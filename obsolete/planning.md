# eRezept-Versand Automatisierung - Konzept

## Projektübersicht
Automatisierung des manuellen eRezept-Versands für eine medizinische Praxis durch ein PowerShell-Skript, das als Windows-Dienst läuft.

## Ausgangssituation
- PDFCreator erzeugt bereits korrekt benannte PDFs
- Manuelles Verschieben in Apotheken-Unterordner durch Praxis-Team
- Manuelles Anhängen im Arztprogramm per KIM
- Probleme: Übertragungsfehler, Doppelversand, falsche Zuordnungen

## Zielsetzung
Vollautomatischer Prozess:
1. PDF-Überwachung → Patientenname extrahieren
2. Excel-Lookup: Patient → Apotheke
3. PDF verschieben in Apotheken-Unterordner
4. Excel-Lookup: Apotheke → KIM-Email
5. Versand per KIM-Dienst

## Architektur

### Komponenten
- **PowerShell-Skript** (.ps1): Hauptlogik
- **NSSM**: Windows Service Manager
- **Tesseract OCR**: Texterkennung für gedrehte PDFs
- **Ghostscript**: PDF-Rotation und -Verarbeitung
- **CSV-Parser**: PowerShell `Import-Csv` (kein Excel)
- **KIM-Dienst**: E-Mail-Versand (SMTP über kv.dox)

### Datenflüsse
```
PDFCreator → C:\Daten\ERP\Heim_INBOX → PowerShell-Service → CSV-Lookups → C:\Daten\ERP\Heim\Apotheken\APO_* → KIM-Dienst → Apotheke
```

### Verzeichnisstruktur (Kunden-Pfade)
```
C:\Daten\ERP\
├── Heim_INBOX/                    # Neue PDFs vom PDFCreator
├── Heim/
│   ├── Apotheken/                 # Apotheken-Unterordner (APO_*)
│   ├── UNKLAR/                    # Nicht zuordbare PDFs
│   └── SENT/                      # Erfolgreich gesendet (APO_*)
├── Heim_LOGGING/                  # JSONL Audit-Logs
├── patient_apo_mapping.csv        # Patient → Apotheke (Spalte 34)
├── KIM_apo_mapping.csv           # Apotheke → KIM-Email
└── tools/                         # Mitgelieferte Tools
    ├── tesseract.exe              # OCR Engine
    ├── tessdata/                  # Sprachpakete (deu)
    └── gswin64c.exe               # Ghostscript für PDF-Verarbeitung
```

## Technische Umsetzung

### PDF-Verarbeitung (mit OCR)
- **Herausforderung**: PDFs sind -90° gedreht, Text von unten nach oben
- **Schritt 1**: PDF mit Ghostscript um 90° korrigieren
- **Schritt 2**: OCR mit Tesseract (Deutsch) für Text-Extraktion
- **Schritt 3**: Regex-Patterns für "Für" und "geboren am" Felder
- **Tools**: Ghostscript.exe + Tesseract.exe mitliefern
- **Performance**: OCR langsamer als Text-Extraktion, aber zuverlässig

### CSV-Integration (statt Excel)
- **Modul**: PowerShell `Import-Csv` (keine externen Abhängigkeiten)
- **patient_apo_mapping.csv**: Spalte 2 (Nachname), 4 (Vorname), 6 (Geburtsdatum), 34 (APO_KEY)
- **KIM_apo_mapping.csv**: KIM_APO, KIM_ADDR, APO_NAME
- **Matching**: Name + Geburtsdatum für eindeutige Identifikation
- **Caching**: In-Memory für Performance bei großen Dateien

### Logging & Audit
- **Format**: JSONL (JSON Lines) für append-only
- **Inhalt**: Timestamp, SHA-256 Hash, Patient (datensparsam), Apotheke, Status
- **Status-Codes**: ROUTED, SENT, DUPLICATE_BLOCKED, UNKLAR, ERROR
- **Retention**: Konfigurierbare Aufbewahrung

### Duplikatschutz
- **SHA-256 Hash** pro PDF
- **Hash-DB**: In Logdateien gespeichert
- **Check**: Vor Verarbeitung neuer PDFs

### Windows-Service
- **NSSM**: Non-Sucking Service Manager
- **Konfiguration**: Autostart, Recovery-Actions
- **Logging**: Windows Event Log Integration
- **Monitoring**: Health-Checks

## Sicherheitsaspekte

### Datenschutz
- **Datensparsamkeit**: Nur notwendige Daten loggen
- **Pseudonymisierung**: Patient-Identifier statt voller Namen
- **Access Control**: NTFS-Berechtigungen für Ordner

### Betriebssicherheit
- **Error-Handling**: Try-Catch mit Retry-Logik
- **Monitoring**: Log-Analyse, Alerting bei Fehlern
- **Backup**: Konfiguration und Logs sichern
- **Rollback**: Deinstallations-Skript

### Testmodus (kein Versand)
- **EnableSend-Schalter**: Standardmäßig ist `EnableSend = $false`, sodass kein SMTP-Versand stattfindet.
- **SMTP-Host im Test**: Standardmäßig wird ein Test-Host (z.B. `testserver`) verwendet; der produktive Host bleibt auskommentiert.
- **Ziel**: End-to-End Test (Routing, Logging, Duplikatschutz) ohne Datenversand.

## Offene Punkte (Geklärt)

### PDF-Struktur ✅
- PDFs von PDFCreator 3.5.0, Version 1.4, 1 Seite
- **Problem**: -90° gedreht, Text von unten nach oben
- **Lösung**: Ghostscript Rotation + Tesseract OCR
- Patientendaten in "Für" und "geboren am" Feldern
- OCR-Genauigkeit: 90-95% bei guter Qualität

### CSV-Format ✅
- patient_apo_mapping.csv: Semikolon-getrennt, 34 Spalten
- Name in Spalte 2+4, Geburtsdatum in Spalte 6, APO_KEY in Spalte 34
- KIM_apo_mapping.csv: KIM_APO;KIM_ADDR;APO_NAME
- Patienten können gleichen Namen haben → Geburtsdatum erforderlich

### KIM-Dienst ✅
- KV-DOX-Mailclient (Domain: kv.dox.kim.telematik)
- Alternativen: Outlook oder Thunderbird
- SMTP-Versand über kv.dox Clientmodul/Proxy
- E-Mail-Format: Standard mit PDF-Anhang

### Bugfixes (Stabilität) ✅
- **Hash-Berechnung**: Namenskonflikt/Rekursion bei `Get-FileHash` behoben (Aufruf des Built-in Cmdlets via Modulqualifizierung), um Abstürze zu vermeiden.

## Offene Punkte (Noch zu klären)

### KIM-Dienst Konfiguration
- SMTP-Server: kv.dox.kim.telematik (Port, Auth?)
- Benötigt es spezielle Header oder Formate?
- Alternative: Outlook/Thunderbird Automation?

### Fehlerbehandlung
- E-Mail-Adresse für Benachrichtigungen bei UNKLAR/FEHLER
- Wer erhält die Benachrichtigungen?

### Performance-Optimierung
- OCR-Verarbeitung kann langsam sein
- Batch-Verarbeitung oder parallele Prozesse?

## Risiken & Mitigation (Aktualisiert)

### Technische Risiken
- **PDF-OCR**: Gedrehte PDFs → Ghostscript + Tesseract Lösung
- **OCR-Genauigkeit**: 90-95% → Regex-Fallbacks und manuelle Prüfung
- **CSV-Performance**: 250+ Zeilen → Caching implementieren
- **KIM-Dienst**: Unbekannte SMTP-Settings → Kunden-Support kontaktieren

### Betriebsrisiken
- **Performance**: OCR langsamer → Batch-Verarbeitung implementieren
- **Stabilität**: Windows Service ohne GUI → Robustes Error-Handling
- **Wartung**: Tools mitliefern → Versionskontrolle wichtig

### Geschäftsrisiken
- **Doppeleinträge**: Same Name + DOB Matching → SHA-256 Hash
- **Fehlzweisung**: UNKLAR-Ordner mit E-Mail-Benachrichtigung
