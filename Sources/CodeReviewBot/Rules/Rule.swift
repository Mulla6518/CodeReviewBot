//
//  Rule.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

public enum Severity: String, Codable {
    case info, warning, error
}

public struct Finding: Codable {
    public let rule: String
    public let severity: Severity
    public let file: String
    public let line: Int
    public let message: String

    public init(rule: String, severity: Severity, file: String, line: Int, message: String) {
        self.rule = rule
        self.severity = severity
        self.file = file
        self.line = line
        self.message = message
    }
}

/// File-level rules evaluate a single source file.
public protocol FileRule {
    var name: String { get }
    func evaluate(fileURL: URL, source: String) async throws -> [Finding]
}

/// Project-level rules evaluate across the repo (e.g., test coverage).
public protocol ProjectRule {
    var name: String { get }
    func evaluateProject(sourceRoot: URL) async throws -> [Finding]
}


enum RuleRegistry {
    static func buildFileRules(config: BotConfig) -> [FileRule] {
        var out: [FileRule] = []
        if config.rules["accessibility"]?.enabled ?? true { out.append(AccessibilityRule(config: config)) }
        if config.rules["concurrency"]?.enabled ?? true { out.append(ConcurrencyRule(config: config)) }
        if config.rules["performance"]?.enabled ?? true { out.append(PerformanceRule(config: config)) }
        if config.rules["networking"]?.enabled ?? true { out.append(NetworkingRule(config: config)) }
        if config.rules["security"]?.enabled ?? true { out.append(SecurityRule()) }
        return out
    }

    static func buildProjectRules(config: BotConfig) -> [ProjectRule] {
        var out: [ProjectRule] = []
        if config.rules["tests"]?.enabled ?? true { out.append(TestCoverageRule(config: config)) }
        return out
    }
}


enum RuleRunner {
    /// Run all file-level rules on a single Swift file.
    static func runFileRules(rules: [FileRule], fileURL: URL, source: String) async throws -> [Finding] {
        var all: [Finding] = []
        for r in rules {
            let f = try await r.evaluate(fileURL: fileURL, source: source)
            all.append(contentsOf: f)
        }
        return all
    }

    /// Run all project-level rules once for the repository.
    static func runProjectRules(rules: [ProjectRule], sourceRoot: URL) async throws -> [Finding] {
        var all: [Finding] = []
        for r in rules {
            let f = try await r.evaluateProject(sourceRoot: sourceRoot)
            all.append(contentsOf: f)
        }
        return all
    }
}
