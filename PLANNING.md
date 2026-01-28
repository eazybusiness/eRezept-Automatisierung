# eRezept-Automatisierung

## Goal (current focus)
Create a **Windows Server 2008 R2 / PowerShell 2.0 compatible test package** that can be copied to a machine (USB/SMB), executed with minimal manual setup, and **never sends real data** during tests.

The main success criteria for the current phase:
- The Windows test runner starts reliably.
- PDFs are processed end-to-end:
  - rotate PDF (Ghostscript)
  - OCR (Tesseract)
  - extract patient name + birthdate
  - CSV lookup: patient -> pharmacy
  - CSV lookup: pharmacy -> KIM address
  - route/move files into the correct folders
  - log JSONL entries
  - duplicate detection via SHA-256
- **Dry-run is guaranteed** (`EnableSend = $false`) so no SMTP is used.

## Non-goals (for this phase)
- Production deployment on the customer environment.
- Running as a Windows service (NSSM) in this test phase.

## Constraints
- Must run on **PowerShell 2.0** (no `ConvertTo-Json`, no `Get-FileHash`, no `-in`, etc.).
- Must be safe for customer PDFs/CSVs: **never commit private data**.
- Prefer a USB-friendly structure with relative paths for the test package.

## Architecture (high level)

### Components
- `windows-test-package/run-test.cmd`: Windows launcher for the test runner.
- `windows-test-package/run-test.ps1`: Main loop and orchestration.
- `windows-test-package/config/settings.ps1`: Configuration (folders, tools, dry-run flag).
- `windows-test-package/scripts/`:
  - `pdf-ocr.ps1`: Ghostscript rotation + Tesseract OCR + regex extraction
  - `csv-lookup.ps1`: PS2-safe CSV parsing + lookup functions
  - `logger.ps1`: PS2-safe JSONL logging + SHA-256 hashing + duplicate detection
  - `email-sender.ps1`: contains sending logic but must honor `EnableSend = $false` in tests

### Data flow (test package)
```
local-inbox/ (drop PDFs) -> run-test.ps1 -> rotate+OCR -> extract patient -> CSV lookups
-> route into pharmacies/<APO_KEY>/ or unklar/ -> (dry-run) move to sent/ -> logs/
```

## Safety: no data must be sent
- `EnableSend` must remain `false` in all test runs.
- Default `SmtpServer` must remain a non-production value (e.g. `testserver`).
- If you want an extra safety barrier: disconnect the test machine from the network.

## Known issues / troubleshooting focus
- If the Windows launcher behaves oddly (e.g. only prints a single character like `K`):
  - verify you are running the correct file (`type run-test.cmd`)
  - avoid executing `.ps1` from `cmd.exe` directly
  - prefer calling PowerShell explicitly (see `TASK.md` for the exact command)

## Repository hygiene
- Customer PDFs/CSVs must never be committed.
- Keep repo root clean: move legacy docs into `obsolete/`.
