//
//  PathUtils.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

public enum PathUtils {
    /// Return path relative to the given root, if possible.
    public static func relativize(_ absolute: URL, root: URL) -> String {
        let a = absolute.standardizedFileURL.path
        let r = root.standardizedFileURL.path
        if a.hasPrefix(r) {
            let idx = a.index(a.startIndex, offsetBy: r.count)
            let rel = a[idx...]
            return rel.hasPrefix("/") ? String(rel.dropFirst()) : String(rel)
        }
        return a
    }

    /// Normalize path (strip "./", collapse repeated slashes).
    public static func normalize(_ path: String) -> String {
        var p = path.replacingOccurrences(of: "//", with: "/")
        if p.hasPrefix("./") { p.removeFirst(2) }
        return p
    }
}

