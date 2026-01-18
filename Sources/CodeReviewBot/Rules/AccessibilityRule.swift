//
//  AccessibilityRule.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

final class AccessibilityRule: FileRule {
    let name = "Accessibility"

    private let requireLabelsForImages: Bool
    private let requireLabelsForButtons: Bool

    init(config: BotConfig) {
        requireLabelsForImages = config.rules["accessibility"]?.extras?["requireLabelsForImages"] ?? true
        requireLabelsForButtons = config.rules["accessibility"]?.extras?["requireLabelsForButtons"] ?? true
    }

    func evaluate(fileURL: URL, source: String) async throws -> [Finding] {
        var findings: [Finding] = []
        let lines = source.components(separatedBy: .newlines)

        for (i, line) in lines.enumerated() {
            // Heuristics are conservative to reduce false positives.
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if requireLabelsForImages &&
               trimmed.contains("Image(") &&
               !trimmed.contains(".accessibilityLabel(") &&
               !trimmed.contains("accessibilityHidden(true)")
            {
                findings.append(Finding(rule: name, severity: .warning,
                                        file: fileURL.path, line: i+1,
                                        message: "SwiftUI Image missing accessibilityLabel"))
            }

            if requireLabelsForButtons &&
               trimmed.contains("Button(") &&
               !trimmed.contains(".accessibilityLabel(") &&
               !trimmed.contains("accessibilityHidden(true)")
            {
                findings.append(Finding(rule: name, severity: .info,
                                        file: fileURL.path, line: i+1,
                                        message: "SwiftUI Button missing accessibilityLabel (hint)"))
            }
        }
        return findings
    }
}

