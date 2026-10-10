//
//  PrintParser.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//
//  `launchctl print` into a status. Its output is for people, not
//  programs — nested braces, `key = value` lines, "(never exited)" where a
//  number would be — and Apple calls the format unstable, so only the five
//  top-level keys this needs are read, each optional.
//

import Foundation

/// Reads `launchctl print gui/<uid>/<label>`.
public enum PrintParser {

    /// The status in a service's print-out.
    ///
    /// - Parameter text: What `launchctl print` wrote.
    /// - Returns: The state, pid, run count, last exit code and plist path.
    public static func status(from text: String) -> JobStatus {
        var values: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            // Top-level keys sit one tab in; deeper ones belong to nested blocks.
            guard line.hasPrefix("\t"), !line.hasPrefix("\t\t"),
                  let equals = line.range(of: " = ") else { continue }
            let key = line[..<equals.lowerBound].trimmingCharacters(in: .whitespaces)
            let value = line[equals.upperBound...].trimmingCharacters(in: .whitespaces)
            if values[key] == nil { values[key] = value }
        }
        return JobStatus(state: values["state"] ?? "unknown",
                         pid: values["pid"].flatMap { Int($0) },
                         runs: values["runs"].flatMap { Int($0) } ?? 0,
                         lastExitCode: values["last exit code"].flatMap { Int($0) },
                         path: values["path"])
    }
}
