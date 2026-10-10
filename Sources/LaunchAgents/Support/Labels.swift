//
//  Labels.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//
//  How this tool tells its own jobs from everyone else's. A Mac's
//  LaunchAgents folder holds updaters, sync clients and helpers the person
//  never chose to touch; every job made here carries one prefix, so `list`
//  can show only those and `remove` can refuse the rest.
//

import Foundation

/// The label namespace for jobs this tool makes.
public enum Labels {

    /// Every job made here is labelled `local.schedule.<name>`. "local." is
    /// the convention for jobs a person made on their own machine, and it
    /// names no company, so it survives whatever this tool is called later.
    public static let prefix = "local.schedule."

    /// The label for a short name.
    ///
    /// - Throws: ``LaunchAgentError/invalid(_:)`` unless the name is 1–64
    ///   letters, digits, dots, dashes or underscores — what a filename and
    ///   a launchd label can both hold.
    public static func label(for name: String) throws -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        guard (1...64).contains(name.count), name.unicodeScalars.allSatisfy(allowed.contains),
              !name.hasPrefix(".") else {
            throw LaunchAgentError.invalid("a job name is 1–64 letters, digits, dots, dashes or underscores: \(name)")
        }
        return name.hasPrefix(prefix) ? name : prefix + name
    }

    /// Whether a label is one this tool made.
    public static func isOwn(_ label: String) -> Bool { label.hasPrefix(prefix) }
}
