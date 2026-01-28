# eRezept Diagnostic Script for Windows Server 2008 R2 / PowerShell 2.0
# Run this FIRST to verify your environment before running run-test.ps1

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " eRezept Environment Diagnostic" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. PowerShell Version
Write-Host "[1] PowerShell Version:" -ForegroundColor Yellow
$PSVersionTable.PSVersion | Format-Table -AutoSize
Write-Host ""

# 2. Script Location
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "[2] Script Location: $scriptRoot" -ForegroundColor Yellow
Write-Host ""

# 3. Check for required folders
Write-Host "[3] Folder Structure:" -ForegroundColor Yellow
$folders = @("config", "scripts", "tools", "local-inbox", "local-data", "logs")
foreach ($f in $folders) {
    $path = Join-Path $scriptRoot $f
    if (Test-Path $path) {
        Write-Host "  [OK] $f" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $f" -ForegroundColor Red
    }
}
Write-Host ""

# 4. Check for required scripts
Write-Host "[4] Script Files:" -ForegroundColor Yellow
$scripts = @(
    "config\settings.ps1",
    "scripts\logger.ps1",
    "scripts\csv-lookup.ps1",
    "scripts\pdf-ocr.ps1",
    "scripts\email-sender.ps1"
)
foreach ($s in $scripts) {
    $path = Join-Path $scriptRoot $s
    if (Test-Path $path) {
        Write-Host "  [OK] $s" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $s" -ForegroundColor Red
    }
}
Write-Host ""

# 5. Encoding Check
Write-Host "[5] Encoding Check (UTF-8 mojibake detection):" -ForegroundColor Yellow
$encodingOk = $true
foreach ($s in $scripts) {
    $path = Join-Path $scriptRoot $s
    if (Test-Path $path) {
        try {
            $content = [System.IO.File]::ReadAllText($path)
            if ($content -match "(FÃ¼r|Ã¼|Ã¤|Ã¶)") {
                Write-Host "  [ENCODING ERROR] $s - UTF-8 mis-decoded!" -ForegroundColor Red
                $encodingOk = $false
            } else {
                Write-Host "  [OK] $s" -ForegroundColor Green
            }
        } catch {
            Write-Host "  [ERROR] $s - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
if (-not $encodingOk) {
    Write-Host ""
    Write-Host "  HINWEIS: Encoding-Fehler bedeuten, dass die Dateien beim Kopieren" -ForegroundColor Yellow
    Write-Host "  beschaedigt wurden. Nutze 7-Zip oder kopiere per USB ohne ZIP." -ForegroundColor Yellow
}
Write-Host ""

# 6. Tool Detection
Write-Host "[6] OCR Tools:" -ForegroundColor Yellow

# Ghostscript
$gsFound = $false
$gsPaths = @(
    (Join-Path $scriptRoot "tools\ghostscript\bin\gswin64c.exe"),
    (Join-Path $scriptRoot "tools\ghostscript\bin\gswin32c.exe"),
    (Join-Path $scriptRoot "tools\gswin64c.exe"),
    (Join-Path $scriptRoot "tools\gswin32c.exe"),
    "C:\Program Files\gs\gs*\bin\gswin64c.exe",
    "C:\Program Files\gs\gs*\bin\gswin32c.exe",
    "C:\Program Files (x86)\gs\gs*\bin\gswin32c.exe"
)
foreach ($p in $gsPaths) {
    $resolved = Get-ChildItem -Path $p -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($resolved) {
        Write-Host "  [OK] Ghostscript: $($resolved.FullName)" -ForegroundColor Green
        $gsFound = $true
        break
    }
}
if (-not $gsFound) {
    Write-Host "  [MISSING] Ghostscript (gswin64c.exe / gswin32c.exe)" -ForegroundColor Red
    Write-Host "    Download: https://ghostscript.com/releases/gsdnld.html" -ForegroundColor Gray
}

# Tesseract
$tessFound = $false
$tessPaths = @(
    (Join-Path $scriptRoot "tools\tesseract\tesseract.exe"),
    (Join-Path $scriptRoot "tools\tesseract.exe"),
    "C:\Program Files\Tesseract-OCR\tesseract.exe",
    "C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"
)
foreach ($p in $tessPaths) {
    if (Test-Path $p) {
        Write-Host "  [OK] Tesseract: $p" -ForegroundColor Green
        $tessFound = $true
        break
    }
}
if (-not $tessFound) {
    Write-Host "  [MISSING] Tesseract (tesseract.exe)" -ForegroundColor Red
    Write-Host "    Download: https://github.com/UB-Mannheim/tesseract/wiki" -ForegroundColor Gray
}
Write-Host ""

# 7. CSV Data Files
Write-Host "[7] Data Files (local-data):" -ForegroundColor Yellow
$dataFiles = @(
    "local-data\patient_apo_mapping.csv",
    "local-data\KIM_apo_mapping.csv"
)
foreach ($d in $dataFiles) {
    $path = Join-Path $scriptRoot $d
    if (Test-Path $path) {
        $size = (Get-Item $path).Length
        Write-Host "  [OK] $d ($size bytes)" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $d" -ForegroundColor Yellow
        Write-Host "    Kopiere die CSV-Dateien in den local-data Ordner." -ForegroundColor Gray
    }
}
Write-Host ""

# 8. Quick PS2 Compatibility Test
Write-Host "[8] PowerShell 2.0 Compatibility Test:" -ForegroundColor Yellow
try {
    # Test hashtable
    $h = @{ "key" = "value" }
    Write-Host "  [OK] Hashtable creation" -ForegroundColor Green
    
    # Test array
    $a = @("a", "b", "c")
    Write-Host "  [OK] Array creation" -ForegroundColor Green
    
    # Test .NET SHA256
    $sha = New-Object System.Security.Cryptography.SHA256Managed
    Write-Host "  [OK] SHA256Managed available" -ForegroundColor Green
    
    # Test regex with Unicode escape
    $testStr = "Test mit Fuer"
    if ($testStr -match "F\u00FCr|Fuer") {
        Write-Host "  [OK] Unicode regex escape" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Unicode regex may not work as expected" -ForegroundColor Yellow
    }
    
    # Test file read
    $bytes = [System.IO.File]::ReadAllBytes($MyInvocation.MyCommand.Definition)
    Write-Host "  [OK] System.IO.File access" -ForegroundColor Green
    
} catch {
    Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# 9. Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$ready = $true
if (-not $gsFound) { 
    Write-Host "- Ghostscript fehlt" -ForegroundColor Red
    $ready = $false
}
if (-not $tessFound) { 
    Write-Host "- Tesseract fehlt" -ForegroundColor Red
    $ready = $false
}
if (-not $encodingOk) { 
    Write-Host "- Encoding-Probleme in Skript-Dateien" -ForegroundColor Red
    $ready = $false
}

if ($ready) {
    Write-Host "System ist bereit fuer run-test.ps1" -ForegroundColor Green
} else {
    Write-Host "Bitte behebe die oben genannten Probleme." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Druecke eine Taste zum Beenden..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
