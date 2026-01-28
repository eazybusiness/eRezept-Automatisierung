# E-Mail Modul für eRezept-Automatisierung
# KIM-Dienst Integration mit SMTP

function Send-PDFViaKIM {
    <#
    .SYNOPSIS
        Sendet PDF per KIM-Dienst an Apotheke
    .PARAMETER PDFPath
        Pfad zur PDF-Datei
    .PARAMETER ApoKey
        APO_KEY der Apotheke
    .PARAMETER RecipientEmail
        KIM-E-Mail-Adresse der Apotheke
    .PARAMETER PatientName
        Name des Patienten
    .PARAMETER FileHash
        SHA-256 Hash der Datei
    .RETURNS
        $true bei Erfolg, $false bei Fehler
    #>
    param(
        [string]$PDFPath,
        [string]$ApoKey,
        [string]$RecipientEmail,
        [string]$PatientName,
        [string]$FileHash
    )
    
    try {
        $subject = $KIMConfig.EmailSubject -f $PatientName
        $body = Create-KIMEmailBody -PatientName $PatientName -ApoKey $ApoKey
        
        $mailParams = @{
            SmtpServer = $KIMConfig.SmtpServer
            Port = $KIMConfig.SmtpPort
            UseSsl = $KIMConfig.UseSSL
            From = $KIMConfig.EmailFrom
            To = $RecipientEmail
            Subject = $subject
            Body = $body
            Attachments = $PDFPath
            Encoding = "UTF8"
            ErrorAction = "Stop"
        }
        
        # Authentifizierung hinzufügen, falls konfiguriert
        if ($KIMConfig.Credential) {
            $mailParams.Credential = $KIMConfig.Credential
        }
        
        # Retry-Logik
        for ($i = 1; $i -le $ErrorConfig.RetryAttempts; $i++) {
            try {
                Send-MailMessage @mailParams
                Write-Log "PDF gesendet an: $RecipientEmail" -Status $LogConfig.Status_SENT -Patient $PatientName -Pharmacy $ApoKey -FileHash $FileHash
                
                # In SENT-Ordner verschieben
                $sentPath = Move-ToSentFolder -PDFPath $PDFPath -ApoKey $ApoKey
                
                return $true
            }
            catch {
                if ($i -eq $ErrorConfig.RetryAttempts) {
                    throw
                }
                Write-Log "Versand fehlgeschlagen (Versuch $i/$($ErrorConfig.RetryAttempts)): $($_.Exception.Message)" -Status "WARN"
                Start-Sleep -Seconds $ErrorConfig.RetryDelaySeconds
            }
        }
    }
    catch {
        Write-Log "Fehler beim E-Mail-Versand: $($_.Exception.Message)" -Status $LogConfig.Status_ERROR -Patient $PatientName -Pharmacy $ApoKey -FileHash $FileHash
        
        # Fehlerbenachrichtigung senden
        if ($ErrorConfig.EnableErrorNotifications) {
            Send-ErrorNotification -Subject "Versand fehlgeschlagen: $PatientName ($ApoKey)" -Body @"
Der Versand des eRezepts für Patient $PatientName an Apotheke $ApoKey ist fehlgeschlagen.

Fehler: $($_.Exception.Message)

Datei: $PDFPath
KIM-Adresse: $RecipientEmail
"@
        }
        
        return $false
    }
}

function Create-KIMEmailBody {
    <#
    .SYNOPSIS
        Erstellt den E-Mail-Body für KIM-Versand
    #>
    param(
        [string]$PatientName,
        [string]$ApoKey
    )
    
    return @"
Sehr geehrte Apotheke,

Anbei das eRezept für Patienten: $PatientName
Apotheken-Key: $ApoKey

Dies ist eine automatisch generierte Nachricht.
Bei Fragen wenden Sie sich bitte an die Praxis.

Mit freundlichen Grüßen
Ihre Praxis

---
Gesendet via eRezept-Automatisierung v2.0
"@
}

function Move-ToSentFolder {
    <#
    .SYNOPSIS
        Verschiebt gesendete PDF in SENT-Ordner
    #>
    param(
        [string]$PDFPath,
        [string]$ApoKey
    )
    
    try {
        $sentFolder = Join-Path $Config.SentFolder $ApoKey
        if (-not (Test-Path $sentFolder)) {
            New-Item -ItemType Directory -Path $sentFolder -Force | Out-Null
        }
        
        $sentPath = Join-Path $sentFolder (Split-Path $PDFPath -Leaf)
        Move-Item -Path $PDFPath -Destination $sentPath -Force
        
        Write-Log "PDF in SENT-Ordner verschoben: $sentPath" -Status "INFO"
        
        return $sentPath
    }
    catch {
        Write-Log "Fehler beim Verschieben nach SENT: $($_.Exception.Message)" -Status "ERROR"
        return $null
    }
}

function Test-KIMConnection {
    <#
    .SYNOPSIS
        Testet die Verbindung zum KIM-SMTP-Server
    #>
    try {
        Write-Log "Teste KIM-Verbindung..." -Status "INFO"
        
        $testParams = @{
            SmtpServer = $KIMConfig.SmtpServer
            Port = $KIMConfig.SmtpPort
            UseSsl = $KIMConfig.UseSSL
            From = $KIMConfig.EmailFrom
            To = $KIMConfig.EmailFrom  # Test an sich selbst
            Subject = "KIM-Verbindungstest"
            Body = "Dies ist ein automatischer Verbindungstest."
            ErrorAction = "Stop"
        }
        
        if ($KIMConfig.Credential) {
            $testParams.Credential = $KIMConfig.Credential
        }
        
        Send-MailMessage @testParams
        
        Write-Log "KIM-Verbindungstest erfolgreich" -Status "INFO"
        return $true
    }
    catch {
        Write-Log "KIM-Verbindungstest fehlgeschlagen: $($_.Exception.Message)" -Status "ERROR"
        return $false
    }
}

function Configure-KIMAuthentication {
    <#
    .SYNOPSIS
        Konfiguriert die KIM-Authentifizierung
    #>
    try {
        Write-Host "KIM-Authentifizierung konfigurieren" -ForegroundColor Yellow
        Write-Host "SMTP-Server: $($KIMConfig.SmtpServer):$($KIMConfig.SmtpPort)" -ForegroundColor Gray
        
        # Prüfen ob bereits Anmeldedaten gespeichert sind
        if (Test-Path "$($Config.ToolsFolder)\kim_cred.xml") {
            Write-Host "Gespeicherte Anmeldedaten gefunden." -ForegroundColor Green
            $KIMConfig.Credential = Import-Clixml -Path "$($Config.ToolsFolder)\kim_cred.xml"
            return $true
        }
        
        # Anmeldedaten abfragen
        Write-Host "Bitte geben Sie die KIM-Anmeldedaten ein:" -ForegroundColor Yellow
        $credential = Get-Credential -Message "KIM SMTP-Anmeldung" -UserName "benutzer@domain.de"
        
        if ($credential) {
            # Anmeldedaten speichern
            $credential | Export-Clixml -Path "$($Config.ToolsFolder)\kim_cred.xml"
            $KIMConfig.Credential = $credential
            
            Write-Host "Anmeldedaten gespeichert." -ForegroundColor Green
            return $true
        }
        
        return $false
    }
    catch {
        Write-Log "Fehler bei KIM-Authentifizierung: $($_.Exception.Message)" -Status "ERROR"
        return $false
    }
}
