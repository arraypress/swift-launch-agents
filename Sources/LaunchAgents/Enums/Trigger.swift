//
//  Trigger.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//
//  When a job runs. launchd offers more (sockets, mounts); these are the
//  ones a person asks for in words — at seven, every fifteen minutes, when I
//  log in, when something lands in this folder.
//

import Foundation

/// What starts a job.
public enum Trigger: Sendable, Codable, Equatable, Hashable {
    /// At these wall-clock moments. A Mac asleep at the time runs the job
    /// once on waking — launchd coalesces missed calendar runs.
    case calendar([CalendarSlot])
    /// Every this many seconds, counted from when the job was loaded.
    case interval(Int)
    /// Only when loaded — at login, or when added.
    case atLoad
    /// Never on its own: only when run by hand.
    case manual
    /// Whenever one of these paths changes — launchd's `WatchPaths`. For a
    /// folder, that is a file arriving, leaving or being renamed in it (not
    /// a change inside a file already there). launchd says only THAT it
    /// changed, never which file: see ``NewFiles``.
    case watch([String])
}
