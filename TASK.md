# TASKS

## Active Work (Windows Server 2008 R2 test package)

- [ ] **(Next)** Test on Windows 2008 R2:
  - [ ] Run `diagnose.cmd` first to verify environment.
  - [ ] If encoding errors: re-copy files using 7-Zip or direct USB (no Windows ZIP).
  - [ ] Install Ghostscript + Tesseract if missing.
  - [ ] Place CSV files in `local-data/` folder.
  - [ ] Place test PDFs in `local-inbox/` folder.
  - [ ] Run `run-test.cmd` and check `logs/` for output.

## Completed

- [x] Fix Ghostscript output argument: use `-sOutputFile=...` (instead of `-o`).
- [x] Fix Ghostscript rotation procedure to avoid `/typecheck`:
  - Use `<</Install {90 rotate}>> setpagedevice`.
- [x] Harden hash handling so empty/invalid paths don’t produce confusing failures.
- [x] **(2025-01-28)** Add PS2-safe encoding preflight in `run-test.ps1`:
  - Detects mis-decoded UTF-8 (e.g. `FÃ¼r`) and aborts with guidance.
- [x] **(2025-01-28)** Fix PS2 compatibility issues:
  - Replace `-contains` with explicit `-eq` checks in `logger.ps1`.
  - Replace `System.Collections.Generic.List[string]` with simple array in `csv-lookup.ps1`.
  - Fix `Get-LogStatistics` to use `ConvertFrom-JsonLineCompat` instead of `ConvertFrom-Json`.
- [x] **(2025-01-28)** Create `diagnose.ps1` / `diagnose.cmd`:
  - Standalone diagnostic script to verify environment before running main script.

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
