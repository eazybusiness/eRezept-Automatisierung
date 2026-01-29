# TASKS

## Active Work (Windows 10 VM Testing)

- [ ] **(Next)** Final testing and pharmacy mapping confirmation:
  - [x] Set up Windows 10 VM with VirtualBox
  - [x] Install Ghostscript and Tesseract
  - [x] Install German language data (deu.traineddata)
  - [x] Fix PDF-to-image conversion (Tesseract can't read PDFs directly)
  - [x] Check OCR output in `temp/ocr_debug_*.txt` files
  - [x] Adjust regex patterns to match actual OCR output
  - [x] Fix patient name extraction (was extracting doctor name instead)
  - [ ] Test with all 5 patient PDFs
  - [ ] Confirm pharmacy mapping structure with client

## Completed (2026-01-29)

- [x] **Critical Bug Fix: Patient Name Extraction**:
  - Analyzed OCR debug output from Windows test runs
  - Identified root cause: regex was extracting doctor name (Tobias Frank) instead of patient name
  - Implemented section-based extraction: only search between "für geboren am" and "ausgestellt von"
  - Added safety filter to skip names containing "Frank", "Dr.", "med."
  - Created test package v2 with fixes
  - Documented changes in CHANGELOG.md and TESTING_NOTES.md

## Completed (2025-01-28)

- [x] **Windows 10 VM Setup**:
  - Set up VirtualBox VM with Windows 10 Enterprise Evaluation
  - Configured HTTP server for file transfer (bypassing VirtualBox sharing issues)
  - Installed Ghostscript 10.06.0 and Tesseract OCR
  - Installed German language data (deu.traineddata)
- [x] **PowerShell 5.1 Compatibility Fixes**:
  - Renamed `Get-FileHash` to `Get-PDFFileHash` (collision with built-in cmdlet)
  - Set `TESSDATA_PREFIX` environment variable automatically
  - Added check for German language data with helpful error messages
- [x] **PDF Processing Pipeline**:
  - Removed broken Ghostscript rotation (GS 10.x syntax incompatibility)
  - Implemented PDF-to-PNG conversion (300 DPI) before OCR
  - Tesseract now processes PNG images instead of PDFs directly
  - Added OCR debug output to `temp/ocr_debug_*.txt` files
- [x] Fix Ghostscript output argument: use `-sOutputFile=...` (instead of `-o`).
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
