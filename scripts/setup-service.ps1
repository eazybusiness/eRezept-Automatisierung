# Windows Service Setup für eRezept-Automatisierung
# NSSM-basierte Installation als Windows-Dienst

function Test-AdminPrivileges {
    <#
    .SYNOPSIS
        Prüft ob das Skript mit Administratorrechten läuft
    #>
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Install-NSSM {
    <#
    .SYNOPSIS
        Lädt und installiert NSSM (Non-Sucking Service Manager)
    #>
    try {
        Write-Host "Installiere NSSM..." -ForegroundColor Yellow
        
        # NSSM Download URL
        $nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
        $nssmZip = Join-Path $env:TEMP "nssm.zip"
        $nssmFolder = Join-Path $Config.ToolsFolder "nssm"
        
        # Download
        Write-Host "Lade NSSM herunter..." -ForegroundColor Gray
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($nssmUrl, $nssmZip)
        $webClient.Dispose()
        
        # Entpacken
        Write-Host "Entpacke NSSM..." -ForegroundColor Gray
        Expand-Archive -Path $nssmZip -DestinationPath $nssmFolder -Force
        
        # 64-bit Version kopieren
        $nssmExe = Join-Path $nssmFolder "nssm-2.24\win64\nssm.exe"
        $targetPath = Join-Path $Config.ToolsFolder "nssm.exe"
        
        if (Test-Path $nssmExe) {
            Copy-Item $nssmExe $targetPath -Force
            Write-Host "NSSM installiert: $targetPath" -ForegroundColor Green
            return $targetPath
        } else {
            Write-Host "NSSM.exe nicht gefunden!" -ForegroundColor Red
            return $null
        }
    }
    catch {
        Write-Host "Fehler bei NSSM Installation: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
    finally {
        # Aufräumen
        if (Test-Path $nssmZip) {
            Remove-Item $nssmZip -Force
        }
        if (Test-Path $nssmFolder) {
            Remove-Item $nssmFolder -Recurse -Force
        }
    }
}

function Install-Service {
    <#
    .SYNOPSIS
        Installiert den eRezept-Automatisierungsdienst
    #>
    try {
        Write-Host "Installiere eRezept-Automatisierungsdienst..." -ForegroundColor Yellow
        
        # NSSM prüfen/installieren
        $nssmPath = Join-Path $Config.ToolsFolder "nssm.exe"
        if (-not (Test-Path $nssmPath)) {
            $nssmPath = Install-NSSM
            if (-not $nssmPath) {
                throw "NSSM konnte nicht installiert werden"
            }
        }
        
        # Dienstname und Beschreibung
        $serviceName = "eRezeptAutomatisierung"
        $serviceDisplayName = "eRezept-Versand Automatisierung"
        $serviceDescription = "Automatischer Versand von eRezept-PDFs an Apotheken über KIM-Dienst"
        
        # PowerShell Pfad ermitteln
        $powershellPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $scriptPath = "$PSScriptRoot\eRezept-Automatisierung.ps1"
        
        # Dienst installieren
        Write-Host "Registriere Dienst..." -ForegroundColor Gray
        $installArgs = @(
            "install", $serviceName,
            $powershellPath,
            "-ExecutionPolicy", "Bypass",
            "-NonInteractive",
            "-NoProfile",
            "-File", "`"$scriptPath`""
        )
        
        & $nssmPath $installArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Dienst erfolgreich registriert" -ForegroundColor Green
            
            # Konfiguration setzen
            & $nssmPath set $serviceName DisplayName $serviceDisplayName
            & $nssmPath set $serviceName Description $serviceDescription
            & $nssmPath set $serviceName Start SERVICE_AUTO_START
            & $nssmPath set $serviceName AppRotateFiles 1
            & $nssmPath set $serviceName AppRotateOnline 1
            & $nssmPath set $serviceName AppRotateBytes 1048576
            
            # Recovery-Einstellungen
            & $nssmPath set $serviceName AppRestartDelay 30000
            & $nssmPath set $serviceName AppThrottle 5000
            & $nssmPath set $serviceName AppExit Default Restart
            & $nssmPath set $serviceName AppRestartDelay 60000
            
            # Log-Verzeichnis für STDOUT/STDERR
            $logDir = Join-Path $Config.LogFolder "service"
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            
            & $nssmPath set $serviceName AppStdout (Join-Path $logDir "stdout.log")
            & $nssmPath set $serviceName AppStderr (Join-Path $logDir "stderr.log")
            & $nssmPath set $serviceName AppStdoutCreationDisposition 4  # APPEND
            & $nssmPath set $serviceName AppStderrCreationDisposition 4  # APPEND
            
            Write-Host "Dienstkonfiguration abgeschlossen" -ForegroundColor Green
            return $true
        } else {
            throw "Dienstregistrierung fehlgeschlagen (Exit-Code: $LASTEXITCODE)"
        }
    }
    catch {
        Write-Host "Fehler bei Dienstinstallation: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Start-Service {
    <#
    .SYNOPSIS
        Startet den eRezept-Automatisierungsdienst
    #>
    try {
        $serviceName = "eRezeptAutomatisierung"
        
        Write-Host "Starte Dienst: $serviceName" -ForegroundColor Yellow
        
        # Prüfen ob Dienst existiert
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if (-not $service) {
            Write-Host "Dienst nicht gefunden. Bitte zuerst installieren." -ForegroundColor Red
            return $false
        }
        
        # Dienst starten
        Start-Service -Name $serviceName -ErrorAction Stop
        
        # Status prüfen
        $service.Refresh()
        if ($service.Status -eq "Running") {
            Write-Host "Dienst erfolgreich gestartet" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Dienst konnte nicht gestartet werden. Status: $($service.Status)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "Fehler beim Starten des Dienstes: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Stop-Service {
    <#
    .SYNOPSIS
        Stoppt den eRezept-Automatisierungsdienst
    #>
    try {
        $serviceName = "eRezeptAutomatisierung"
        
        Write-Host "Stoppe Dienst: $serviceName" -ForegroundColor Yellow
        
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq "Running") {
            Stop-Service -Name $serviceName -Force -ErrorAction Stop
            Write-Host "Dienst gestoppt" -ForegroundColor Green
        } else {
            Write-Host "Dienst läuft nicht" -ForegroundColor Yellow
        }
        
        return $true
    }
    catch {
        Write-Host "Fehler beim Stoppen des Dienstes: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Uninstall-Service {
    <#
    .SYNOPSIS
        Deinstalliert den eRezept-Automatisierungsdienst
    #>
    try {
        $serviceName = "eRezeptAutomatisierung"
        $nssmPath = Join-Path $Config.ToolsFolder "nssm.exe"
        
        Write-Host "Deinstalliere Dienst: $serviceName" -ForegroundColor Yellow
        
        # Dienst stoppen
        Stop-Service | Out-Null
        
        # Dienst entfernen
        if (Test-Path $nssmPath) {
            & $nssmPath remove $serviceName confirm
            Write-Host "Dienst deinstalliert" -ForegroundColor Green
        } else {
            Write-Host "NSSM nicht gefunden. Dienst kann nicht entfernt werden." -ForegroundColor Red
            return $false
        }
        
        return $true
    }
    catch {
        Write-Host "Fehler bei Deinstallation: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Get-ServiceStatus {
    <#
    .SYNOPSIS
        Zeigt den Status des eRezept-Automatisierungsdienstes
    #>
    try {
        $serviceName = "eRezeptAutomatisierung"
        
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        
        if ($service) {
            Write-Host "Dienst: $($service.DisplayName)" -ForegroundColor Cyan
            Write-Host "Status: $($service.Status)" -ForegroundColor $(if ($service.Status -eq "Running") { "Green" } else { "Yellow" })
            Write-Host "Starttyp: $($service.StartType)" -ForegroundColor Gray
            
            if ($service.Status -eq "Running") {
                Write-Host "Laufzeit: $($service | Select-Object @{Name='Uptime';Expression={(Get-Date) - $_.StartTime}} | Select-Object -ExpandProperty Uptime)" -ForegroundColor Gray
            }
            
            # Letzte Logs anzeigen
            $logFile = Join-Path $Config.LogFolder "erezept_$(Get-Date -Format 'yyyy-MM-dd').jsonl"
            if (Test-Path $logFile) {
                Write-Host "`nLetzte Log-Einträge:" -ForegroundColor Gray
                Get-Content $logFile -Tail 5 | ForEach-Object {
                    $entry = $_ | ConvertFrom-Json
                    $color = switch ($entry.status) {
                        "ERROR" { "Red" }
                        "WARN" { "Yellow" }
                        default { "Gray" }
                    }
                    Write-Host "[$($entry.timestamp)] $($entry.status): $($entry.message)" -ForegroundColor $color
                }
            }
        } else {
            Write-Host "Dienst nicht installiert" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Fehler bei Statusabfrage: $($_.Exception.Message)" -ForegroundColor Red
    }
}
