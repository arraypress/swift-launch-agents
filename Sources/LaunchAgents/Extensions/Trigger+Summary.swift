//
//  Trigger+Summary.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//
//  A trigger said back in the words it was given in — "weekdays at 07:00",
//  "every 15m" — so a list of jobs reads like a list of intentions.
//

import Foundation

public extension Trigger {

    /// The trigger in words.
    var summary: String {
        switch self {
        case .manual: return "by hand"
        case .atLoad: return "at login"
        case .interval(let seconds): return "every " + Self.duration(seconds)
        case .calendar(let slots): return Self.describe(slots)
        }
    }

    /// `90s`, `15m`, `2h`, `1d` — the largest unit that divides evenly.
    static func duration(_ seconds: Int) -> String {
        for (unit, size) in [("d", 86_400), ("h", 3600), ("m", 60)] where seconds % size == 0 {
            return "\(seconds / size)\(unit)"
        }
        return "\(seconds)s"
    }

    /// Calendar slots in words.
    static func describe(_ slots: [CalendarSlot]) -> String {
        guard !slots.isEmpty else { return "never" }
        let times = Array(Set(slots.map { slot -> String in
            switch (slot.hour, slot.minute) {
            case let (hour?, minute?): return String(format: "%02d:%02d", hour, minute)
            case let (nil, minute?): return String(format: "every hour at :%02d", minute)
            case let (hour?, nil): return String(format: "every minute of %02d:00", hour)
            default: return "every minute"
            }
        })).sorted()
        let weekdays = Set(slots.compactMap(\.weekday).map { $0 % 7 })
        let names = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        var days: String
        switch weekdays {
        case []: days = "daily"
        case [1, 2, 3, 4, 5]: days = "weekdays"
        case [0, 6]: days = "weekends"
        default: days = weekdays.sorted().map { names[$0] }.joined(separator: ",")
        }
        if let day = slots.compactMap(\.day).first { days = "on day \(day)" + (weekdays.isEmpty ? "" : " and \(days)") }
        return "\(days) at \(times.joined(separator: ", "))"
    }
}
