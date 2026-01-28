# Tools Setup Skript für eRezept-Automatisierung
# Lädt Tesseract und Ghostscript herunter und konfiguriert die Pfade

function Download-File {
    <#
    .SYNOPSIS
        Lädt eine Datei herunter mit Fortschrittsanzeige
    #>
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    try {
        $webClient = New-Object System.Net.WebClient
        Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
            $percent = $Event.SourceEventArgs.ProgressPercentage
            Write-Progress -Activity "Download" -Status "$percent% komplett" -PercentComplete $percent
        } | Out-Null
        
        $webClient.DownloadFile($Url, $OutputPath)
        $webClient.Dispose()
        Write-Progress -Activity "Download" -Completed
        
        return $true
    }
    catch {
        Write-Log "Fehler beim Download von $Url`: $($_.Exception.Message)" -Status "ERROR"
        return $false
    }
}

function Install-Tesseract {
    <#
    .SYNOPSIS
        Lädt Tesseract OCR herunter und installiert es
    #>
    try {
        Write-Log "Installiere Tesseract OCR..." -Status "INFO"
        
        # Tesseract Download URL (Windows 64-bit)
        $tesseractUrl = "https://github.com/UB-Mannheim/tesseract/wiki/download/tesseract-ocr-w64-setup-5.3.3.20231005.exe"
        $tesseractInstaller = Join-Path $env:TEMP "tesseract-installer.exe"
        
        # Download
        if (-not (Download-File -Url $tesseractUrl -OutputPath $tesseractInstaller)) {
            return $false
        }
        
        # Stiller Install in tools Ordner
        $installArgs = @(
            "/S",
            "/D=$($Config.ToolsFolder)\tesseract"
        )
        
        Write-Log "Führe Tesseract Installation durch..." -Status "INFO"
        $process = Start-Process -FilePath $tesseractInstaller -ArgumentList $installArgs -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            # Deutsches Sprachpaket herunterladen
            Write-Log "Lade deutsches Sprachpaket herunter..." -Status "INFO"
            $tessdataUrl = "https://github.com/tesseract-ocr/tessdata/raw/main/deu.traineddata"
            $tessdataPath = Join-Path $Config.ToolsFolder "tesseract\tessdata\deu.traineddata"
            
            if (Download-File -Url $tessdataUrl -OutputPath $tessdataPath) {
                Write-Log "Tesseract mit deutschem Sprachpaket installiert" -Status "INFO"
                
                # Konfiguration anpassen
                $Config.TesseractExe = Join-Path $Config.ToolsFolder "tesseract\tesseract.exe"
                $Config.TesseractData = Join-Path $Config.ToolsFolder "tesseract\tessdata"
                
                return $true
            }
        }
        
        Write-Log "Tesseract Installation fehlgeschlagen" -Status "ERROR"
        return $false
    }
    catch {
        Write-Log "Fehler bei Tesseract Installation: $($_.Exception.Message)" -Status "ERROR"
        return $false
    }
    finally {
        # Installer aufräumen
        if (Test-Path $tesseractInstaller) {
            Remove-Item $tesseractInstaller -Force
        }
    }
}

function Install-Ghostscript {
    <#
    .SYNOPSIS
        Lädt Ghostscript herunter und installiert es
    #>
    try {
        Write-Log "Installiere Ghostscript..." -Status "INFO"
        
        # Ghostscript Download URL (Windows 64-bit)
        $ghostscriptUrl = "https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10030/gs10030w64.exe"
        $ghostscriptInstaller = Join-Path $env:TEMP "ghostscript-installer.exe"
        
        # Download
        if (-not (Download-File -Url $ghostscriptUrl -OutputPath $ghostscriptInstaller)) {
            return $false
        }
        
        # Stiller Install
        $installArgs = @(
            "/S",
            "/D=$($Config.ToolsFolder)\ghostscript"
        )
        
        Write-Log "Führe Ghostscript Installation durch..." -Status "INFO"
        $process = Start-Process -FilePath $ghostscriptInstaller -ArgumentList $installArgs -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Log "Ghostscript installiert" -Status "INFO"
            
            # Konfiguration anpassen
            $Config.GhostscriptExe = Join-Path $Config.ToolsFolder "ghostscript\bin\gswin64c.exe"
            
            return $true
        }
        
        Write-Log "Ghostscript Installation fehlgeschlagen" -Status "ERROR"
        return $false
    }
    catch {
        Write-Log "Fehler bei Ghostscript Installation: $($_.Exception.Message)" -Status "ERROR"
        return $false
    }
    finally {
        # Installer aufräumen
        if (Test-Path $ghostscriptInstaller) {
            Remove-Item $ghostscriptInstaller -Force
        }
    }
}

function Test-ToolsInstallation {
    <#
    .SYNOPSIS
        Testet ob alle Tools korrekt installiert sind
    #>
    try {
        Write-Log "Teste Tools Installation..." -Status "INFO"
        
        $allOK = $true
        
        # Tesseract testen
        if (Test-Path $Config.TesseractExe) {
            try {
                $process = Start-Process -FilePath $Config.TesseractExe -ArgumentList "--version" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\tess_version.txt"
                $version = Get-Content "$env:TEMP\tess_version.txt" -Raw
                Write-Log "Tesseract Version: $version" -Status "INFO"
            }
            catch {
                Write-Log "Tesseract Test fehlgeschlagen: $($_.Exception.Message)" -Status "ERROR"
                $allOK = $false
            }
        } else {
            Write-Log "Tesseract nicht gefunden: $($Config.TesseractExe)" -Status "ERROR"
            $allOK = $false
        }
        
        # Ghostscript testen
        if (Test-Path $Config.GhostscriptExe) {
            try {
                $process = Start-Process -FilePath $Config.GhostscriptExe -ArgumentList "--version" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\gs_version.txt"
                $version = Get-Content "$env:TEMP\gs_version.txt" -Raw
                Write-Log "Ghostscript Version: $version" -Status "INFO"
            }
            catch {
                Write-Log "Ghostscript Test fehlgeschlagen: $($_.Exception.Message)" -Status "ERROR"
                $allOK = $false
            }
        } else {
            Write-Log "Ghostscript nicht gefunden: $($Config.GhostscriptExe)" -Status "ERROR"
            $allOK = $false
        }
        
        # Sprachpaket testen
        $deuPath = Join-Path $Config.TesseractData "deu.traineddata"
        if (Test-Path $deuPath) {
            Write-Log "Deutsches Sprachpaket gefunden" -Status "INFO"
        } else {
            Write-Log "Deutsches Sprachpaket nicht gefunden: $deuPath" -Status "ERROR"
            $allOK = $false
        }
        
        if ($allOK) {
            Write-Log "Alle Tools erfolgreich installiert und getestet" -Status "INFO"
        } else {
            Write-Log "Tools Installation unvollständig" -Status "ERROR"
        }
        
        return $allOK
    }
    catch {
        Write-Log "Fehler bei Tools Test: $($_.Exception.Message)" -Status "ERROR"
        return $false
    }
}

function Install-AllTools {
    <#
    .SYNOPSIS
        Installiert alle erforderlichen Tools
    #>
    try {
        Write-Log "Starte Installation aller Tools..." -Status "INFO"
        
        # Tools Ordner erstellen
        if (-not (Test-Path $Config.ToolsFolder)) {
            New-Item -ItemType Directory -Path $Config.ToolsFolder -Force | Out-Null
        }
        
        # Tesseract installieren
        $tesseractOK = Install-Tesseract
        
        # Ghostscript installieren
        $ghostscriptOK = Install-Ghostscript
        
        # Installation testen
        if ($tesseractOK -and $ghostscriptOK) {
            return Test-ToolsInstallation
        } else {
            Write-Log "Installation der Tools fehlgeschlagen" -Status "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Fehler bei der Installation: $($_.Exception.Message)" -Status "ERROR"
        return $false
    }
}
