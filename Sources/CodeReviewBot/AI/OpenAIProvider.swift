//
//  OpenAIProvider.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

final class OpenAIProvider: SuggestionProvider {
    let config: BotConfig
    init(config: BotConfig) { self.config = config }

    func summarize(findings: [Finding], diffPath: String?) async throws -> AISummary? {
        // NOTE: Example only. Implement your HTTP call to OpenAI/Azure OpenAI here.
        // Read env: OPENAI_API_KEY, OPENAI_MODEL (e.g., gpt-4o-mini)
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else { return nil }

        // 1) Build prompt from findings & optional diff
        // 2) POST to OpenAI API
        // 3) Parse JSON response → AISummary
        // Keep deterministic fallbacks if network is unavailable.

        return AISummary(title: "AI Suggestions (Stub)",
                         body: "LLM suggestions would appear here once provider is wired.")
    }
}

