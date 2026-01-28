param(
    [int]$ScanIntervalSeconds = 5
)

$ErrorActionPreference = "Stop"

# PowerShell 2 compatible script root resolution
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptRoot

. .\config\settings.ps1

# Load modules (dot-source)
. .\scripts\logger.ps1
. .\scripts\csv-lookup.ps1
. .\scripts\pdf-ocr.ps1
. .\scripts\email-sender.ps1

function Assert-ToolExists {
    param(
        [string]$Path,
        [string]$ToolName
    )

    if (-not $Path -or -not (Test-Path $Path)) {
        Write-Host "[ERROR] Fehlt: $ToolName ($Path)" -ForegroundColor Red
        return $false
    }

    return $true
}

function Preflight-Checks {
    $ok = $true

    $ok = $ok -and (Assert-ToolExists -Path $Config.GhostscriptExe -ToolName "Ghostscript (gswin64c.exe)")
    $ok = $ok -and (Assert-ToolExists -Path $Config.TesseractExe -ToolName "Tesseract (tesseract.exe)")

    if (-not $ok) {
        Write-Host "" -ForegroundColor Red
        Write-Host "Bitte stelle sicher, dass die Tools unter 'tools\\' im Testpaket liegen (oder passe config\\settings.ps1 an)." -ForegroundColor Yellow
        return $false
    }

    return $true
}

function Initialize-TestDirectories {
    param([hashtable]$Config)

    $folders = @(
        $Config.InputFolder,
        $Config.PharmacyBaseFolder,
        $Config.UnklarFolder,
        $Config.SentFolder,
        $Config.LogFolder,
        $Config.TempFolder,
        $Config.ToolsFolder,
        (Split-Path -Parent $Config.PatientApoMapping),
        (Split-Path -Parent $Config.KIMApoMapping),
        $ErrorConfig.DeadLetterFolder
    )

    foreach ($folder in $folders) {
        if (-not $folder) { continue }
        if (-not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        }
    }
}

function Move-ToPharmacyFolder {
    param(
        [string]$PDFPath,
        [string]$ApoKey
    )

    $targetFolder = Join-Path $Config.PharmacyBaseFolder $ApoKey
    if (-not (Test-Path $targetFolder)) {
        New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
    }

    $targetPath = Join-Path $targetFolder (Split-Path $PDFPath -Leaf)
    Move-Item -Path $PDFPath -Destination $targetPath -Force

    return $targetPath
}

function Move-ToUnklarFolder {
    param([string]$PDFPath)

    $targetPath = Join-Path $Config.UnklarFolder (Split-Path $PDFPath -Leaf)
    Move-Item -Path $PDFPath -Destination $targetPath -Force

    return $targetPath
}

function Process-InboxOnce {
    $pattern = if ($ProcessingConfig.FilePattern) { $ProcessingConfig.FilePattern } else { "*.pdf" }
    $pdfFiles = Get-ChildItem -Path $Config.InputFolder -Filter $pattern -ErrorAction SilentlyContinue

    foreach ($pdf in $pdfFiles) {
        try {
            Write-Log "Verarbeite Datei: $($pdf.FullName)" -Status "INFO"

            $fileHash = Get-FileHash -FilePath $pdf.FullName
            if (-not $fileHash) {
                Write-Log "Hash-Berechnung fehlgeschlagen: $($pdf.FullName)" -Status $LogConfig.Status_ERROR
                continue
            }

            if (Test-DuplicateFile -FileHash $fileHash) {
                Write-Log "Duplikat erkannt, überspringe: $($pdf.Name)" -Status $LogConfig.Status_DUPLICATE -FileHash $fileHash
                continue
            }

            $patientInfo = Extract-PatientNameFromPDF -Path $pdf.FullName
            if (-not $patientInfo) {
                Write-Log "Keine Patientendaten gefunden: $($pdf.Name)" -Status $LogConfig.STATUS_UNKLAR -FileHash $fileHash
                $null = Move-ToUnklarFolder -PDFPath $pdf.FullName
                continue
            }

            $apoKey = Get-PharmacyForPatient -PatientName $patientInfo.Name -BirthDate $patientInfo.BirthDate
            if (-not $apoKey) {
                Write-Log "Keine Apotheke gefunden für: $($patientInfo.FullName)" -Status $LogConfig.STATUS_UNKLAR -Patient $patientInfo.Name -FileHash $fileHash
                $null = Move-ToUnklarFolder -PDFPath $pdf.FullName
                continue
            }

            $kimInfo = Get-EmailForPharmacy -ApoKey $apoKey
            if (-not $kimInfo) {
                Write-Log "Keine KIM-Adresse gefunden für Apotheke: $apoKey" -Status $LogConfig.STATUS_UNKLAR -Patient $patientInfo.Name -Pharmacy $apoKey -FileHash $fileHash
                $null = Move-ToUnklarFolder -PDFPath $pdf.FullName
                continue
            }

            $routedPath = Move-ToPharmacyFolder -PDFPath $pdf.FullName -ApoKey $apoKey
            Write-Log "PDF geroutet: $routedPath" -Status $LogConfig.Status_ROUTED -Patient $patientInfo.Name -Pharmacy $apoKey -FileHash $fileHash

            $sent = Send-PDFViaKIM -PDFPath $routedPath -ApoKey $apoKey -RecipientEmail $kimInfo.KIMAddress -PatientName $patientInfo.Name -FileHash $fileHash
            if ($sent) {
                Write-Log "Prozess abgeschlossen: $($pdf.Name)" -Status $LogConfig.Status_COMPLETED -Patient $patientInfo.Name -Pharmacy $apoKey -FileHash $fileHash
            }
        }
        catch {
            Write-Log "Fehler bei Verarbeitung von $($pdf.FullName): $($_.Exception.Message)" -Status $LogConfig.Status_ERROR
            try {
                $null = Move-Item -Path $pdf.FullName -Destination $ErrorConfig.DeadLetterFolder -Force
            }
            catch {
                # ignore
            }
        }
    }
}

Write-Host "eRezept-Automatisierung - Windows Test Package" -ForegroundColor Green
Write-Host "Pfad: $scriptRoot" -ForegroundColor Gray
Write-Host "Testmodus: EnableSend=$($KIMConfig.EnableSend)  SmtpServer=$($KIMConfig.SmtpServer)" -ForegroundColor Yellow
Write-Host "Lege Test-PDFs in: $($Config.InputFolder)" -ForegroundColor Cyan

Initialize-TestDirectories -Config $Config

if (-not (Preflight-Checks)) {
    exit 1
}

# Initialize caches (CSV)
$null = Initialize-CSVCache

while ($true) {
    Process-InboxOnce
    Start-Sleep -Seconds $ScanIntervalSeconds
}
