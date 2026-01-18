//
//  YAMLDecoder.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

/// A tiny YAML→JSON bridge for simple maps used in `code-review.yml`.
/// It supports nested dicts (2–3 levels), bools, ints, and strings.
/// For complex YAML, use a full parser library. This is intentionally minimal.
public enum YAMLDecoder {

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        // 1) If input already looks like JSON, decode directly.
        if let jsonStr = String(data: data, encoding: .utf8),
           jsonStr.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") {
            return try JSONDecoder().decode(T.self, from: data)
        }

        // 2) Convert simple YAML (key: value, indented blocks) to a JSON dictionary string.
        let yaml = String(data: data, encoding: .utf8) ?? ""
        let json = try yamlToJSON(yaml)
        return try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    // MARK: - Minimal YAML→JSON converter
    private static func yamlToJSON(_ yaml: String) throws -> String {
        // Very small subset: lines "key:" start objects, "key: value" set primitives.
        // Indentation defines nesting. Assumes 2 spaces per indent.
        struct Node { var children: [String: Any] = [:] }
        var stack: [(indent: Int, node: Node)] = [(indent: 0, node: Node())]

        func set(_ key: String, _ value: Any, indent: Int) {
            while let last = stack.last, last.indent > indent { _ = stack.popLast() }
            var top = stack.removeLast()
            top.node.children[key] = value
            stack.append(top)
        }

        func enter(_ key: String, indent: Int) {
            while let last = stack.last, last.indent >= indent { _ = stack.popLast() }
            stack.append((indent: indent, node: Node()))
            // attach new node to parent
            var parent = stack[stack.count - 2]
            parent.node.children[key] = stack.last!.node.children
            stack[stack.count - 2] = parent
        }

        let lines = yaml.components(separatedBy: .newlines)
        for raw in lines {
            let line = raw.replacingOccurrences(of: "\t", with: "  ")
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let indent = (line.count - trimmed.count)
            if trimmed.hasSuffix(":") {
                // object start
                let key = String(trimmed.dropLast())
                enter(key, indent: indent)
                continue
            }

            let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let valStr = parts[1].trimmingCharacters(in: .whitespaces)

                let value: Any
                if valStr.lowercased() == "true" || valStr.lowercased() == "false" {
                    value = (valStr.lowercased() == "true")
                } else if let i = Int(valStr) {
                    value = i
                } else if valStr.hasPrefix("\"") && valStr.hasSuffix("\"") {
                    value = String(valStr.dropFirst().dropLast())
                } else {
                    value = valStr
                }
                set(key, value, indent: indent)
            }
        }

        // Serialize top node to JSON
        func toJSON(_ any: Any) -> String {
            switch any {
            case let dict as [String: Any]:
                let entries = dict.map { "\"\($0)\": \(toJSON($1))" }.joined(separator: ",")
                return "{\(entries)}"
            case let arr as [Any]:
                let entries = arr.map { toJSON($0) }.joined(separator: ",")
                return "[\(entries)]"
            case let s as String:
                return "\"\(s)\""
            case let b as Bool:
                return b ? "true" : "false"
            case let i as Int:
                return "\(i)"
            default:
                return "null"
            }
        }

        let top = stack.first!.node.children
        return toJSON(top)
    }
}

