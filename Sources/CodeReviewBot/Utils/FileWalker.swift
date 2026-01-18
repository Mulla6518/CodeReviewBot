//
//  FileWalker.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

final class FileWalker {
    let root: URL
    init(root: URL) { self.root = root }

    func swiftFiles() throws -> [URL] {
        var out: [URL] = []
        let fm = FileManager.default
        guard let e = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        for case let url as URL in e {
            if url.pathExtension == "swift" { out.append(url) }
        }
        return out
    }

    func files(matching extensions: Set<String>) -> [URL] {
        var out: [URL] = []
        let fm = FileManager.default
        guard let e = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        for case let url as URL in e {
            if extensions.contains(url.pathExtension.lowercased()) { out.append(url) }
        }
        return out
    }
}

