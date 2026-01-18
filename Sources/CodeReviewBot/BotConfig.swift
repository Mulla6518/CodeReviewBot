//
//  BotConfig.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

struct BotConfig: Codable {
    struct RuleConfig: Codable {
        var enabled: Bool
        var extras: [String: Bool]?
        var thresholds: [String: Int]?
    }
    var rules: [String: RuleConfig]
    struct AIConfig: Codable {
        var provider: String
        var maxTokens: Int
        var temperature: Double
        var promptStyle: String
    }
    var ai: AIConfig

    static func load() throws -> BotConfig {
        // Look for env override (e.g., $CODE_REVIEW_CONFIG)
        let envPath = ProcessInfo.processInfo.environment["CODE_REVIEW_CONFIG"]
        if let p = envPath {
            let d = try Data(contentsOf: URL(fileURLWithPath: p))
            return try YAMLDecoder.decode(BotConfig.self, from: d) // or use JSON (swap in JSONDecoder)
        }
        // Default bundled YAML → for brevity, use JSON fallback
        let defaultJSON = """
        {"rules":{}, "ai":{"provider":"none","maxTokens":512,"temperature":0.2,"promptStyle":"pr-summary"}}
        """
        return try JSONDecoder().decode(BotConfig.self, from: Data(defaultJSON.utf8))
    }
}

