# Memory: Lessons — Windows / Flutter / Dart environment playbook

**ID:** `mem-lessons-windows-flutter-environment`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-07

## Machine facts (owner PC)

- Flutter 3.47.6 / Dart 3.13.5 at **`D:\flutter`**. `D:\flutter\bin` is on the **user PATH (registry)**, but agent shells started before the PATH edit don't see it → prefix `$env:Path = "D:\flutter\bin;$env:Path"` (PowerShell) or `PATH=/d/flutter/bin:$PATH` (bash).
- Test PATH the way Task Scheduler sees it: build Path from `[Environment]::GetEnvironmentVariable('Path','Machine')` + `'User'` and run `where dart` in a fresh process (BUG-0002 rejected this way).
- `dart` / `flutter` on PATH are **`.bat` shims** (`D:\flutter\bin\dart.bat`). Anything that spawns without a shell (Claude Code `.mcp.json`, Node `spawn`) must use `"command": "cmd", "args": ["/c", "dart", ...]`. Real exe: `D:\flutter\bin\cache\dart-sdk\bin\dart.exe`.
- Not admin. Elevated registry/settings changes are refused by the agent's permission classifier → hand OS-level steps to the owner.

## Windows build prerequisites (both hit this session, in this order)

| Error | Fix (owner) |
|---|---|
| `Building with plugins requires symlink support` | Settings → System → For developers → **Developer Mode** on |
| `Unable to find suitable Visual Studio toolchain` | VS Build Tools 2022 → Modify → **Desktop development with C++** (`setup.exe modify --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended`) |

Then `flutter build windows --release` (~25–40 s). Ship the **whole** `Release` folder (dll + `data\`), not just the exe.

## Running the local server

- `cd server; dart run bin/server.dart config.json` — first `dart run` after code changes compiles for 60–90 s; probes must wait that long.
- **Stale server trap:** an older server left running keeps port 8080 → new process dies with `errno = 10048`, and requests hit OLD code (`Route not found` for new routes). Check with `Get-CimInstance Win32_Process -Filter "Name='dartvm.exe' OR Name='dart.exe'"` (CommandLine shows `bin\server.dart`) and kill before restarting.
- In the agent's PowerShell tool, `Start-Process … -RedirectStandardOutput` + wait loops tend to hang until timeout; starting via bash `nohup … &` and polling with `curl -s -m 2` is reliable. PowerShell 5.1 `Invoke-WebRequest` to localhost sometimes fails where `curl` works.
- `sqlite3` Dart package (2.x) loads Windows' built-in `winsqlite3`; JSON1 (`json_extract`, `json_each`) available — no dll download needed on this PC.

## Runtime verification recipe (no human clicks)

- Screenshot script (scratchpad `shoot_styles.ps1` pattern): write `%APPDATA%\com.hung\analytic_app\shared_preferences.json` with `{"flutter.appStyle":"<style>"}` (back up/restore original), launch exe, `MoveWindow` to 1440×900, `SetProcessDPIAware`, wait ~6 s, `CopyFromScreen` window rect → PNG → Read the PNG to inspect.
- Navigate by synthetic click: `SetCursorPos` + `mouse_event(2/4)` at sidebar coordinates (window at 40,40: Funnels ≈ 133,321).
- Server-side evidence: server log lines (`logRequests`) prove the app fetched; curl the API with real ranges to cross-check numbers.

## Flutter / package API traps met

- Riverpod: pin **2.6.1** (v3 changes retry + APIs). Family keys must have value equality: records of Strings OK; a record holding a `List` never compares equal → endless refetch (use comma-joined String or a class with `==`).
- Desktop: `RefreshIndicator` pull-to-refresh does not work with a mouse → always provide a Refresh button (BUG-0001). Show a snackbar after refresh, else identical data looks like "nothing happened".
- fl_chart default line tooltip: grey bg + line-colour text → unreadable on some palettes; shows `1.0` for ints (BUG-0005/0006). Axis labels can collide with asserted KPI texts in widget tests → seed chart data with different numbers.
- `find.widgetWithText(TextButton, …)` misses `TextButton.icon` (private subclass) → match `ButtonStyleButton` ancestor.
- Bundled fonts: Google Fonts CSS API (`curl` without browser UA) returns **static TTF per weight** from fonts.gstatic.com — safer than variable fonts for Flutter weights.
- Flutter tests make real HTTP return 400 (mock HttpClient) → override every provider a page in an `IndexedStack` watches, or offstage pages show errors.
