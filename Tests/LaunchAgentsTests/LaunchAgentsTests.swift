//
//  LaunchAgentsTests.swift
//  LaunchAgentsTests
//
//  Created by David Sherlock on 2026.
//
//  The words-to-launchd rules with known answers, then the real thing:
//  jobs added to and removed from this Mac's launchd — from a scratch
//  folder, under throwaway names, running nothing but /bin/sh writing to
//  that folder, and always removed. The person's own LaunchAgents folder is
//  never read or written by these tests.
//

import Foundation
import Testing
@testable import LaunchAgents

@Suite("Schedules in words")
struct ScheduleParserTests {

    @Test("Durations take s, m, h and d", arguments: [("90s", 90), ("15m", 900), ("2h", 7200), ("1d", 86_400), ("45", 45)])
    func durations(text: String, seconds: Int) throws {
        #expect(try ScheduleParser.seconds(text) == seconds)
    }

    @Test("Nonsense durations are refused", arguments: ["", "0m", "-5m", "fifteen", "15y"])
    func badDurations(text: String) {
        #expect(throws: LaunchAgentError.self) { try ScheduleParser.seconds(text) }
    }

    @Test("Times are a 24-hour clock")
    func times() throws {
        #expect(try ScheduleParser.time("07:05") == (7, 5))
        #expect(throws: LaunchAgentError.self) { try ScheduleParser.time("24:00") }
        #expect(throws: LaunchAgentError.self) { try ScheduleParser.time("7pm") }
    }

    @Test("Days are counted as launchd counts them, Sunday 0")
    func days() throws {
        #expect(try ScheduleParser.weekdays("weekdays") == [1, 2, 3, 4, 5])
        #expect(try ScheduleParser.weekdays("weekends") == [0, 6])
        #expect(try ScheduleParser.weekdays("mon,Wednesday,fri") == [1, 3, 5])
        #expect(try ScheduleParser.weekdays("daily") == [])
        #expect(throws: LaunchAgentError.self) { try ScheduleParser.weekdays("funday") }
    }

    @Test("Every time on every day given is one slot each")
    func crossProduct() throws {
        let slots = try ScheduleParser.slots(times: ["07:00", "19:30"], days: [1, 5])
        #expect(slots.count == 4)
        #expect(slots.contains(CalendarSlot(minute: 30, hour: 19, weekday: 5)))
    }

    @Test("The next run of a weekday slot skips the weekend")
    func nextRun() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        // Saturday 2026-10-10 12:00 UTC → next weekday 07:00 is Monday the 12th.
        let saturday = Date(timeIntervalSince1970: 1_791_633_600)
        let slots = try ScheduleParser.slots(times: ["07:00"], days: try ScheduleParser.weekdays("weekdays"))
        let next = try #require(ScheduleParser.nextRun(of: slots, after: saturday, calendar: calendar))
        let parts = calendar.dateComponents([.weekday, .hour, .minute, .day], from: next)
        #expect(parts.weekday == 2)
        #expect(parts.day == 12)
        #expect(parts.hour == 7 && parts.minute == 0)
    }
}

@Suite("Plists")
struct PlistTests {

    @Test("A calendar job round-trips through its plist")
    func roundTrip() throws {
        let slots = [CalendarSlot(minute: 0, hour: 7, weekday: 1), CalendarSlot(minute: 0, hour: 7, weekday: 2)]
        let spec = JobSpec(name: "x", arguments: ["/bin/echo", "hi"], trigger: .calendar(slots))
        let plist = PlistBuilder.plist(for: spec, label: "local.schedule.x")
        #expect(PlistBuilder.trigger(of: plist) == .calendar(slots))
        #expect((plist["StartCalendarInterval"] as? [[String: Int]])?.count == 2)
    }

    @Test("A single slot is written as a dictionary, as launchd's own docs show")
    func single() {
        let spec = JobSpec(name: "x", arguments: ["/bin/echo"], trigger: .calendar([CalendarSlot(minute: 0, hour: 7)]))
        #expect(PlistBuilder.plist(for: spec, label: "l")["StartCalendarInterval"] is [String: Int])
    }

    @Test("Homebrew is on the PATH unless one is given")
    func path() {
        let spec = JobSpec(name: "x", arguments: ["/bin/echo"], trigger: .interval(60))
        #expect((PlistBuilder.plist(for: spec, label: "l")["EnvironmentVariables"] as? [String: String])?["PATH"]
                == PlistBuilder.defaultPath)
        var own = spec
        own.environment = ["PATH": "/bin"]
        #expect((PlistBuilder.plist(for: own, label: "l")["EnvironmentVariables"] as? [String: String])?["PATH"] == "/bin")
    }

    @Test("An at-login job runs at load")
    func atLoad() {
        let plist = PlistBuilder.plist(for: JobSpec(name: "x", arguments: ["/bin/echo"], trigger: .atLoad), label: "l")
        #expect(plist["RunAtLoad"] as? Bool == true)
        #expect(PlistBuilder.trigger(of: plist) == .atLoad)
    }
}

@Suite("Labels and print-outs")
struct LabelTests {

    @Test("Names become prefixed labels; bad names are refused")
    func labels() throws {
        #expect(try Labels.label(for: "backup") == "local.schedule.backup")
        #expect(try Labels.label(for: "local.schedule.backup") == "local.schedule.backup")
        #expect(throws: LaunchAgentError.self) { try Labels.label(for: "../evil") }
        #expect(throws: LaunchAgentError.self) { try Labels.label(for: "") }
        #expect(Labels.isOwn("local.schedule.x"))
        #expect(!Labels.isOwn("com.google.keystone.agent"))
    }

    @Test("launchctl print is read at the top level only")
    func printParser() {
        let text = "gui/501/l = {\n\tactive count = 0\n\tpath = /tmp/l.plist\n\tstate = not running\n\truns = 3\n"
            + "\tlast exit code = 1\n\tevent triggers = {\n\t\tstate = active\n\t}\n}\n"
        let status = PrintParser.status(from: text)
        #expect(status.state == "not running", "the nested 'state = active' must not win")
        #expect(status.runs == 3)
        #expect(status.lastExitCode == 1)
        #expect(status.path == "/tmp/l.plist")
        #expect(PrintParser.status(from: "\tlast exit code = (never exited)\n").lastExitCode == nil)
    }

    @Test("A bare program is found on the PATH")
    func resolve() throws {
        #expect(try Scheduler.resolve("true", path: "/usr/bin:/bin") == "/usr/bin/true")
        #expect(throws: LaunchAgentError.self) { try Scheduler.resolve("no-such-program-xyz", path: "/usr/bin") }
    }
}

@Suite("Against launchd", .serialized)
struct LaunchdTests {

    /// A scheduler over a scratch folder, so the person's LaunchAgents are untouched.
    func scratch() throws -> (Scheduler, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("launch-agents-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (Scheduler(folder: root.appendingPathComponent("agents"), logFolder: root.appendingPathComponent("logs")), root)
    }

    @Test("A job is added, loaded, run, logged, listed and removed — and launchd agrees each time")
    func lifecycle() async throws {
        let (scheduler, root) = try scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let name = "test-\(UUID().uuidString.prefix(8))"
        defer { try? scheduler.remove(name) }

        let added = try scheduler.add(JobSpec(name: name, arguments: ["/bin/sh", "-c", "echo ran-\(name)"],
                                              trigger: .calendar(try ScheduleParser.slots(times: ["03:17"], days: []))))
        #expect(added.status != nil, "launchd has it")
        #expect(added.isOwn)
        #expect(added.nextRun != nil)
        #expect(try scheduler.list().map(\.name) == [name])
        #expect(throws: LaunchAgentError.self) { try scheduler.add(JobSpec(name: name, arguments: ["/usr/bin/true"], trigger: .manual)) }

        try scheduler.run(name)
        var lines: [String] = []
        for _ in 0..<40 where lines.isEmpty {
            try await Task.sleep(nanoseconds: 100_000_000)
            lines = try scheduler.logs(of: name)
        }
        #expect(lines.contains("ran-\(name)"))
        #expect(try scheduler.job(named: name).status?.runs == 1)

        try scheduler.remove(name)
        #expect(try scheduler.list().isEmpty)
        #expect(try Launchctl().status(Labels.label(for: name)) == nil, "launchd no longer has it")
    }

    @Test("A job this tool did not make is not removed without force")
    func notOwn() throws {
        let (scheduler, root) = try scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        let label = "com.example.notours-\(UUID().uuidString.prefix(8))"
        try FileManager.default.createDirectory(at: scheduler.folder, withIntermediateDirectories: true)
        let plist = ["Label": label, "ProgramArguments": ["/usr/bin/true"]] as [String: Any]
        try PlistBuilder.data(for: plist).write(to: scheduler.folder.appendingPathComponent("\(label).plist"))
        #expect(try scheduler.list().isEmpty, "only this tool's jobs by default")
        #expect(try scheduler.list(includingOthers: true).map(\.label) == [label])
        #expect(throws: LaunchAgentError.notOwn(label)) { try scheduler.remove(label) }
        try scheduler.remove(label, force: true)
        #expect(try scheduler.list(includingOthers: true).isEmpty)
    }

    @Test("A program that does not exist is refused before anything is written")
    func missingProgram() throws {
        let (scheduler, root) = try scratch()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: LaunchAgentError.self) {
            try scheduler.add(JobSpec(name: "nope", arguments: ["no-such-program-xyz"], trigger: .manual))
        }
        #expect(!FileManager.default.fileExists(atPath: scheduler.folder.appendingPathComponent("local.schedule.nope.plist").path))
    }
}

@Suite("Triggers in words")
struct SummaryTests {

    @Test("A schedule reads back as it was asked for")
    func words() throws {
        #expect(Trigger.calendar(try ScheduleParser.slots(times: ["07:00"], days: [1, 2, 3, 4, 5])).summary == "weekdays at 07:00")
        #expect(Trigger.calendar(try ScheduleParser.slots(times: ["19:30", "07:00"], days: [])).summary == "daily at 07:00, 19:30")
        #expect(Trigger.calendar(try ScheduleParser.slots(times: ["09:00"], days: [1, 3])).summary == "mon,wed at 09:00")
        #expect(Trigger.calendar(try ScheduleParser.slots(times: ["09:00"], days: [], dayOfMonth: 1)).summary == "on day 1 at 09:00")
        #expect(Trigger.interval(900).summary == "every 15m")
        #expect(Trigger.interval(7200).summary == "every 2h")
        #expect(Trigger.interval(90).summary == "every 90s")
        #expect(Trigger.atLoad.summary == "at login")
    }
}

@Suite("Watched folders")
struct WatchTests {

    @Test("A watch job round-trips through its plist as WatchPaths")
    func roundTrip() {
        let spec = JobSpec(name: "x", arguments: ["/bin/echo"], trigger: .watch(["/tmp/inbox"]))
        let plist = PlistBuilder.plist(for: spec, label: "l")
        #expect(plist["WatchPaths"] as? [String] == ["/tmp/inbox"])
        #expect(PlistBuilder.trigger(of: plist) == .watch(["/tmp/inbox"]))
        #expect(Trigger.watch([NSHomeDirectory() + "/Drop"]).summary == "when ~/Drop changes")
    }

    @Test("Only finished, unseen, visible files are pending, oldest first")
    func pending() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        func file(_ name: String, _ age: TimeInterval, size: Int64 = 10) -> FileStamp {
            FileStamp(name: name, size: size, modified: now.addingTimeInterval(-age))
        }
        let done = file("old.pdf", 600)
        let listing = [file("b.pdf", 30), file("a.pdf", 60), done, file(".DS_Store", 60),
                       file("big.mov.crdownload", 60), file("photo.jpg.part", 60), file("growing.csv", 0.5)]
        let names = NewFiles.pending(listing, seen: [done.identity], now: now).map(\.name)
        #expect(names == ["a.pdf", "b.pdf"])
        // A newer copy under the same name counts as new again.
        #expect(NewFiles.pending([file("old.pdf", 60, size: 99)], seen: [done.identity], now: now).count == 1)
    }

    @Test("The listing reads regular files only")
    func listing() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("watch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("sub"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("hi".utf8).write(to: folder.appendingPathComponent("a.txt"))
        let listing = try NewFiles.listing(of: folder)
        #expect(listing.map(\.name) == ["a.txt"])
        #expect(listing.first?.size == 2)
    }
}
