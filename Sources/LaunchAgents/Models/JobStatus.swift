//
//  JobStatus.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//
//  What launchd says about a loaded job, read from `launchctl print`.
//

import Foundation

/// A loaded job's state, as launchd reports it.
public struct JobStatus: Sendable, Codable, Equatable {
    /// "running", "not running", "waiting" …
    public let state: String
    /// The process id while it runs.
    public let pid: Int?
    /// How many times launchd has started it since it was loaded.
    public let runs: Int
    /// The last exit code, or nil when it has never exited.
    public let lastExitCode: Int?
    /// The plist launchd loaded it from.
    public let path: String?

    public init(state: String, pid: Int?, runs: Int, lastExitCode: Int?, path: String?) {
        self.state = state
        self.pid = pid
        self.runs = runs
        self.lastExitCode = lastExitCode
        self.path = path
    }
}
