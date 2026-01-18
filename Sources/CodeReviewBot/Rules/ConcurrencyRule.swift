//
//  ConcurrencyRule.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

final class ConcurrencyRule: FileRule {
    let name = "Concurrency"

    private let warnMainActorBlocking: Bool
    private let enforceSendable: Bool

    init(config: BotConfig) {
        warnMainActorBlocking = config.rules["concurrency"]?.extras?["warnMainActorBlocking"] ?? true
        enforceSendable = config.rules["concurrency"]?.extras?["enforceSendable"] ?? true
    }

    func evaluate(fileURL: URL, source: String) async throws -> [Finding] {
        var findings: [Finding] = []
        let lines = source.components(separatedBy: .newlines)

        for (i, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)

            // Synchronous JSON decoding is a common main‑thread offender.
            if warnMainActorBlocking &&
               (t.contains("JSONDecoder().decode(") || t.contains("try JSONDecoder().decode(")) &&
               !t.contains("Task.detached") && !t.contains("DispatchQueue.global().async")
            {
                findings.append(Finding(rule: name, severity: .warning,
                                        file: fileURL.path, line: i+1,
                                        message: "Potential synchronous JSON decode on main. Move to Task.detached/background queue."))
            }

            // Encourage explicit concurrency semantics for types.
            if enforceSendable && t.hasPrefix("struct ") || t.hasPrefix("class ") || t.hasPrefix("actor ") {
                let isSendable = t.contains("Sendable")
                let isActorOrMain = t.contains("@MainActor") || t.hasPrefix("actor ")
                if !isSendable && !isActorOrMain {
                    findings.append(Finding(rule: name, severity: .info,
                                            file: fileURL.path, line: i+1,
                                            message: "Consider `Sendable` or actor/@MainActor isolation for concurrency‑critical types."))
                }
            }
        }
        return findings
    }
}

