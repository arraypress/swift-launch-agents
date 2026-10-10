//
//  LaunchAgentError.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//
//  Failures a caller can act on, each naming what was wrong.
//

import Foundation

/// Why a job could not be scheduled, read or removed.
public enum LaunchAgentError: Error, LocalizedError, Sendable, Equatable {
    /// The name or schedule was not understood.
    case invalid(String)
    /// The program does not exist or cannot be run.
    case programNotFound(String)
    /// No job with that label.
    case notFound(String)
    /// A job with that name already exists.
    case exists(String)
    /// The job was not made by this tool; removing it needs `force`.
    case notOwn(String)
    /// launchctl refused, or said something unexpected.
    case launchctl(String)
    /// The change was made but launchd does not show it — a write that
    /// did not take.
    case unverified(String)

    public var errorDescription: String? {
        switch self {
        case .invalid(let why): return why
        case .programNotFound(let program): return "\(program) is not a program this Mac can run"
        case .notFound(let label): return "no job called \(label)"
        case .exists(let label): return "\(label) already exists"
        case .notOwn(let label): return "\(label) was not made by this tool; it is left alone without force"
        case .launchctl(let why): return "launchctl: \(why)"
        case .unverified(let why): return "launchd does not show the change: \(why)"
        }
    }
}
