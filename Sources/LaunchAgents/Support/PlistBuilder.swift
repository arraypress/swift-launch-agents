//
//  PlistBuilder.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//
//  A job into launchd's plist, and a plist back into a job — both pure, so
//  the keys launchd reads are tested without asking launchd anything.
//

import Foundation

/// Builds and reads LaunchAgent property lists.
public enum PlistBuilder {

    /// The PATH a job gets when none is given.
    ///
    /// launchd's own is `/usr/bin:/bin:/usr/sbin:/sbin`, so a job that calls
    /// a Homebrew tool by name fails at 07:00 with "command not found" after
    /// working perfectly when tried by hand. Homebrew's folders go first.
    public static let defaultPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    /// The plist for a job.
    ///
    /// - Parameters:
    ///   - spec: The job.
    ///   - label: Its launchd label.
    /// - Returns: The dictionary to serialise.
    public static func plist(for spec: JobSpec, label: String) -> [String: Any] {
        var plist: [String: Any] = ["Label": label, "ProgramArguments": spec.arguments]
        switch spec.trigger {
        case .calendar(let slots):
            let entries = slots.map(entry)
            plist["StartCalendarInterval"] = entries.count == 1 ? entries[0] as Any : entries as Any
        case .interval(let seconds):
            plist["StartInterval"] = seconds
        case .atLoad, .manual:
            break
        }
        if spec.runAtLoad || spec.trigger == .atLoad { plist["RunAtLoad"] = true }
        if spec.keepAlive { plist["KeepAlive"] = true }
        var environment = spec.environment
        if environment["PATH"] == nil { environment["PATH"] = defaultPath }
        plist["EnvironmentVariables"] = environment
        if let directory = spec.workingDirectory { plist["WorkingDirectory"] = directory }
        if let out = spec.standardOutPath { plist["StandardOutPath"] = out }
        if let err = spec.standardErrorPath { plist["StandardErrorPath"] = err }
        return plist
    }

    /// The bytes of a plist, XML so a person can read and diff it.
    public static func data(for plist: [String: Any]) throws -> Data {
        do {
            return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        } catch {
            throw LaunchAgentError.invalid("the job could not be written as a plist: \(error.localizedDescription)")
        }
    }

    /// When a plist says its job runs.
    public static func trigger(of plist: [String: Any]) -> Trigger {
        if let one = plist["StartCalendarInterval"] as? [String: Any] { return .calendar([slot(one)]) }
        if let many = plist["StartCalendarInterval"] as? [[String: Any]] { return .calendar(many.map(slot)) }
        if let seconds = plist["StartInterval"] as? Int { return .interval(seconds) }
        if plist["RunAtLoad"] as? Bool == true { return .atLoad }
        return .manual
    }

    static func entry(_ slot: CalendarSlot) -> [String: Int] {
        var entry: [String: Int] = [:]
        if let minute = slot.minute { entry["Minute"] = minute }
        if let hour = slot.hour { entry["Hour"] = hour }
        if let day = slot.day { entry["Day"] = day }
        if let weekday = slot.weekday { entry["Weekday"] = weekday }
        if let month = slot.month { entry["Month"] = month }
        return entry
    }

    static func slot(_ entry: [String: Any]) -> CalendarSlot {
        CalendarSlot(minute: entry["Minute"] as? Int, hour: entry["Hour"] as? Int, day: entry["Day"] as? Int,
                     weekday: entry["Weekday"] as? Int, month: entry["Month"] as? Int)
    }
}
