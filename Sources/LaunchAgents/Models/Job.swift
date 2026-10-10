//
//  Job.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//
//  A job as it stands: its plist, read back, and launchd's view of it.
//

import Foundation

/// A LaunchAgent on disk, and whether launchd has it.
public struct Job: Sendable, Codable, Equatable {
    /// The launchd label.
    public let label: String
    /// Whether this tool made it — the label carries ``Labels/prefix``.
    public let isOwn: Bool
    /// The plist's path.
    public let path: String
    /// The program and its arguments.
    public let arguments: [String]
    /// When it runs, as read from the plist.
    public let trigger: Trigger
    /// Where its output goes.
    public let standardOutPath: String?
    /// Where its errors go.
    public let standardErrorPath: String?
    /// launchd's view, or nil when it is not loaded.
    public let status: JobStatus?
    /// The next calendar run, when it has one.
    public let nextRun: Date?

    public init(label: String, isOwn: Bool, path: String, arguments: [String], trigger: Trigger,
                standardOutPath: String?, standardErrorPath: String?, status: JobStatus?, nextRun: Date?) {
        self.label = label
        self.isOwn = isOwn
        self.path = path
        self.arguments = arguments
        self.trigger = trigger
        self.standardOutPath = standardOutPath
        self.standardErrorPath = standardErrorPath
        self.status = status
        self.nextRun = nextRun
    }

    /// The short name, without the prefix, for a job this tool made.
    public var name: String { isOwn ? String(label.dropFirst(Labels.prefix.count)) : label }
}
