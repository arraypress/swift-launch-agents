//
//  NewFiles.swift
//  LaunchAgents
//
//  Created by David Sherlock on 2026.
//
//  Which files in a watched folder still need handling. launchd's
//  WatchPaths fires when a folder changes but never says which file, and
//  fires again for every later change — so a job that simply "processes the
//  folder" would redo everything each time. These rules pick the files not
//  yet handled, and leave out the ones that are not finished arriving: a
//  browser's .crdownload, a hidden temp file, a copy still growing. Such a
//  file changes again when it completes, which fires the job once more.
//

import Foundation

public enum NewFiles {

    /// Names a download or a copy uses while it is unfinished.
    public static let partialExtensions: Set<String> = ["download", "crdownload", "part", "partial", "tmp", "temp", "opdownload"]

    /// A file changed this recently may still be being written.
    public static let settleSeconds: TimeInterval = 2

    /// The files of `listing` to handle now, oldest first: not hidden, not
    /// partial, not changed in the last ``settleSeconds``, and not in `seen`.
    public static func pending(_ listing: [FileStamp], seen: Set<String>, now: Date = Date()) -> [FileStamp] {
        listing.filter { file in
            !file.name.hasPrefix(".")
                && !partialExtensions.contains((file.name as NSString).pathExtension.lowercased())
                && now.timeIntervalSince(file.modified) >= settleSeconds
                && !seen.contains(file.identity)
        }
        .sorted { ($0.modified, $0.name) < ($1.modified, $1.name) }
    }

    /// The regular files directly inside `folder` (not its subfolders).
    public static func listing(of folder: URL) throws -> [FileStamp] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        let items: [URL]
        do {
            items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)
        } catch {
            throw LaunchAgentError.invalid("cannot read \(folder.path): \(error.localizedDescription)")
        }
        return items.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { return nil }
            return FileStamp(name: url.lastPathComponent, size: Int64(values.fileSize ?? 0),
                             modified: values.contentModificationDate ?? .distantPast)
        }
    }
}
