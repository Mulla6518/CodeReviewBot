//
//  NetworkingRule.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

final class NetworkingRule: FileRule {
    let name = "Networking"

    private let requireBrotli: Bool
    private let requireRetryWithBackoff: Bool

    init(config: BotConfig) {
        requireBrotli = config.rules["networking"]?.extras?["requireBrotliAcceptEncoding"] ?? true
        requireRetryWithBackoff = config.rules["networking"]?.extras?["requireRetryWithBackoff"] ?? true
    }

    func evaluate(fileURL: URL, source: String) async throws -> [Finding] {
        var f: [Finding] = []
        let lines = source.components(separatedBy: .newlines)

        var hasBrotliHeader = false

        for (i, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)

            if requireBrotli && t.contains("Accept-Encoding") && t.contains("br") {
                hasBrotliHeader = true
            }

            if requireRetryWithBackoff &&
               (t.contains("dataTask") || t.contains("URLSession.shared.data(") || t.contains("URLSession.shared.dataTask(")) &&
               !(t.contains("retry") || t.contains("Backoff") || t.contains("Task.sleep"))
            {
                f.append(Finding(rule: name, severity: .info, file: fileURL.path, line: i+1,
                                 message: "Consider retry with exponential backoff for transient errors (429/5xx/timeout)."))
            }
        }

        if requireBrotli && !hasBrotliHeader {
            f.append(Finding(rule: name, severity: .info, file: fileURL.path, line: 1,
                             message: "Add `Accept-Encoding: br` (Brotli) where server supports it to cut payload size."))
        }

        return f
    }
}

