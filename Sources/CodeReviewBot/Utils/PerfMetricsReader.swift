//
//  PerfMetricsReader.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

// MARK: - Data Models

/// Normalized metrics you can track in CI.
public struct PerfMetricSummary: Codable {
    // Launch / runtime
    public var appLaunchMeanMs: Double?
    public var appLaunchStdMs: Double?

    // CPU / memory
    public var cpuTimeSecMean: Double?
    public var memoryMBMean: Double?

    // UI/animation (optional)
    public var droppedFramesCount: Int?
    public var scrollJankEvents: Int?

    // Raw source (for provenance)
    public var source: String?

    public init(appLaunchMeanMs: Double? = nil,
                appLaunchStdMs: Double? = nil,
                cpuTimeSecMean: Double? = nil,
                memoryMBMean: Double? = nil,
                droppedFramesCount: Int? = nil,
                scrollJankEvents: Int? = nil,
                source: String? = nil) {
        self.appLaunchMeanMs = appLaunchMeanMs
        self.appLaunchStdMs = appLaunchStdMs
        self.cpuTimeSecMean = cpuTimeSecMean
        self.memoryMBMean = memoryMBMean
        self.droppedFramesCount = droppedFramesCount
        self.scrollJankEvents = scrollJankEvents
        self.source = source
    }
}

/// Comparison outcome for CI gating.
public struct PerfComparison: Codable {
    public let baseline: PerfMetricSummary
    public let current: PerfMetricSummary
    public let regressions: [String] // human-readable messages
    public let passes: Bool
}

// MARK: - Reader

/// Reads performance metrics from different sources and produces a normalized summary.
public enum PerfMetricsReader {

    // -------- XCTest (.xcresult via xcresulttool) --------

    /// Reads metrics from an `.xcresult` bundle by invoking `xcrun xcresulttool`.
    /// - Parameters:
    ///   - xcresultPath: Path to the `.xcresult` bundle
    ///   - testNameFilter: Optional substring filter to narrow to a specific perf test
    /// - Returns: PerfMetricSummary or nil if parsing failed
    public static func readXCResult(at xcresultPath: String,
                                    testNameFilter: String? = nil) -> PerfMetricSummary? {
        // xcresulttool emits a large JSON; we scan for the common perf metrics structure.
        #if os(macOS)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        task.arguments = ["xcresulttool", "get", "--format", "json", "--path", xcresultPath]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return nil
        }

        task.waitUntilExit()

        guard task.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else { return nil }

        // Attempt to walk the xcresult JSON structure and extract metrics.
        // XCTest perf metrics typically appear under activity summaries / performanceMetrics.
        let metrics = extractPerfFromXCResult(json: json, nameFilter: testNameFilter)
        var summary = PerfMetricSummary(source: "xcresulttool")
        summary.appLaunchMeanMs = metrics["XCTApplicationLaunchMetric.meanMs"] ?? metrics["launch.meanMs"]
        summary.appLaunchStdMs  = metrics["XCTApplicationLaunchMetric.stdMs"]  ?? metrics["launch.stdMs"]
        summary.cpuTimeSecMean  = metrics["XCTCPUMetric.meanSec"]             ?? metrics["cpu.meanSec"]
        summary.memoryMBMean    = metrics["XCTMemoryMetric.meanMB"]           ?? metrics["memory.meanMB"]
        return summary
        #else
        return nil
        #endif
    }

    // Walks the xcresult JSON tree to find known metric keys (best-effort).
    private static func extractPerfFromXCResult(json: Any, nameFilter: String?) -> [String: Double] {
        var out: [String: Double] = [:]

        func scan(_ obj: Any) {
            if let dict = obj as? [String: Any] {
                // Heuristics: look for keys "measurements", "metrics", "performanceMetrics", etc.
                for (k, v) in dict {
                    if let s = v as? String {
                        // parse simple "mean: 123.4 ms" forms
                        if k.lowercased().contains("mean"),
                           let num = numberFromString(s) {
                            out[k] = num
                        }
                    } else if let n = v as? NSNumber {
                        out[k] = n.doubleValue
                    } else {
                        scan(v)
                    }
                }
            } else if let arr = obj as? [Any] {
                arr.forEach(scan)
            }
        }

        scan(json)
        // Narrow by test name if provided: (this requires richer parsing of TestSummary → skipped here)
        return out
    }

    // -------- xctrace (CSV / JSON exports) --------

    /// Reads an xctrace CSV/JSON summary file and returns normalized metrics.
    public static func readXctraceSummary(at path: String) -> PerfMetricSummary? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let text = String(data: data, encoding: .utf8) else { return nil }

        // Quick CSV detection; otherwise try JSON
        if text.contains(",") && text.contains("\n") {
            return parseXctraceCSV(text)
        } else if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            return parseXctraceJSON(json)
        }
        return nil
    }

    private static func parseXctraceCSV(_ csv: String) -> PerfMetricSummary? {
        // Look for rows like: Metric,Mean,Std
        // Launch,512.3,32.1
        var summary = PerfMetricSummary(source: "xctrace-csv")
        let lines = csv.components(separatedBy: .newlines)
        for row in lines {
            let cols = row.split(separator: ",").map(String.init)
            guard cols.count >= 2 else { continue }
            let key = cols[0].lowercased()
            if key.contains("launch") {
                summary.appLaunchMeanMs = numberFromString(cols[1])
                if cols.count >= 3 { summary.appLaunchStdMs = numberFromString(cols[2]) }
            } else if key.contains("cpu") {
                summary.cpuTimeSecMean = numberFromString(cols[1])
            } else if key.contains("memory") {
                summary.memoryMBMean = numberFromString(cols[1])
            } else if key.contains("dropped") || key.contains("frames") {
                summary.droppedFramesCount = Int(numberFromString(cols[1]) ?? 0)
            }
        }
        return summary
    }

    private static func parseXctraceJSON(_ json: Any) -> PerfMetricSummary? {
        var summary = PerfMetricSummary(source: "xctrace-json")
        func scan(_ obj: Any) {
            if let d = obj as? [String: Any] {
                for (k, v) in d {
                    let kl = k.lowercased()
                    if let n = v as? NSNumber {
                        if kl.contains("launch") && kl.contains("mean") { summary.appLaunchMeanMs = n.doubleValue }
                        if kl.contains("launch") && kl.contains("std")  { summary.appLaunchStdMs  = n.doubleValue }
                        if kl.contains("cpu") && kl.contains("mean")    { summary.cpuTimeSecMean  = n.doubleValue }
                        if kl.contains("memory") && kl.contains("mean") { summary.memoryMBMean    = n.doubleValue }
                        if kl.contains("dropped") || kl.contains("frames") {
                            summary.droppedFramesCount = Int(truncating: n)
                        }
                    } else {
                        scan(v)
                    }
                }
            } else if let a = obj as? [Any] {
                a.forEach(scan)
            }
        }
        scan(json)
        return summary
    }

    // -------- Plain Text Logs --------

    /// Reads a plain text perf log (e.g., from `measure(metrics:)` prints) and extracts numbers by regex.
    public static func readPlainLog(at path: String) -> PerfMetricSummary? {
        guard let text = try? String(contentsOfFile: path) else { return nil }
        var s = PerfMetricSummary(source: "text")
        s.appLaunchMeanMs = matchFirst(in: text, pattern: #"launch.*?mean[:=]\s*([0-9]+(?:\.[0-9]+)?)\s*ms"#)
        s.appLaunchStdMs  = matchFirst(in: text, pattern: #"launch.*?std(?:dev)?[:=]\s*([0-9]+(?:\.[0-9]+)?)\s*ms"#)
        s.cpuTimeSecMean  = matchFirst(in: text, pattern: #"cpu.*?mean[:=]\s*([0-9]+(?:\.[0-9]+)?)\s*s"#)
        s.memoryMBMean    = matchFirst(in: text, pattern: #"mem.*?mean[:=]\s*([0-9]+(?:\.[0-9]+)?)\s*mb"#)
        return s
    }

    // -------- Baseline Comparison --------

    /// Compares current metrics with a baseline against tolerances (percent thresholds).
    public static func compare(current: PerfMetricSummary,
                               baseline: PerfMetricSummary,
                               tolerancesPercent: [String: Double] = [
                                   "launch.mean": 5.0,       // allow +5% launch time
                                   "cpu.mean":    5.0,
                                   "memory.mean": 5.0
                               ]) -> PerfComparison {
        var regressions: [String] = []

        func check(_ currentVal: Double?, _ baselineVal: Double?, key: String, unit: String) {
            guard let c = currentVal, let b = baselineVal, b > 0 else { return }
            let pct = ((c - b) / b) * 100.0
            let limit = tolerancesPercent[key] ?? 0.0
            if pct > limit {
                regressions.append("\(key) regressed by +\(String(format: "%.1f", pct))% (baseline \(String(format: "%.1f", b))\(unit) → current \(String(format: "%.1f", c))\(unit); limit +\(String(format: "%.1f", limit))%)")
            }
        }

       check(current.appLaunchMeanMs, baseline.appLaunchMeanMs, key: "launch.mean", unit: "ms")
       check(current.cpuTimeSecMean,  baseline.cpuTimeSecMean,  key: "cpu.mean",    unit: "s")
       check(current.memoryMBMean,    baseline.memoryMBMean,    key: "memory.mean", unit: "MB")

        return PerfComparison(baseline: baseline, current: current, regressions: regressions, passes: regressions.isEmpty)
    }

    // MARK: - Helpers

    private static func numberFromString(_ s: String) -> Double? {
        Double(s.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func matchFirst(in text: String, pattern: String) -> Double? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let m = re.firstMatch(in: text, options: [], range: range), m.numberOfRanges >= 2,
           let r = Range(m.range(at: 1), in: text) {
            return Double(text[r])
        }
        return nil
    }
}


