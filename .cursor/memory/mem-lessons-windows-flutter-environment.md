# Memory: Lessons — Windows / Flutter / Dart environment playbook

**ID:** `mem-lessons-windows-flutter-environment`
**Parent:** `mem-project-index`
**Last updated:** 2026-10-14

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

- `cd server; dart run bin/server.dart config.json` — first `dart run` after code changes compiles for 60–90 s, **sometimes longer** (v5 wave 1 restart: a 90 s poll timed out, server answered right after). Poll longer, and give every probe `-TimeoutSec` — a plain `Invoke-RestMethod` against a not-yet-listening server can hang the tool call.
- PowerShell 5.1 `Set-Content -Encoding utf8` writes a **BOM** → noisy diffs in Dart files. Edit files with the Edit tool or Python (`newline=''` keeps CRLF/LF as found).
- `flutter build windows --release` succeeds while the old `analytic_app.exe` is running (it rewrote `data\app.so`); the running app keeps old code until restarted. A 5 s "Built" with unchanged timestamps = nothing to rebuild.
- **Stale server trap:** an older server left running keeps port 8080 → new process dies with `errno = 10048`, and requests hit OLD code (`Route not found` for new routes). Check with `Get-CimInstance Win32_Process -Filter "Name='dartvm.exe' OR Name='dart.exe'"` (CommandLine shows `bin\server.dart`) and kill before restarting.
- Historical tooling sometimes hung when process launch and wait loops shared one call. This session successfully used hidden Start-Process with explicit working directory/logs and separate bounded HTTP probes; use the current supported harness rather than assuming bash nohup survives Windows process cleanup.
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

## 2026-10-09 runtime and preview evidence

- New source routes do not hot-reload an existing Dart process. Owner's three-tab404 report was reproduced on the older server, resolved by a targeted restart, and confirmed by200 JSON responses from survival/version-impact/associations/anomalies. Record live endpoint evidence separately from source/analyzer success.
- In this session a hidden PowerShell Start-Process of the real Dart executable, with explicit server working directory/config and separate stdout/stderr logs, succeeded. Launch first and probe in later calls with timeouts; do not kill unrelated Dart/MCP processes or wrap the launch in a long blocking loop.
- Windows app was not rebuilt during the later UI planning; a future Gemini implementation must build/relaunch and inspect the actual current binary.
- Browser companion used the project's brainstorming script under Git Bash with --open --foreground and persistent `.superpowers/brainstorm/` files. Its URL token lives in local server-info; do not commit it in project memory. The server may expire after inactivity.
- Browser automation was unavailable in this session. Only preview HTTP delivery and JavaScript/template behavior were checked; no screenshot-based visual sign-off. Use currently supported UI tools in future sessions; older synthetic-click recipes are historical, not authority to bypass tool restrictions.

## SDK bootstrap and UTF-8 lessons - 2026-10-12

- In restricted Windows sessions, flutter.bat/dart.bat can spin silently before launching Dart. The SDK shared.bat bootstrap redirects lock errors and retries acquiring bin/cache/flutter.bat.lock; a denied cache write can look like a busy SDK. Inspect this review's process tree/command lines and pinned script rather than waiting indefinitely or assuming tests started.
- Stop only the identified processes launched by this review. Do not delete SDK lock/cache files, kill unrelated Dart/MCP sessions or request broader access before checking a safe fallback.
- On this installed SDK, the real Dart executable and prebuilt flutter_tools.snapshot successfully ran analyzers/tests without the batch bootstrap. Verify those installed paths exist and cached dependencies are ready; this is a review/test fallback, not an SDK upgrade or assurance about every build command.

```powershell
# cwd app; run separately and inspect each exit/output
& 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\flutter\bin\cache\flutter_tools.snapshot' analyze --no-pub
& 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\flutter\bin\cache\flutter_tools.snapshot' test --no-pub
# cwd shared, then server
& 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze
& 'D:\flutter\bin\cache\dart-sdk\bin\dart.exe' test
```

- A wrapped shell ending with success can hide an earlier analyzer/test failure. Record per-command results, not just the surrounding script exit. Full output that is truncated must still preserve final test summary/count/exit; capture and filter summaries if needed.
- Python on this Windows host defaults to cp1252 for stdout and text subprocess decoding. Unicode arrows and Flutter box-drawing output caused UnicodeEncodeError/UnicodeDecodeError even after the child test had run. Use `sys.stdout.reconfigure(encoding='utf-8')` for emitted text and `subprocess.run(..., text=True, encoding='utf-8', errors='replace')` for captured logs. A decode failure is not a behavioral test result; rerun/read the actual child output.
- Preserve existing Markdown encoding/newlines and use targeted updates after rereading shared files. Code-fence formatter checks may use declaration/statement wrappers; state that boundary explicitly. Remove only named temporary validation files, not an entire tool/test directory.
- These sessions performed automated widget/render-object probes only. No fresh Windows release build, screenshot/live walkthrough or server restart occurred; keep those evidence fields pending until actually observed.
- **WindowStation and Desktop isolation (`WinSta0\Default` vs `exebox-...`):**
  - Provenance: Gemini-recorded prior runner investigation, retained from separate runtime notes. The latest dashboard demo/review/repair session did not independently inspect desktop stations or perform native UI control; browser inventory was empty and native APIs unavailable.
  - Tool runner subprocesses spawned by the IDE language server/agent background daemon run inside an isolated virtual desktop (`exebox-6M2X6FETC7WN7A6IRJQEOWS4SL`), rather than the interactive user desktop (`WinSta0\Default`).
  - Child GUI processes spawned via standard `Start-Process` or `cmd /c` inherit this virtual desktop. Their Win32 HWND is created inside `exebox-...`, so the application runs and communicates with the localhost server while remaining completely invisible on the physical monitor (`MainWindowHandle` appears 0 to queries from other sessions, and GDI `CopyFromScreen` throws `Win32Exception: The handle is invalid`).
  - Gemini recorded a Win32 CreateProcess/lpDesktop workaround. Do not treat historical notes as current authorization or reuse old process IDs. Prefer owner launch from File Explorer/their terminal or available supported computer-use APIs; obey the current tool restrictions rather than building a custom UI helper.
- **Wrap layout expansion with `Center` (2026-10-14):**
  - In Flutter desktop, placing an unconstrained `Center` widget (e.g. `ConstrainedBox(constraints: BoxConstraints(minHeight: 44), child: Center(child: FilterChip(...)))`) inside a `Wrap` causes `Center` to expand to the full remaining row width (`maxWidth`). This forces subsequent widgets onto new rows, ballooning the toolbar height (e.g. from 88px to 208px), which in turn pushes downstream page widgets down and can cause off-screen tap failure (`Offset outside root Size`).
  - Gemini's recorded fix uses Align with widthFactor1 for the chip. Responsive Wrap still legitimately creates multiple rows when width/text scaling requires it; do not equate every extra row with a defect or force clipping to obtain one row.
- **Windows release build binary locking (2026-10-14):**
  - When `analytic_app.exe` is running, Windows locks the executable and `data/app.so` against being written.
  - Running `flutter build windows --release --no-pub` while the process is active will fail with an access denied / link error.
  - Inspect the exact current `analytic_app` PID/path before build. If owner's interactive work is open or build is locked, let the owner close that identified app; no blanket wildcard kill, unrelated Dart termination or reuse of historical PIDs. In the latest dashboard repair session no live app was terminated.
  - A successful build and fresh Dart payload metadata establish build evidence, not native visual acceptance. Latest recorded dashboard repair build:26.6seconds, app.so2026-10-14 13:49:37; keep all15 walkthroughs/six baseline checks pending until observed.
