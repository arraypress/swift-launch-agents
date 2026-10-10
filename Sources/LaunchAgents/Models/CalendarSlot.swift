//
//  CalendarSlot.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//
//  One `StartCalendarInterval` entry: a wall-clock moment that repeats.
//  Each field left nil is a wildcard, exactly as launchd reads it — a slot
//  with only `hour` and `minute` fires every day at that time.
//

import Foundation

/// A repeating moment on the calendar.
public struct CalendarSlot: Sendable, Codable, Equatable, Hashable {
    /// 0–59, or nil for every minute.
    public var minute: Int?
    /// 0–23, or nil for every hour.
    public var hour: Int?
    /// 1–31, or nil for every day of the month.
    public var day: Int?
    /// 0–7 with 0 and 7 both Sunday, as launchd counts, or nil for every day.
    public var weekday: Int?
    /// 1–12, or nil for every month.
    public var month: Int?

    /// - Parameters:
    ///   - minute: The minute.
    ///   - hour: The hour.
    ///   - day: The day of the month.
    ///   - weekday: The day of the week, 0 = Sunday.
    ///   - month: The month.
    public init(minute: Int? = nil, hour: Int? = nil, day: Int? = nil, weekday: Int? = nil, month: Int? = nil) {
        self.minute = minute
        self.hour = hour
        self.day = day
        self.weekday = weekday
        self.month = month
    }
}
