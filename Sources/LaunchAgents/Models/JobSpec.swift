//
//  JobSpec.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//
//  Everything a scheduled job is, before it becomes a launchd plist.
//

import Foundation

/// A job to schedule.
public struct JobSpec: Sendable, Codable, Equatable {
    /// The short name: letters, digits, dots, dashes, underscores. The
    /// launchd label is ``Labels/prefix`` + this.
    public var name: String
    /// The program and its arguments; the program as an absolute path.
    public var arguments: [String]
    /// When it runs.
    public var trigger: Trigger
    /// Also run as soon as it is loaded.
    public var runAtLoad: Bool
    /// Restart it whenever it exits — a long-running service, not a task.
    public var keepAlive: Bool
    /// Environment variables. `PATH` is filled in when absent; see
    /// ``PlistBuilder/defaultPath``.
    public var environment: [String: String]
    /// The directory it runs in.
    public var workingDirectory: String?
    /// Where its standard output goes.
    public var standardOutPath: String?
    /// Where its standard error goes.
    public var standardErrorPath: String?

    /// - Parameters:
    ///   - name: The short name.
    ///   - arguments: Program and arguments.
    ///   - trigger: When it runs.
    ///   - runAtLoad: Also run when loaded.
    ///   - keepAlive: Restart on exit.
    ///   - environment: Environment variables.
    ///   - workingDirectory: Where it runs.
    ///   - standardOutPath: Standard output file.
    ///   - standardErrorPath: Standard error file.
    public init(name: String, arguments: [String], trigger: Trigger, runAtLoad: Bool = false,
                keepAlive: Bool = false, environment: [String: String] = [:], workingDirectory: String? = nil,
                standardOutPath: String? = nil, standardErrorPath: String? = nil) {
        self.name = name
        self.arguments = arguments
        self.trigger = trigger
        self.runAtLoad = runAtLoad
        self.keepAlive = keepAlive
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.standardOutPath = standardOutPath
        self.standardErrorPath = standardErrorPath
    }
}
