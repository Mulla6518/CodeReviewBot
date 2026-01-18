//
//  Reporter.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

final class Reporter {
    enum Format { case md, json }
    let format: Format

    init(format: String) {
        self.format = (format.lowercased() == "json") ? .json : .md
    }

    func render(findings: [Finding], aiSummary: AISummary?) -> String {
        switch format {
        case .md:
            var out = "# Code Review Bot Report\n\n"
            if let ai = aiSummary {
                out += "## AI Summary: \(ai.title)\n\n\(ai.body)\n\n---\n"
            }
            out += "## Findings (\(findings.count))\n"
            for f in findings {
                out += "- **[\(f.severity.rawValue.uppercased())] \(f.rule)** – \(f.message)  `\(f.file):\(f.line)`\n"
            }
            return out
        case .json:
            let dict: [String: Any] = [
                "summary": aiSummary.map { ["title": $0.title, "body": $0.body] } ?? NSNull(),
                "findings": findings.map {
                    ["rule": $0.rule, "severity": $0.severity.rawValue, "file": $0.file, "line": $0.line, "message": $0.message]
                }
            ]
            let data = try! JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
            return String(data: data, encoding: .utf8) ?? "{}"
        }
    }
}

