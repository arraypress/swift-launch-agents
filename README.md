# swift-launch-agents

Schedule jobs on a Mac the way the Mac does it — **launchd**, not cron — from
Swift, headless. Add a job in words ("07:00 on weekdays", "every 15 minutes",
"at login"), and get back what launchd actually holds; list, run, stop, read
the log and remove it, with every change checked against launchd afterwards.

```swift
import LaunchAgents

let scheduler = Scheduler()   // ~/Library/LaunchAgents, your GUI domain
let job = try scheduler.add(JobSpec(
    name: "backup",
    arguments: ["rsync", "-a", "/Users/me/Notes", "/Volumes/Backup/Notes"],
    trigger: .calendar(try ScheduleParser.slots(times: ["02:00"], days: try ScheduleParser.weekdays("weekdays")))))
job.status?.state     // "not running" — loaded, waiting for 02:00
job.nextRun           // the next weekday at 02:00
job.environment       // what its plist sets, PATH included — how a caller reads back its own keys
try scheduler.logs(of: "backup")
try scheduler.remove("backup")
```

## What it guarantees

- **Only its own jobs.** Every job made here is labelled `local.schedule.<name>`
  ("local." is the convention for jobs a person made on their own machine, and
  names no company). `list` shows only those unless asked for all, and `remove`
  refuses anything else without `force` — a Mac's LaunchAgents folder holds
  updaters and sync clients nobody chose to touch.
- **Checked, not assumed.** After `add`, `launchctl print` must show the job
  loaded from the plist just written, or the plist is deleted and the call
  fails; after `remove`, launchd must no longer have it and the plist must be
  gone. A plist written but never loaded is the classic silent failure of a
  cron replacement.
- **The PATH a job actually gets.** launchd's own PATH is
  `/usr/bin:/bin:/usr/sbin:/sbin`, so a job that calls a Homebrew tool works
  when tried by hand and fails at 07:00 with "command not found". Jobs get
  `/opt/homebrew/bin:/usr/local/bin` first unless they set PATH themselves, and
  the program is resolved to an absolute path when added — refused then, not at
  run time, when it does not exist. A Homebrew program is recorded by its
  `opt/` path (`/opt/homebrew/opt/<formula>/libexec/<tool>`), which survives
  an upgrade and is the binary itself, not `bin/`'s exec script
  (`HomebrewPaths.stable`; `Scheduler.resolve` is public for commands a caller
  runs itself). Measured: whichever path a job names, macOS's privacy checks
  see the versioned Cellar binary — the kernel resolves the link and the
  script execs — so no path keeps a Full Disk Access grant across an upgrade.
- **Folders, file by file.** `Trigger.watch([paths])` is launchd's `WatchPaths`: the
  job runs when a file arrives in, leaves or is renamed in a folder — but launchd
  never says which. `NewFiles.pending(_:seen:)` picks the files still to handle:
  not hidden, not an unfinished download (`.crdownload`, `.part`, `.download`…),
  not changed in the last 2 s, and not already handled (name + size + date, so a
  newer copy counts again). Measured live: an existing file skipped, each new file
  handled once, a `.crdownload` left until it was renamed to the finished name.
- **Somewhere to look.** Output and errors go to `~/Library/Logs/schedule/<name>.log`
  unless given elsewhere; `logs(of:)` reads the tail.

## Measured

- `launchctl bootstrap gui/<uid>` loads a plist from any folder and needs no
  privileges; `print` reports `runs = 1` and `last exit code = 0` after a
  `kickstart`; after `bootout`, `print` exits 113. Probed with a throwaway job
  running `/bin/sh -c date` before anything was written.
- **launchd resolves symlinks in the path it reports** — a plist written to
  `/var/folders/…` comes back as `/private/var/folders/…`. The first version of
  the post-add check compared them raw and called a good load a failure; a test
  caught it.
- `launchctl print`'s format is for people and Apple calls it unstable, so only
  five top-level keys are read (state, pid, runs, last exit code, path), each
  optional, and a nested `state = active` inside `event triggers` is ignored.
- The test suite adds, runs, reads, lists and removes real jobs in this Mac's
  launchd — from a scratch folder, under throwaway names, running only
  `/bin/sh` — and leaves none loaded. The person's own LaunchAgents folder is
  never touched by the tests.

Missed calendar runs while the Mac sleeps are run once on waking (launchd
coalesces them); an interval job counts from when it was loaded. Agents only —
system daemons need root and are out of scope.

## Layout

`Core/` Scheduler, Launchctl · `Support/` ScheduleParser, PlistBuilder,
PrintParser, Labels · `Models/` JobSpec, Job, JobStatus, CalendarSlot ·
`Enums/` Trigger · `Errors/` LaunchAgentError.

## Requirements

macOS 14, Swift 6.2.

## License

MIT — see [LICENSE](LICENSE).
