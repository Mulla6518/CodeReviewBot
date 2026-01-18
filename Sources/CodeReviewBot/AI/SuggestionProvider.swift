//
//  SuggestionProvider.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

struct AISummary {
    let title: String
    let body: String
}

protocol SuggestionProvider {
    func summarize(findings: [Finding], diffPath: String?) async throws -> AISummary?
}
