//
//  Launchctl.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//
//  The one door to launchd. Everything goes through `launchctl` with the
//  modern verbs — bootstrap, bootout, kickstart, kill, print — in the
//  person's own GUI domain, which is where LaunchAgents live and which
//  needs no privileges.
//

import Foundation

/// Runs `launchctl`.
public struct Launchctl: Sendable {

    /// What one invocation said.
    public struct Output: Sendable {
        public let status: Int32
        public let text: String
        public let error: String
    }

    /// The domain jobs are loaded into: `gui/<uid>`.
    public let domain: String

    /// - Parameter domain: Defaults to the current user's GUI domain.
    public init(domain: String = "gui/\(getuid())") {
        self.domain = domain
    }

    /// Runs `launchctl` with arguments.
    @discardableResult
    public func run(_ arguments: [String]) throws -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do { try process.run() } catch { throw LaunchAgentError.launchctl(error.localizedDescription) }
        // Read before waiting: a print-out larger than the pipe buffer would
        // otherwise block launchctl and this process on each other.
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let error = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return Output(status: process.terminationStatus, text: text, error: error)
    }

    /// Loads a plist into the domain.
    public func bootstrap(_ plist: URL) throws {
        let result = try run(["bootstrap", domain, plist.path])
        guard result.status == 0 else { throw LaunchAgentError.launchctl(message(result, "bootstrap")) }
    }

    /// Unloads a job; succeeds quietly when it was not loaded.
    public func bootout(_ label: String) throws {
        let result = try run(["bootout", "\(domain)/\(label)"])
        // 3 / 113: no such process / service — already gone, which is the goal.
        guard [0, 3, 113].contains(result.status) else { throw LaunchAgentError.launchctl(message(result, "bootout")) }
    }

    /// Starts a job now, whatever its schedule.
    public func kickstart(_ label: String) throws {
        let result = try run(["kickstart", "\(domain)/\(label)"])
        guard result.status == 0 else { throw LaunchAgentError.launchctl(message(result, "kickstart")) }
    }

    /// Sends a running job SIGTERM.
    public func stop(_ label: String) throws {
        let result = try run(["kill", "SIGTERM", "\(domain)/\(label)"])
        guard [0, 3].contains(result.status) else { throw LaunchAgentError.launchctl(message(result, "kill")) }
    }

    /// launchd's status for a job, or nil when it is not loaded.
    public func status(_ label: String) throws -> JobStatus? {
        let result = try run(["print", "\(domain)/\(label)"])
        guard result.status == 0 else { return nil }
        return PrintParser.status(from: result.text)
    }

    private func message(_ output: Output, _ verb: String) -> String {
        let said = (output.error.isEmpty ? output.text : output.error).trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(verb) exited \(output.status)" + (said.isEmpty ? "" : ": \(said)")
    }
}
