# TASKS

## Active Work (Windows Server 2008 R2 test package)

- [ ] **(Today)** Stabilize Windows entrypoint:
  - [ ] Confirm `run-test.cmd` launches PowerShell reliably.
  - [ ] Document a *known-good* direct command runner.
  - [ ] Add rollback instructions if the launcher behaves strangely.

- [ ] **(Today)** Add PS2-safe encoding preflight:
  - [ ] Detect mis-decoded source (e.g. `FÃ¼r`) early and abort with clear guidance.

## Completed

- [x] Fix Ghostscript output argument: use `-sOutputFile=...` (instead of `-o`).
- [x] Fix Ghostscript rotation procedure to avoid `/typecheck`:
  - Use `<</Install {90 rotate}>> setpagedevice`.
- [x] Harden hash handling so empty/invalid paths don’t produce confusing failures.

## Known-Good Runner Commands (Windows)

### Run from `cmd.exe`
From inside `F:\eRezept-Automatisierung\windows-test-package`:

```
%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\run-test.ps1"
```

### Verify launcher file content
```
type run-test.cmd
```

## Discovered During Work

- Launcher behavior may differ depending on:
  - how the folder was copied (zip/unzip, SMB, USB tools)
  - whether the `.cmd` was edited by a tool that changes encoding/line endings
  - whether PowerShell is in PATH on that machine
