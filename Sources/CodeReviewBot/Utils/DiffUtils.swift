//
//  DiffUtils.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

/// Represents a unified-diff entry for a single file.
public struct DiffFile {
    public let path: String
    public var addedLines: Set<Int> = []
    public var removedLines: Set<Int> = []
}

public enum DiffUtils {

    /// Parse a unified diff (e.g., `git diff`) and return per-file changed line sets.
    /// Supports hunks like:
    /// @@ -a,b +c,d @@
    public static func parseUnifiedDiff(_ text: String) -> [DiffFile] {
        var files: [String: DiffFile] = [:]
        var currentPath: String?
        var currentNewLineStart: Int = 0

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            if line.hasPrefix("+++ ") {
                // e.g., "+++ b/Sources/Foo.swift"
                let path = normalizeFromDiffHeader(line)
                currentPath = path
                if files[currentPath!] == nil {
                    files[currentPath!] = DiffFile(path: currentPath!)
                }
                continue
            }

            if line.hasPrefix("@@") {
                // Example: @@ -32,7 +32,9 @@
                // We care about new file start '+c,d'
                if let plusRange = line.range(of: "+") {
                    let tail = line[plusRange.lowerBound...]
                    // "+c,d @@" or "+c @@"
                    let parts = tail.split(separator: " ")
                    if let hunk = parts.first {
                        let nums = hunk.dropFirst().split(separator: ",")
                        let start = Int(nums.first ?? Substring("0")) ?? 0
                        currentNewLineStart = start
                    }
                }
                continue
            }

            // Inside hunk, new lines prefixed with '+', context ' ' and deletions '-'
            guard let path = currentPath else { continue }
            switch line.first {
            case "+":
                // new line added; record the current new line number
                files[path]?.addedLines.insert(currentNewLineStart)
                currentNewLineStart += 1
            case " ":
                // context line; advance
                currentNewLineStart += 1
            case "-":
                // deletion; do not advance new line counter
                // We can't reliably know old line numbers without full mapping,
                // but we record deletion for visibility.
                files[path]?.removedLines.insert(currentNewLineStart)
            default:
                break
            }
        }

        return Array(files.values)
    }

    /// Load a diff from a file path.
    public static func loadDiff(at path: String) -> [DiffFile] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let text = String(data: data, encoding: .utf8) else { return [] }
        return parseUnifiedDiff(text)
    }

    /// Convenience: given a diff path and a file path, return changed new-line numbers.
    public static func changedLines(for filePath: String, diffPath: String?) -> Set<Int> {
        guard let diffPath else { return [] }
        let entries = loadDiff(at: diffPath)
        let normalized = normalizePath(filePath)
        if let entry = entries.first(where: { normalizePath($0.path) == normalized }) {
            return entry.addedLines
        }
        return []
    }

    // MARK: - Helpers

    private static func normalizeFromDiffHeader(_ header: String) -> String {
        // "+++ b/Sources/Foo.swift" or "+++ /dev/null"
        let trimmed = header.replacingOccurrences(of: "+++ ", with: "")
        if trimmed.hasPrefix("b/") || trimmed.hasPrefix("a/") {
            return String(trimmed.dropFirst(2))
        }
        return trimmed
    }

    private static func normalizePath(_ path: String) -> String {
        var p = path
        if p.hasPrefix("./") { p.removeFirst(2) }
        return p
    }
}

