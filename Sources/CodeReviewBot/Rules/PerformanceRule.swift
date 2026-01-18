//
//  PerformanceRule.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

final class PerformanceRule: FileRule {
    let name = "Performance"

    private let maxFunctionLength: Int
    private let flagImageDecodingOnMain: Bool
    private let flagHeavyWorkInViewBody: Bool

    init(config: BotConfig) {
        maxFunctionLength = config.rules["performance"]?.thresholds?["maxFunctionLength"] ?? 80
        flagImageDecodingOnMain = config.rules["performance"]?.extras?["flagImageDecodingOnMain"] ?? true
        flagHeavyWorkInViewBody = true
    }

    func evaluate(fileURL: URL, source: String) async throws -> [Finding] {
        var out: [Finding] = []
        let lines = source.components(separatedBy: .newlines)

        // Naive function boundary tracking (works fine for lint hints).
        var currentFnLine = 0
        var inFn = false

        for (i, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)

            if t.hasPrefix("func ") {
                inFn = true; currentFnLine = i+1
            }
            if inFn && t == "}" {
                let length = (i+1) - currentFnLine
                if length > maxFunctionLength {
                    out.append(Finding(rule: name, severity: .info, file: fileURL.path, line: currentFnLine,
                                       message: "Function spans \(length) lines (> \(maxFunctionLength)). Consider refactor for readability & compile time."))
                }
                inFn = false
            }

            if flagImageDecodingOnMain &&
               (t.contains("UIImage(data:") || t.contains("CGImageSourceCreateImageAtIndex"))
            {
                out.append(Finding(rule: name, severity: .warning, file: fileURL.path, line: i+1,
                                   message: "Image decoding may occur on main thread. Decode off‑main to avoid UI jank."))
            }

            // Heavy work in SwiftUI `var body: some View` (quick heuristic)
            if flagHeavyWorkInViewBody &&
               (t.contains("var body: some View") || t.contains("var body: View")) {
                // Scan next ~20 lines for obvious heavy operations
                let tail = lines.dropFirst(i).prefix(20).joined(separator: "\n")
                if tail.contains("JSONDecoder().decode(") || tail.contains("Data(contentsOf:") {
                    out.append(Finding(rule: name, severity: .warning, file: fileURL.path, line: i+1,
                                       message: "Avoid heavy work inside SwiftUI `body`. Move networking/decoding to ViewModel/.task."))
                }
            }
        }
        return out
    }
}

