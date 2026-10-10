//
//  Scheduler.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//
//  The front door: add, list, run, stop and remove the person's own
//  scheduled jobs. Every change is checked against launchd afterwards — a
//  plist written but not loaded is the classic silent failure of a cron
//  replacement, and it is reported as one.
//

import Foundation

/// Manages LaunchAgents in one folder and one launchd domain.
///
/// ```swift
/// let scheduler = Scheduler()
/// try scheduler.add(JobSpec(name: "backup", arguments: ["/usr/bin/rsync", "-a", src, dst],
///                           trigger: .calendar(try ScheduleParser.slots(times: ["02:00"], days: []))))
/// try scheduler.list()          // the jobs this tool made, with launchd's status
/// try scheduler.remove("backup")
/// ```
public struct Scheduler: Sendable {

    /// Where plists live: `~/Library/LaunchAgents` unless a test says otherwise.
    public let folder: URL
    /// The launchctl wrapper, carrying the domain.
    public let launchctl: Launchctl
    /// Where jobs log by default: `~/Library/Logs/schedule`.
    public let logFolder: URL

    /// - Parameters:
    ///   - folder: The LaunchAgents folder.
    ///   - logFolder: The default log folder.
    ///   - launchctl: The launchctl runner.
    public init(folder: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents"),
                logFolder: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/schedule"),
                launchctl: Launchctl = Launchctl()) {
        self.folder = folder
        self.logFolder = logFolder
        self.launchctl = launchctl
    }

    // MARK: - Adding

    /// Writes a job's plist, loads it, and checks launchd has it.
    ///
    /// The program is resolved to an absolute path first — launchd does not
    /// search a PATH for the program itself — and its output goes to
    /// `<logFolder>/<name>.log` unless the spec says otherwise.
    ///
    /// - Parameters:
    ///   - spec: The job.
    ///   - replacing: Replace a job of the same name rather than refusing.
    /// - Returns: The job as launchd now holds it.
    /// - Throws: ``LaunchAgentError``.
    @discardableResult
    public func add(_ spec: JobSpec, replacing: Bool = false) throws -> Job {
        let label = try Labels.label(for: spec.name)
        let path = plistURL(label)
        if FileManager.default.fileExists(atPath: path.path) {
            guard replacing else { throw LaunchAgentError.exists(label) }
            try remove(spec.name)
        }
        var spec = spec
        guard let program = spec.arguments.first else { throw LaunchAgentError.invalid("give a program to run") }
        spec.arguments[0] = try Self.resolve(program, path: spec.environment["PATH"] ?? PlistBuilder.defaultPath)
        let log = logFolder.appendingPathComponent("\(spec.name).log").path
        if spec.standardOutPath == nil { spec.standardOutPath = log }
        if spec.standardErrorPath == nil { spec.standardErrorPath = log }
        try FileManager.default.createDirectory(at: logFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let data = try PlistBuilder.data(for: PlistBuilder.plist(for: spec, label: label))
        do { try data.write(to: path, options: .atomic) } catch {
            throw LaunchAgentError.invalid("could not write \(path.path): \(error.localizedDescription)")
        }
        do {
            try launchctl.bootstrap(path)
        } catch {
            try? FileManager.default.removeItem(at: path)
            throw error
        }
        // launchd reports the path with symlinks resolved (/private/var for
        // /var), so both sides are resolved before they are compared.
        guard let status = try launchctl.status(label),
              status.path.map({ URL(fileURLWithPath: $0).resolvingSymlinksInPath().path })
                == path.resolvingSymlinksInPath().path else {
            try? launchctl.bootout(label)
            try? FileManager.default.removeItem(at: path)
            throw LaunchAgentError.unverified("\(label) was written but launchd did not load it")
        }
        return try job(label, status: status)
    }

    // MARK: - Reading

    /// The jobs in the folder, with launchd's view of each.
    ///
    /// - Parameter includingOthers: Also list jobs this tool did not make.
    /// - Returns: The jobs, sorted by label.
    public func list(includingOthers: Bool = false) throws -> [Job] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return try files.filter { $0.pathExtension == "plist" }
            .compactMap { file -> Job? in
                guard let plist = Self.read(file), let label = plist["Label"] as? String else { return nil }
                guard includingOthers || Labels.isOwn(label) else { return nil }
                return try job(label, plist: plist, path: file, status: launchctl.status(label))
            }
            .sorted { $0.label < $1.label }
    }

    /// One job by name or label.
    ///
    /// - Throws: ``LaunchAgentError/notFound(_:)``.
    public func job(named name: String) throws -> Job {
        return try job(try label(for: name), status: launchctl.status(try label(for: name)))
    }

    /// The last lines a job wrote to its log.
    ///
    /// - Parameters:
    ///   - name: The job.
    ///   - lines: How many lines from the end.
    /// - Returns: The lines, oldest first; empty when it has written nothing.
    public func logs(of name: String, lines: Int = 50) throws -> [String] {
        let job = try job(named: name)
        let paths = Set([job.standardOutPath, job.standardErrorPath].compactMap { $0 })
        let text = paths.compactMap { try? String(contentsOfFile: $0, encoding: .utf8) }.joined(separator: "\n")
        return Array(text.split(whereSeparator: \.isNewline).map(String.init).suffix(lines))
    }

    // MARK: - Changing

    /// Runs a job now.
    public func run(_ name: String) throws {
        let job = try job(named: name)
        guard job.status != nil else { throw LaunchAgentError.unverified("\(job.label) is not loaded") }
        try launchctl.kickstart(job.label)
    }

    /// Stops a running job; a scheduled one still runs next time.
    public func stop(_ name: String) throws {
        try launchctl.stop(try job(named: name).label)
    }

    /// Unloads a job and deletes its plist, then checks both are gone.
    ///
    /// - Parameters:
    ///   - name: The job.
    ///   - force: Remove a job this tool did not make.
    /// - Throws: ``LaunchAgentError/notOwn(_:)`` without `force`.
    public func remove(_ name: String, force: Bool = false) throws {
        let job = try job(named: name)
        guard job.isOwn || force else { throw LaunchAgentError.notOwn(job.label) }
        try launchctl.bootout(job.label)
        try? FileManager.default.removeItem(atPath: job.path)
        if try launchctl.status(job.label) != nil || FileManager.default.fileExists(atPath: job.path) {
            throw LaunchAgentError.unverified("\(job.label) is still loaded or its plist is still there")
        }
    }

    // MARK: - Pieces

    func plistURL(_ label: String) -> URL { folder.appendingPathComponent("\(label).plist") }

    /// The label a name refers to: this tool's own job by short name, or any
    /// job by its full label when a plist of that label is in the folder —
    /// so `remove com.vendor.updater --force` can reach one it did not make.
    func label(for name: String) throws -> String {
        if Labels.isOwn(name) { return name }
        if FileManager.default.fileExists(atPath: plistURL(name).path) { return name }
        return try Labels.label(for: name)
    }

    func job(_ label: String, status: JobStatus?) throws -> Job {
        let path = URL(fileURLWithPath: status?.path ?? plistURL(label).path)
        guard let plist = Self.read(path) else { throw LaunchAgentError.notFound(label) }
        return try job(label, plist: plist, path: path, status: status)
    }

    func job(_ label: String, plist: [String: Any], path: URL, status: JobStatus?) throws -> Job {
        let trigger = PlistBuilder.trigger(of: plist)
        var next: Date?
        if case .calendar(let slots) = trigger { next = ScheduleParser.nextRun(of: slots, after: Date()) }
        let arguments = plist["ProgramArguments"] as? [String] ?? [plist["Program"] as? String].compactMap { $0 }
        return Job(label: label, isOwn: Labels.isOwn(label), path: path.path, arguments: arguments, trigger: trigger,
                   standardOutPath: plist["StandardOutPath"] as? String,
                   standardErrorPath: plist["StandardErrorPath"] as? String, status: status, nextRun: next)
    }

    static func read(_ url: URL) -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: url.path) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    /// A program as an absolute path, searched for on `path` when bare.
    ///
    /// - Throws: ``LaunchAgentError/programNotFound(_:)``.
    static func resolve(_ program: String, path: String) throws -> String {
        let expanded = (program as NSString).expandingTildeInPath
        if expanded.contains("/") {
            let absolute = URL(fileURLWithPath: expanded).standardizedFileURL.path
            guard FileManager.default.isExecutableFile(atPath: absolute) else {
                throw LaunchAgentError.programNotFound(program)
            }
            return absolute
        }
        for directory in path.split(separator: ":") {
            let candidate = "\(directory)/\(expanded)"
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        throw LaunchAgentError.programNotFound(program)
    }
}
