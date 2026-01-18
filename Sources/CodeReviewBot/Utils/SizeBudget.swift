//
//  SizeBudget.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

// MARK: - Data Models

public struct SizeBudget: Codable {
    /// Max absolute IPA size allowed (in MB). If nil, no absolute gate.
    public var maxAbsoluteMB: Double?
    /// Max allowed diff vs baseline (in MB). If nil, no diff gate.
    public var maxDiffMB: Double?
    /// Optional fail on increase (%) even if MB diff is small.
    public var maxIncreasePercent: Double?

    public init(maxAbsoluteMB: Double? = nil,
                maxDiffMB: Double? = nil,
                maxIncreasePercent: Double? = nil) {
        self.maxAbsoluteMB = maxAbsoluteMB
        self.maxDiffMB = maxDiffMB
        self.maxIncreasePercent = maxIncreasePercent
    }
}

public struct SizeReport: Codable {
    public let ipaPath: String
    public let currentMB: Double
    public let baselineMB: Double?
    public let diffMB: Double?
    public let diffPercent: Double?
    public let passes: Bool
    public let messages: [String]
}

// MARK: - Evaluator

public enum SizeBudgetEvaluator {

    /// Evaluate an IPA against a budget and optional baseline.
    /// - Parameters:
    ///   - ipaURL: Path to .ipa (zip)
    ///   - baselineMB: Previous size in MB (from last release or artifact); pass nil if none
    ///   - budget: SizeBudget thresholds
    /// - Returns: SizeReport suitable for CI annotation
    public static func evaluate(ipaURL: URL,
                                baselineMB: Double?,
                                budget: SizeBudget) -> SizeReport {
        let currentBytes = fileSizeBytes(at: ipaURL) ?? 0
        let currentMB = bytesToMB(currentBytes)

        var messages: [String] = []
        var passes = true

        // Absolute gate
        if let absGate = budget.maxAbsoluteMB {
            if currentMB > absGate {
                passes = false
                messages.append("IPA exceeds absolute budget: \(fmt(currentMB)) MB > \(fmt(absGate)) MB")
            } else {
                messages.append("IPA within absolute budget: \(fmt(currentMB)) MB ≤ \(fmt(absGate)) MB")
            }
        } else {
            messages.append("No absolute budget set. Current size: \(fmt(currentMB)) MB")
        }

        // Diff gate
        var diffMB: Double? = nil
        var diffPct: Double? = nil
        if let base = baselineMB, base > 0 {
            diffMB = currentMB - base
            diffPct = ((currentMB - base) / base) * 100.0

            if let diffGate = budget.maxDiffMB, let d = diffMB {
                if d > diffGate {
                    passes = false
                    messages.append("Size diff exceeds budget: +\(fmt(d)) MB > +\(fmt(diffGate)) MB (baseline \(fmt(base)) MB → current \(fmt(currentMB)) MB)")
                } else {
                    messages.append("Size diff within budget: +\(fmt(d)) MB ≤ +\(fmt(diffGate)) MB (baseline \(fmt(base)) MB → current \(fmt(currentMB)) MB)")
                }
            } else {
                messages.append("No diff budget set. Diff: \(fmt(diffMB ?? 0)) MB")
            }

            if let pctGate = budget.maxIncreasePercent, let p = diffPct {
                if p > pctGate {
                    passes = false
                    messages.append("Size increase percent exceeds gate: +\(String(format: "%.1f", p))% > +\(String(format: "%.1f", pctGate))%")
                } else {
                    messages.append("Percent increase within gate: +\(String(format: "%.1f", p))% ≤ +\(String(format: "%.1f", pctGate))%")
                }
            }
        } else {
            messages.append("No baseline provided. Diff gates skipped.")
        }

        return SizeReport(ipaPath: ipaURL.path,
                          currentMB: currentMB,
                          baselineMB: baselineMB,
                          diffMB: diffMB,
                          diffPercent: diffPct,
                          passes: passes,
                          messages: messages)
    }

    // MARK: - Renderers

    /// Markdown report for PR comments / CI artifacts.
    public static func renderMarkdown(_ report: SizeReport) -> String {
        var out = """
        ### App Size Report
        **IPA:** `\(report.ipaPath)`
        **Current:** \(fmt(report.currentMB)) MB
        """

        if let base = report.baselineMB {
            out += "\n**Baseline:** \(fmt(base)) MB"
        }
        if let d = report.diffMB {
            out += "\n**Diff:** \(d >= 0 ? "+" : "")\(fmt(d)) MB"
        }
        if let p = report.diffPercent {
            out += "\n**Diff %:** \(p >= 0 ? "+" : "")\(String(format: "%.1f", p))%"
        }

        out += "\n\n**Status:** \(report.passes ? "✅ PASS" : "❌ FAIL")\n\n**Details:**\n"
        for m in report.messages { out += "- \(m)\n" }
        return out
    }

    /// JSON for machine consumption / annotators.
    public static func renderJSON(_ report: SizeReport) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try! enc.encode(report)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    // MARK: - Helpers

    private static func fileSizeBytes(at url: URL) -> UInt64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? UInt64
    }

    private static func bytesToMB(_ b: UInt64) -> Double {
        Double(b) / (1024.0 * 1024.0)
    }

    private static func fmt(_ v: Double?) -> String {
        guard let v else { return "-" }
        return String(format: "%.2f", v)
    }
}


