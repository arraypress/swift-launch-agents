//
//  HomebrewPaths.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//
//  The path a job should name for a Homebrew-installed program. Homebrew
//  puts a tool's files under a versioned folder — Cellar/<formula>/<version>/
//  — that every upgrade replaces, and keeps two names that survive it:
//  bin/<tool>, a symlink, and opt/<formula>, a symlink to the current
//  version. For a tool that keeps resource bundles beside its binary,
//  bin/<tool> is a bash script that execs the versioned path.
//
//  A job names opt/<formula>/…/<tool>: it survives an upgrade like bin/
//  does, and it is the binary itself, not a shell script in front of it.
//  Measured: either way, the process launchd runs — and the one macOS's
//  privacy checks charge — is the versioned Cellar binary, because the
//  kernel resolves the symlink and the script execs it. No path a job names
//  keeps a Full Disk Access grant across an upgrade; see the CLI's
//  schedule-runner for what does.
//

import Foundation

/// Upgrade-stable paths for Homebrew programs.
public enum HomebrewPaths {

    /// The path to record for a program: its `opt/<formula>/…` form when it
    /// is a Homebrew program, the path as given otherwise.
    ///
    /// Follows a `bin/` symlink into the Cellar, and a Homebrew exec script
    /// (`exec "…/Cellar/<formula>/<version>/libexec/<tool>" "$@"`) to what it
    /// runs, then names that through `opt/<formula>`. Anything that does not
    /// lead to an executable under an `opt/` link that exists is left alone.
    ///
    /// - Parameter path: An absolute path to an executable.
    /// - Returns: The stable path, or `path` itself.
    public static func stable(_ path: String) -> String {
        let real = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        let target = execTarget(of: real) ?? real
        guard let match = target.firstMatch(of: /^(.+)\/Cellar\/([^\/]+)\/[^\/]+\/(.+)$/) else { return path }
        let (prefix, formula, rest) = (String(match.1), String(match.2), String(match.3))
        let link = "\(prefix)/opt/\(formula)"
        let stable = "\(link)/\(rest)"
        // The opt link must be there and lead to this very file.
        guard (try? FileManager.default.destinationOfSymbolicLink(atPath: link)) != nil,
              FileManager.default.isExecutableFile(atPath: stable),
              URL(fileURLWithPath: stable).resolvingSymlinksInPath().path == URL(fileURLWithPath: target).resolvingSymlinksInPath().path
        else { return path }
        return stable
    }

    /// What a Homebrew exec script runs: the quoted path after `exec` in a
    /// short `#!/bin/bash` file, as `write_exec_script` writes it.
    static func execTarget(of path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        // A binary is not read past its first bytes; a script is a few lines.
        guard let head = try? handle.read(upToCount: 1024),
              let text = String(data: head, encoding: .utf8), text.hasPrefix("#!/bin/bash") else { return nil }
        guard let match = text.firstMatch(of: /\nexec "([^"]+)" "\$@"/) else { return nil }
        let target = String(match.1)
        return FileManager.default.isExecutableFile(atPath: target) ? target : nil
    }
}
