//
//  FileStamp.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One file as a folder listing sees it: enough to tell a new arrival from
/// one already handled, and a finished file from one still being written.
public struct FileStamp: Sendable, Codable, Equatable, Hashable {
    /// The file's name inside the watched folder.
    public let name: String
    /// Its size in bytes.
    public let size: Int64
    /// When it last changed.
    public let modified: Date

    public init(name: String, size: Int64, modified: Date) {
        self.name = name
        self.size = size
        self.modified = modified
    }

    /// What is remembered once it is handled: the same name with a new size
    /// or date (a file replaced by a newer copy) counts as new again.
    public var identity: String { "\(name)\t\(size)\t\(Int(modified.timeIntervalSince1970))" }
}
