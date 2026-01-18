//
//  main.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

// MARK: - Entry

enum MainError: Error {
    case EmptySourceRoot
    case invalidArguments
    case Other(Error)
}

do {
    try await Main.main()
} catch {
    throw error
}

struct Main {
    
    static func main() async throws {
        do {
            let args = Arguments.parse(CommandLine.arguments)
            guard let sourceRoot = args.sourceRoot else {
                print("Usage: codereview-bot <source-root> [options]\nRun with --help for details.")
                throw MainError.EmptySourceRoot
            }

            // Load configuration (path overrides env)
            let config = try BotConfigLoader.load(configPath: args.configPath)

            // Enumerate Swift files
            let walker = FileWalker(root: URL(fileURLWithPath: sourceRoot))
            let swiftFiles = try walker.swiftFiles()

            // ---- Run file-level rules
            var findings: [Finding] = []
            let fileRules = RuleRegistry.buildFileRules(config: config)
            for fileURL in swiftFiles {
                let src = try String(contentsOf: fileURL)
                // If you want PR-focused results, you can filter to changed lines here:
                // let changed = DiffUtils.changedLines(for: fileURL.path, diffPath: args.diffPath)
                let fileFindings = try await RuleRunner.runFileRules(rules: fileRules, fileURL: fileURL, source: src)
                findings.append(contentsOf: fileFindings)
            }

            // ---- Run project-level rules
            let projectRules = RuleRegistry.buildProjectRules(config: config)
            let projectFindings = try await RuleRunner.runProjectRules(rules: projectRules, sourceRoot: URL(fileURLWithPath: sourceRoot))
            findings.append(contentsOf: projectFindings)

            // ---- Optional: Perf metrics compare (XCResult / xctrace / text)
            var perfComparison: PerfComparison?
            if let xcresult = args.xcresultPath {
                if let current = PerfMetricsReader.readXCResult(at: xcresult, testNameFilter: args.perfTestFilter) {
                    let baselineSummary = PerfMetricsReader.readXctraceSummary(at: args.perfBaselinePath ?? "")
                                   ?? PerfMetricsReader.readPlainLog(at: args.perfBaselinePath ?? "")
                    if let base = baselineSummary {
                        perfComparison = PerfMetricsReader.compare(current: current, baseline: base, tolerancesPercent: args.perfTolerances)
                    }
                }
            } else if let currentPerfPath = args.perfCurrentPath {
                let current = PerfMetricsReader.readXctraceSummary(at: currentPerfPath)
                           ?? PerfMetricsReader.readPlainLog(at: currentPerfPath)
                let base    = PerfMetricsReader.readXctraceSummary(at: args.perfBaselinePath ?? "")
                           ?? PerfMetricsReader.readPlainLog(at: args.perfBaselinePath ?? "")
                if let c = current, let b = base {
                    perfComparison = PerfMetricsReader.compare(current: c, baseline: b, tolerancesPercent: args.perfTolerances)
                }
            }

            // ---- Optional: size budget evaluation
            var sizeReport: SizeReport?
            if let ipaPath = args.ipaPath {
                let budget = SizeBudget(
                    maxAbsoluteMB: args.sizeAbsMB,
                    maxDiffMB: args.sizeDiffMB,
                    maxIncreasePercent: args.sizePct
                )
                sizeReport = SizeBudgetEvaluator.evaluate(
                    ipaURL: URL(fileURLWithPath: ipaPath),
                    baselineMB: args.sizeBaselineMB,
                    budget: budget
                )
            }

            // ---- Optional AI summary
            let suggestionProvider: SuggestionProvider
            switch config.ai.provider.lowercased() {
                case "openai": suggestionProvider =  OpenAIProvider(config: config)
                default: suggestionProvider =  LocalHeuristicsProvider(config: config)
            }
            let aiSummary = try await suggestionProvider.summarize(findings: findings, diffPath: args.diffPath)

            // ---- Render output
            let reporter = Reporter(format: args.outputFormat)
            var report = reporter.render(findings: findings, aiSummary: aiSummary)

            if let cmp = perfComparison {
                report += Reporter.section("Performance Comparison")
                report += Reporter.bullet("Passes: \(cmp.passes ? "✅" : "❌")")
                if cmp.regressions.isEmpty {
                    report += Reporter.bullet("No perf regressions against baseline")
                } else {
                    for r in cmp.regressions { report += Reporter.bullet(r) }
                }
            }

            if let sr = sizeReport {
                report += Reporter.section("App Size Report")
                report += SizeBudgetEvaluator.renderMarkdown(sr)
            }

            // Write to file or stdout
            if let outPath = args.outputPath {
                let fileName = "output.txt"
                let fileURL = URL(fileURLWithPath: outPath).appendingPathComponent(fileName)
                do {
                    try report.write(to: fileURL, atomically: true, encoding: .utf8)
                    print("Successfully wrote to file at: \(fileURL.path)")
                } catch {
                    print("Failed to write to file: \(error.localizedDescription)")
                    throw MainError.Other(error)
                }
            } else {
                print(report)
            }

            // ---- CI exit codes
            var shouldFail = false

            // Fail on any ERROR severity finding
            if findings.contains(where: { $0.severity == .error }) { shouldFail = true }

            // Fail on perf regressions if present
            if let cmp = perfComparison, !cmp.passes { shouldFail = true }

            // Fail on size budget violation
            if let sr = sizeReport, !sr.passes { shouldFail = true }

            if shouldFail {
                throw MainError.invalidArguments
            }
            exit(0)
        } catch {
            fprint("❌ Fatal: \(error.localizedDescription)")
            throw MainError.Other(error)
        }
    }
}

// MARK: - Lightweight argument parser

private struct Arguments {
    let sourceRoot: String?
    let outputFormat: String
    let outputPath: String?
    let diffPath: String?
    let configPath: String?

    // Perf
    let xcresultPath: String?
    let perfTestFilter: String?
    let perfCurrentPath: String?
    let perfBaselinePath: String?
    let perfTolerances: [String: Double]

    // Size
    let ipaPath: String?
    let sizeBaselineMB: Double?
    let sizeAbsMB: Double?
    let sizeDiffMB: Double?
    let sizePct: Double?

    static func parse(_ argv: [String]) -> Arguments {
        var args = argv.dropFirst() // strip executable name

        func value(after flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i+1 < args.count else { return nil }
            return String(args[args.index(after: i)])
        }

        if args.contains("--help") {
            print("""
            codereview-bot <source-root> [options]
            Options:
              --format md|json          Output format (default md)
              --out <path>              Write report to file (default stdout)
              --diff <path>             Unified diff to focus findings (optional)
              --config <path>           YAML/JSON config path (overrides env)

            Perf metrics:
              --xcresult <path>         XCTest .xcresult bundle (uses xcresulttool)
              --perf-current <path>     xctrace CSV/JSON or text log for current
              --perf-baseline <path>    xctrace CSV/JSON or text log for baseline
              --perf-test-filter <name> Substring to filter perf test (optional)
              --perf-tol <key=percent>  e.g., launch.mean=5 cpu.mean=5 memory.mean=5

            Size budgets:
              --ipa <path>              Path to exported .ipa
              --size-baseline <MB>      Baseline size in MB (e.g., 246.8)
              --size-abs <MB>           Absolute budget (max MB)
              --size-diff <MB>          Max allowed diff in MB
              --size-pct <percent>      Max allowed increase percent

            """)
        }

        let sourceRoot = args.first.flatMap { str in
            str
        }
        if sourceRoot != nil { args = args.dropFirst() }

        // Output
        let format = (value(after: "--format") ?? "md").lowercased()
        let outPath = value(after: "--out")
        let diff = value(after: "--diff")
        let cfg = value(after: "--config")

        // Perf
        let xcresult = value(after: "--xcresult")
        let perfCurrent = value(after: "--perf-current")
        let perfBaseline = value(after: "--perf-baseline")
        let perfFilter = value(after: "--perf-test-filter")

        var perfTols: [String: Double] = [:]
        if let i = args.firstIndex(of: "--perf-tol") {
            // Collect all "key=value" pairs following the flag until next flag or end
            var j = args.index(after: i)
            while j < args.endIndex, !args[j].hasPrefix("--") {
                let pair = String(args[j])
                if let eq = pair.firstIndex(of: "=") {
                    let key = String(pair[..<eq])
                    let valStr = String(pair[pair.index(after: eq)...])
                    if let v = Double(valStr) { perfTols[key] = v }
                }
                j = args.index(after: j)
            }
        }
        if perfTols.isEmpty {
            perfTols = ["launch.mean": 5.0, "cpu.mean": 5.0, "memory.mean": 5.0]
        }

        // Size
        let ipa = value(after: "--ipa")
        let sizeBaseMB = value(after: "--size-baseline").flatMap(Double.init)
        let sizeAbsMB = value(after: "--size-abs").flatMap(Double.init)
        let sizeDiffMB = value(after: "--size-diff").flatMap(Double.init)
        let sizePct = value(after: "--size-pct").flatMap(Double.init)

        return Arguments(
            sourceRoot: sourceRoot,
            outputFormat: format,
            outputPath: outPath,
            diffPath: diff,
            configPath: cfg,
            xcresultPath: xcresult,
            perfTestFilter: perfFilter,
            perfCurrentPath: perfCurrent,
            perfBaselinePath: perfBaseline,
            perfTolerances: perfTols,
            ipaPath: ipa,
            sizeBaselineMB: sizeBaseMB,
            sizeAbsMB: sizeAbsMB,
            sizeDiffMB: sizeDiffMB,
            sizePct: sizePct
        )
    }
}

// MARK: - Helpers

private func fprint(_ msg: String) {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
}

// MARK: - Config loader (YAML/JSON path override)

enum BotConfigLoader {
    static func load(configPath: String?) throws -> BotConfig {
        if let path = configPath {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            // Try YAML, fallback JSON
            do {
                return try YAMLDecoder.decode(BotConfig.self, from: data)
            } catch {
                return try JSONDecoder().decode(BotConfig.self, from: data)
            }
        } else {
            // Fall back to BotConfig.load() which reads env or default
            return try BotConfig.load()
        }
    }
}

// MARK: - Reporter convenience

extension Reporter {
    static func section(_ title: String) -> String {
        return "\n\n## \(title)\n"
    }
    static func bullet(_ text: String) -> String {
        return "- \(text)\n"
    }
}


