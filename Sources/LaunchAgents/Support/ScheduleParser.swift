//
//  ScheduleParser.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//
//  Schedules in words into launchd's terms: "07:00", "every 15m",
//  "weekdays". Pure, so every spelling a person or an agent types can be
//  tested against the slots it should become.
//

import Foundation

/// Parses schedule words.
public enum ScheduleParser {

    /// A duration: `90s`, `15m`, `2h`, `1d`, or plain seconds.
    ///
    /// - Returns: Seconds, at least 1.
    /// - Throws: ``LaunchAgentError/invalid(_:)``.
    public static func seconds(_ text: String) throws -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        let units: [Character: Int] = ["s": 1, "m": 60, "h": 3600, "d": 86_400]
        var number = trimmed, multiplier = 1
        if let last = trimmed.last, let unit = units[last] {
            number = String(trimmed.dropLast())
            multiplier = unit
        }
        guard let value = Int(number), value > 0 else {
            throw LaunchAgentError.invalid("a duration is a number with s, m, h or d: \(text)")
        }
        return value * multiplier
    }

    /// A time of day: `07:00`, `7:05`, `19:30`.
    ///
    /// - Returns: The hour and minute.
    /// - Throws: ``LaunchAgentError/invalid(_:)``.
    public static func time(_ text: String) throws -> (hour: Int, minute: Int) {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else {
            throw LaunchAgentError.invalid("a time is HH:MM on a 24-hour clock: \(text)")
        }
        return (hour, minute)
    }

    /// Days of the week, in launchd's numbering (0 = Sunday … 6 = Saturday).
    ///
    /// Takes `weekdays`, `weekends`, `daily`, or names: `mon,wed,fri`.
    ///
    /// - Returns: The days, or empty for every day.
    /// - Throws: ``LaunchAgentError/invalid(_:)``.
    public static func weekdays(_ text: String) throws -> [Int] {
        let names = ["sun": 0, "mon": 1, "tue": 2, "wed": 3, "thu": 4, "fri": 5, "sat": 6]
        switch text.lowercased() {
        case "daily", "everyday", "every day": return []
        case "weekdays": return [1, 2, 3, 4, 5]
        case "weekends": return [0, 6]
        default:
            return try text.lowercased().split(separator: ",").map { word in
                let key = String(word.trimmingCharacters(in: .whitespaces).prefix(3))
                guard let day = names[key] else {
                    throw LaunchAgentError.invalid("a day is mon…sun, weekdays, weekends or daily: \(word)")
                }
                return day
            }
        }
    }

    /// Calendar slots for times on days: every time, on every day given.
    ///
    /// - Parameters:
    ///   - times: `HH:MM` strings.
    ///   - days: launchd weekday numbers, or empty for every day.
    ///   - dayOfMonth: A day of the month, 1–31, or nil.
    /// - Returns: One slot per time and day.
    public static func slots(times: [String], days: [Int], dayOfMonth: Int? = nil) throws -> [CalendarSlot] {
        if let dayOfMonth, !(1...31).contains(dayOfMonth) {
            throw LaunchAgentError.invalid("a day of the month is 1–31: \(dayOfMonth)")
        }
        let clock = try times.map(time)
        guard !clock.isEmpty else { throw LaunchAgentError.invalid("give at least one time") }
        let weekdays: [Int?] = days.isEmpty ? [nil] : days
        return clock.flatMap { moment in
            weekdays.map { CalendarSlot(minute: moment.minute, hour: moment.hour, day: dayOfMonth, weekday: $0) }
        }
    }

    /// The next time a set of slots fires after a moment.
    ///
    /// - Parameters:
    ///   - slots: The slots.
    ///   - date: The moment to count from.
    ///   - calendar: The calendar and time zone launchd uses — the Mac's.
    /// - Returns: The earliest next firing, or nil when there are no slots.
    public static func nextRun(of slots: [CalendarSlot], after date: Date, calendar: Calendar = .current) -> Date? {
        slots.compactMap { slot -> Date? in
            var components = DateComponents()
            components.minute = slot.minute
            components.hour = slot.hour
            components.day = slot.day
            components.month = slot.month
            // launchd counts Sunday as 0 (or 7); Foundation as 1.
            if let weekday = slot.weekday { components.weekday = weekday % 7 + 1 }
            if slot.minute == nil, slot.hour == nil { components.second = 0 }
            return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
        }.min()
    }
}
