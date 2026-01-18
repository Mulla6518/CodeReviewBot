//
//  Logger.swift
//  CodeReviewBot
//
//  Created by Farooq Mulla on 1/10/26.
//

import Foundation

public enum LogLevel: String {
    case debug = "DEBUG"
    case info  = "INFO"
    case warn  = "WARN"
    case error = "ERROR"
}

public final class Logger {
    nonisolated(unsafe) public static let shared = Logger()
    private init() {}

    public func log(_ level: LogLevel, _ message: String) {
        #if DEBUG
        print("[\(level.rawValue)] \(message)")
        #else
        if level == .error || level == .warn {
            print("[\(level.rawValue)] \(message)")
        }
        #endif
    }
}

