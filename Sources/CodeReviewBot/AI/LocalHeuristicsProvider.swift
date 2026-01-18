//
//  LocalHeuristicsProvider.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

final class LocalHeuristicsProvider: SuggestionProvider {
    
    let config: BotConfig
    init(config: BotConfig) { self.config = config }

    func summarize(findings: [Finding], diffPath: String?) async throws -> AISummary? {
        guard !findings.isEmpty else { return nil }
        let counts = Dictionary(grouping: findings, by: \.rule).mapValues(\.count)
        let body = counts.sorted { $0.value > $1.value }
            .map { "• \($0.key): \($0.value) issues" }
            .joined(separator: "\n")

        return AISummary(title: "Code Review Summary (Local)",
                         body: """
                         Top areas:
                         \(body)

                         Recommendations:
                         - Add accessibility labels to images/buttons
                         - Move JSON/image decoding off main thread
                         - Add retry/backoff for transient network failures
                         - Consider Sendable/actor isolation in concurrency-critical types
                         """)
    }
}

