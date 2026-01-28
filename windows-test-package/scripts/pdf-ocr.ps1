# PDF-OCR Modul für eRezept-Automatisierung
# Extrahiert Patientennamen aus -90° gedrehten PDFs

function Rotate-PDF {
    <#
    .SYNOPSIS
        Rotiert eine PDF-Datei um 90 Grad im Uhrzeigersinn
    .PARAMETER Path
        Pfad zur PDF-Datei
    .PARAMETER OutputPath
        Pfad für die rotierte PDF-Datei
    #>
    param(
        [string]$Path,
        [string]$OutputPath
    )
    
    try {
        # Ghostscript Befehl zum Rotieren
        $gsArgs = @(
            "-sDEVICE=pdfwrite",
            "-dNOPAUSE",
            "-dBATCH",
            "-dAutoRotatePages=/None",
            "-c", "<</Install {90}>> setpagedevice",
            "-f", $Path,
            "-o", $OutputPath
        )
        
        Write-Log "Rotiere PDF: $Path" -Status "INFO"
        
        # Ghostscript ausführen
        $process = Start-Process -FilePath $Config.GhostscriptExe -ArgumentList $gsArgs -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0 -and (Test-Path $OutputPath)) {
            Write-Log "PDF erfolgreich rotiert: $OutputPath" -Status "INFO"
            return $OutputPath
        } else {
            Write-Log "Fehler bei PDF-Rotation: ExitCode $($process.ExitCode)" -Status "ERROR"
            return $null
        }
    }
    catch {
        Write-Log "Fehler bei PDF-Rotation: $($_.Exception.Message)" -Status "ERROR"
        return $null
    }
}

function Extract-TextFromPDF {
    <#
    .SYNOPSIS
        Extrahiert Text aus PDF mit Tesseract OCR
    .PARAMETER Path
        Pfad zur PDF-Datei
    #>
    param([string]$Path)
    
    try {
        # Temporäre Datei für OCR-Output
        $tempTxt = Join-Path $env:TEMP "ocr_$(Get-Random).txt"
        
        # Tesseract Befehl
        $tessArgs = @(
            $Path,
            $tempTxt.Replace('.txt', ''),  # Tesseract fügt .txt automatisch hinzu
            "-l", $ProcessingConfig.OCRLanguage,
            "--psm", "6",  # Uniform block of text
            "--oem", "3"   # Default OCR engine mode
        )
        
        Write-Log "Führe OCR durch: $Path" -Status "INFO"
        
        # Tesseract ausführen
        $process = Start-Process -FilePath $Config.TesseractExe -ArgumentList $tessArgs -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0 -and (Test-Path $tempTxt)) {
            $text = Get-Content -Path $tempTxt -Encoding UTF8 -Raw
            Remove-Item $tempTxt -Force -ErrorAction SilentlyContinue
            Write-Log "OCR erfolgreich, Textlänge: $($text.Length)" -Status "INFO"
            return $text
        } else {
            Write-Log "Fehler bei OCR: ExitCode $($process.ExitCode)" -Status "ERROR"
            return $null
        }
    }
    catch {
        Write-Log "Fehler bei OCR: $($_.Exception.Message)" -Status "ERROR"
        return $null
    }
}

function Extract-PatientNameFromPDF {
    <#
    .SYNOPSIS
        Extrahiert Patientenname und Geburtsdatum aus PDF
    .PARAMETER Path
        Pfad zur PDF-Datei
    .RETURNS
        Hashtable mit Name und Geburtsdatum oder $null
    #>
    param([string]$Path)
    
    try {
        Write-Log "Verarbeite PDF: $Path" -Status "INFO"
        
        # Schritt 1: PDF rotieren
        $rotatedPdf = Join-Path $env:TEMP "rotated_$(Get-Random).pdf"
        $rotationResult = Rotate-PDF -Path $Path -OutputPath $rotatedPdf
        
        if (-not $rotationResult) {
            Write-Log "PDF-Rotation fehlgeschlagen: $Path" -Status "ERROR"
            return $null
        }
        
        # Schritt 2: OCR durchführen
        $ocrText = Extract-TextFromPDF -Path $rotatedPdf
        
        # Temporäre Datei aufräumen
        Remove-Item $rotatedPdf -Force -ErrorAction SilentlyContinue
        
        if (-not $ocrText) {
            Write-Log "OCR fehlgeschlagen: $Path" -Status "ERROR"
            return $null
        }
        
        # Schritt 3: Regex-Patterns für Patientendaten
        $patterns = @(
            # Pattern 1: "Für Max Mustermann geboren am 15.01.1945"
            "Für\s+(?<name>[A-ZäöüÄÖÜ][a-zäöüß]+(?:\s+[A-ZäöüÄÖÜ][a-zäöüß]+)+)\s+geboren\s+am\s+(?<datum>\d{2}\.\d{2}\.\d{4})",
            
            # Pattern 2: "Patient: Mustermann, Max geb. 15.01.1945"
            "Patient:\s+(?<name>[A-ZäöüÄÖÜ][a-zäöüß]+(?:\s+[A-ZäöüÄÖÜ][a-zäöüß]+),\s+[A-ZäöüÄÖÜ][a-zäöüß]+)\s+geb\.\s+(?<datum>\d{2}\.\d{2}\.\d{4})",
            
            # Pattern 3: "Name: Max Mustermann, DOB: 15.01.1945"
            "Name:\s+(?<name>[A-ZäöüÄÖÜ][a-zäöüß]+(?:\s+[A-ZäöüÄÖÜ][a-zäöüß]+))[,\s]*Geburtsdatum[:\s]+(?<datum>\d{2}\.\d{2}\.\d{4})",
            
            # Pattern 4: Nur Name, Datum separat suchen
            "(?s)Für\s+(?<name>[A-ZäöüÄÖÜ][a-zäöüß]+(?:\s+[A-ZäöüÄÖÜ][a-zäöüß]+)+).*?(?:geboren\s+am|geb\.\s*|Geburtsdatum[:\s]*)\s*(?<datum>\d{2}\.\d{2}\.\d{4})"
        )
        
        # Debug: OCR-Output in Log schreiben (nur erste 500 Zeichen)
        Write-Log "OCR-Output (erste 500 Zeichen): $($ocrText.Substring(0, [Math]::Min(500, $ocrText.Length)))" -Status "DEBUG"
        
        # Pattern durchtesten
        foreach ($pattern in $patterns) {
            if ($ocrText -match $pattern) {
                $name = $matches['name'].Trim()
                $datum = $matches['datum'].Trim()
                
                Write-Log "Patient gefunden: Name='$name', Geburtsdatum='$datum'" -Status "INFO"
                
                return @{
                    Name = $name
                    BirthDate = $datum
                    FullName = "$name ($datum)"
                }
            }
        }
        
        # Fallback: Name und Datum getrennt suchen
        $namePattern = "Für\s+([A-ZäöüÄÖÜ][a-zäöüß]+(?:\s+[A-ZäöüÄÖÜ][a-zäöüß]+)+)"
        $datePattern = "(?:geboren\s+am|geb\.\s*|Geburtsdatum[:\s]*)\s*(\d{2}\.\d{2}\.\d{4})"
        
        $nameMatch = [regex]::Match($ocrText, $namePattern)
        $dateMatch = [regex]::Match($ocrText, $datePattern)
        
        if ($nameMatch.Success -and $dateMatch.Success) {
            $name = $nameMatch.Groups[1].Value.Trim()
            $datum = $dateMatch.Groups[1].Value.Trim()
            
            Write-Log "Patient gefunden (Fallback): Name='$name', Geburtsdatum='$datum'" -Status "INFO"
            
            return @{
                Name = $name
                BirthDate = $datum
                FullName = "$name ($datum)"
            }
        }
        
        Write-Log "Keine Patientendaten gefunden in: $Path" -Status "WARN"
        return $null
    }
    catch {
        Write-Log "Fehler bei Extraktion: $($_.Exception.Message)" -Status "ERROR"
        return $null
    }
}

function Test-PDFQuality {
    <#
    .SYNOPSIS
        Testet die Qualität der OCR-Erkennung
    .PARAMETER Text
        Extrahierter Text aus PDF
    #>
    param([string]$Text)
    
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }
    
    # Einfache Qualitätschecks
    $hasGermanChars = $Text -match '[äöüÄÖÜß]'
    $hasNumbers = $Text -match '\d'
    $hasValidWords = $Text -match '\b(Für|Patient|Name|geboren|Geburtsdatum)\b'
    
    return $hasGermanChars -and $hasNumbers -and $hasValidWords
}
