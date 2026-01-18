//
//  TestCoverageRule.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

final class TestCoverageRule: ProjectRule {
    let name = "TestCoverage"

    private let minUnitTests: Int
    private let minUITests: Int

    init(config: BotConfig) {
        minUnitTests = config.rules["tests"]?.thresholds?["minUnitTestFiles"] ?? 5
        minUITests   = config.rules["tests"]?.thresholds?["minUITestFiles"]   ?? 1
    }

    func evaluateProject(sourceRoot: URL) async throws -> [Finding] {
        var findings: [Finding] = []
        let fm = FileManager.default

        var unitCount = 0
        var uiCount = 0

        let enumerator = fm.enumerator(at: sourceRoot, includingPropertiesForKeys: nil)
        while let next = enumerator?.nextObject() as? URL {
            guard next.pathExtension == "swift" else { continue }

            let pathLower = next.path.lowercased()
            if pathLower.contains("tests") {
                // simple heuristics: unit vs ui tests by folder/file naming
                if pathLower.contains("uitests") {
                    uiCount += 1
                } else {
                    unitCount += 1
                }
            }
        }

        if unitCount < minUnitTests {
            findings.append(Finding(rule: name, severity: .warning,
                                    file: sourceRoot.path, line: 1,
                                    message: "Unit test files: \(unitCount) (< \(minUnitTests)). Add coverage for core modules."))
        }
        if uiCount < minUITests {
            findings.append(Finding(rule: name, severity: .info,
                                    file: sourceRoot.path, line: 1,
                                    message: "UI test files: \(uiCount) (< \(minUITests)). Add at least one UITest for smoke flows."))
        }

        return findings
    }
}

