//
//  SecurityRule.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

final class SecurityRule: FileRule {
    let name = "Security"

    func evaluate(fileURL: URL, source: String) async throws -> [Finding] {
        var out: [Finding] = []
        let lines = source.components(separatedBy: .newlines)
        for (i, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.contains("http://") {
                out.append(Finding(rule: name, severity: .warning, file: fileURL.path, line: i+1,
                                   message: "Plain HTTP detected. Use HTTPS or whitelist with ATS justification."))
            }
            if t.contains("NSAllowsArbitraryLoads") {
                out.append(Finding(rule: name, severity: .info, file: fileURL.path, line: i+1,
                                   message: "ATS disabled (NSAllowsArbitraryLoads). Ensure this is intentional & documented."))
            }
        }
        return out
    }
}

