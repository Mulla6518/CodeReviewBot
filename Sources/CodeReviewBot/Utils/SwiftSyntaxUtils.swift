//
//  SwiftSyntaxUtils.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation
import SwiftSyntax
import SwiftParser

struct SyntaxInfo {
    let tree: SourceFileSyntax
}

enum SwiftSyntaxUtils {
    static func parse(_ source: String) -> SyntaxInfo {
        let tree = Parser.parse(source: source)
        return SyntaxInfo(tree: tree)
    }

    static func lines(of source: String) -> [String] {
        source.components(separatedBy: .newlines)
    }
    
    /// Quick utility to check if a trimed line looks like a Swift function start.
    static func isFunctionStart(_ trimmedLine: String) -> Bool {
        trimmedLine.hasPrefix("func ")
    }
}

