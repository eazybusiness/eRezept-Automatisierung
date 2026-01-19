# eRezept-Versand Automatisierung

PowerShell-Skript zur vollautomatisierten Verarbeitung und zum Versand von eRezept-PDFs an Apotheken über den KIM-Dienst.

## 🎯 Funktionsumfang

- **Automatische PDF-Überwachung**: Kontinuierliche Überwachung des Eingangsordners auf neue eRezept-PDFs
- **Intelligente Patientenextraktion**: Extrahiert Patientennamen direkt aus PDF-Metadaten und -Inhalt
- **Excel-basierte Zuordnung**: Sucht automatisch die passende Apotheke und KIM-E-Mail-Adresse in Excel-Tabellen
- **Automatische Dateiverteilung**: Verschiebt PDFs in die richtigen apothekenspezifischen Unterordner
- **KIM-Dienst Integration**: Versendet eRezepte automatisch per E-Mail an die zuständige Apotheke
- **Duplikatschutz**: Verhindert Doppelversand durch SHA-256 Hash-Überprüfung
- **Umfassendes Logging**: JSONL-basiertes Audit-Log mit allen Verarbeitungsschritten

## 📋 Voraussetzungen

- Windows 10/11 oder Windows Server
- PowerShell 5.1 oder höher
- ImportExcel PowerShell Modul
- Zugriff auf KIM-Dienst SMTP-Server
- Excel-Dateien mit Patienten↔Apotheke und Apotheke↔KIM-Email Zuordnungen

## 🚀 Schnellstart

### 1. Modul installieren
```powershell
Install-Module -Name ImportExcel -Scope CurrentUser
```

### 2. Verzeichnisstruktur anlegen
```
eRezept-Automatisierung/
├── eRezept-Automatisierung.ps1
├── input/                    # Neue PDFs vom PDFCreator
├── pharmacies/               # Unterordner pro Apotheke
├── logs/                     # JSONL Logdateien
├── temp/                     # Temporäre Dateien
└── data/
    ├── patienten_apotheken.xlsx
    └── apotheken_emails.xlsx
```

### 3. Konfiguration anpassen
Öffnen Sie `eRezept-Automatisierung.ps1` und passen Sie den `$Config` Abschnitt an:
- Pfade zu Ihren Ordnern
- Excel-Dateinamen und Spaltennamen
- KIM-Dienst E-Mail-Einstellungen

### 4. Testlauf
```powershell
.\eRezept-Automatisierung.ps1
```

## 🔧 Windows Service Installation (NSSM)

### 1. NSSM herunterladen
https://nssm.cc/download und entpacken

### 2. Service installieren
```cmd
nssm install "eRezept-Automatisierung" "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
nssm set "eRezept-Automatisierung" Arguments "-ExecutionPolicy Bypass -File ""C:\Pfad\zum\Skript\eRezept-Automatisierung.ps1"""
nssm set "eRezept-Automatisierung" DisplayName "eRezept-Versand Automatisierung"
nssm set "eRezept-Automatisierung" Description "Automatischer Versand von eRezept-PDFs an Apotheken"
nssm set "eRezept-Automatisierung" Start SERVICE_AUTO_START
```

### 3. Service starten
```cmd
net start "eRezept-Automatisierung"
```

## 📊 Excel-Dateien Format

### patienten_apotheken.xlsx
| Patientenname | Apotheke |
|---------------|----------|
| Max Mustermann | Apotheke am Markt |
| Erika Muster | Sonnen-Apotheke |

### apotheken_emails.xlsx
| Apotheke | KIM_Email |
|----------|-----------|
| Apotheke am Markt | pharmacy1@kim.domain.de |
| Sonnen-Apotheke | pharmacy2@kim.domain.de |

## 📝 Logging

Das Skript erstellt detaillierte Logs im `logs/` Verzeichnis:
- **Format**: JSONL (JSON Lines) für einfache Verarbeitung
- **Inhalt**: Timestamp, Status, Patient, Apotheke, File-Hash, Messages
- **Status-Codes**: `SENT`, `ROUTED`, `DUPLICATE_BLOCKED`, `UNKLAR`, `ERROR`

Beispiel Log-Eintrag:
```json
{"timestamp":"2024-01-19T15:30:45.123Z","status":"SENT","message":"PDF gesendet an: pharmacy1@kim.domain.de","patient":"Max Mustermann","pharmacy":"Apotheke am Markt","file_hash":"a1b2c3d4..."}
```

## ⚙️ Konfiguration

Die wichtigsten Konfigurationsparameter im Skriptkopf:

```powershell
$Config = @{
    InputFolder = ".\input"                    # PDF-Eingangsordner
    PharmacyFolders = ".\pharmacies"           # Apotheken-Unterordner
    ScanInterval = 30                          # Scan-Intervall in Sekunden
    SmtpServer = "localhost"                   # KIM-Dienst SMTP
    EmailFrom = "praxis@domain.de"             # Absenderadresse
}
```

## 🔍 Fehlerbehebung

### Häufige Probleme
1. **ImportExcel Modul nicht gefunden**: Modul mit `Install-Module ImportExcel` installieren
2. **PDF-Extraktion schlägt fehl**: PDF-Struktur prüfen, Regex-Muster anpassen
3. **Excel-Zugriff funktioniert nicht**: Spaltennamen und Sheet-Namen überprüfen
4. **E-Mail-Versand fehlerhaft**: SMTP-Einstellungen und KIM-Dienst-Konnektivität prüfen

### Debugging
- Logs in `logs/` Verzeichnis überprüfen
- PowerShell-Konsole für detaillierte Fehlermeldungen verwenden
- Test-PDFs mit bekannten Patientennamen erstellen

## 🛡️ Sicherheit & Datenschutz

- **Datensparsamkeit**: Es werden nur notwendige Daten geloggt (Patientenname, Apotheke, Hash)
- **Duplikatschutz**: SHA-256 Hash verhindert Doppelverarbeitung
- **Audit-Trail**: Vollständige Nachverfolgung aller Verarbeitungsschritte
- **Append-only Logs**: Manipulationssichere Protokollierung

## 📞 Support

Bei Fragen oder Problemen:
1. Logdateien überprüfen
2. Konfiguration prüfen
3. Test mit einzelnen PDF-Dateien durchführen

---

**Version**: 1.0  
**Kompatibilität**: Windows 10/11, Windows Server 2016+  
**PowerShell**: 5.1+
