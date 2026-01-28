# eRezept-Versand Automatisierung - Taskliste

## Phase 1: Analyse & Klärung (OFFEN - Kundeninput erforderlich)

### 1.1 Spezifikationen klären
- [x] **PDF-Struktur analysiert**: PDFCreator 3.5.0, -90° gedreht
- [x] **OCR-Lösung definiert**: Ghostscript + Tesseract
- [x] **CSV-Format geklärt**: Semikolon-getrennt, Spalten 2,4,6,34
- [x] **KIM-Dienst-Details**: KV-DOX-Mailclient, SMTP über kv.dox.kim.telematik
- [ ] **SMTP-Einstellungen**: Port, Authentifizierung klären
- [ ] **Fehler-Email**: Empfänger für UNKLAR/FEHLER Meldungen
- [ ] **Performance**: Batch-Verarbeitung für OCR

### 1.2 Entwicklungsumgebung vorbereiten
- [ ] PowerShell Core auf Linux installieren (für Syntax-Check)
- [ ] Test-Verzeichnisstruktur anlegen
- [ ] Mock-Daten erstellen (Beispiel-PDFs, Excel-Dateien)

## Phase 2: Grundfunktionalität entwickeln

### 2.1 Core Module erstellen
- [ ] **PDF-OCR Module** (`scripts/pdf-ocr.ps1`)
  - Funktion: `Extract-PatientNameFromPDF`
  - Schritt 1: PDF mit Ghostscript um 90° korrigieren
  - Schritt 2: Tesseract OCR mit deutschem Sprachpaket
  - Schritt 3: Regex für "Für" und "geboren am" Felder
  - Error-Handling für OCR-Fehler

- [ ] **Tools Setup** (`scripts/setup-tools.ps1`)
  - Tesseract.exe herunterladen/kopieren
  - Deutsche Sprachpakete (tessdata/deu.traineddata)
  - Ghostscript (gswin64c.exe) einrichten
  - Pfade in Konfiguration schreiben

- [ ] **CSV-Lookup Module** (`scripts/csv-lookup.ps1`)
  - Funktion: `Get-PharmacyForPatient`
  - Funktion: `Get-EmailForPharmacy`
  - Matching: Name + Geburtsdatum (Spalte 2+4+6)
  - APO_KEY aus Spalte 34 extrahieren
  - In-Memory Cache für Performance

- [ ] **File-Operations Module** (`scripts/file-ops.ps1`)
  - Funktion: `Move-PDFToPharmacyFolder`
  - Funktion: `Get-FileHash` (SHA-256)
  - Funktion: `Test-DuplicateFile`
  - UNKLAR-Ordner Handling

### 2.2 Logging System implementieren
- [ ] **Logging Module** (`scripts/logger.ps1`)
  - JSONL Format implementieren
  - Status-Codes: ROUTED, SENT, DUPLICATE_BLOCKED, UNKLAR, ERROR
  - Append-only mit Datei-Rotation
  - Datensparsame Patient-Identifier

### 2.3 Hauptskript Struktur
- [ ] Konfigurationsbereich auslagern (`config/settings.ps1`)
- [ ] Modul-Imports und Error-Handling
- [ ] Hauptverarbeitungsschleife mit Scan-Interval

## Phase 3: Erweiterte Funktionen

### 3.1 KIM-Dienst Integration
- [ ] **Email Module** (`scripts/email-sender.ps1`)
  - SMTP-Client für kv.dox.kim.telematik
  - Authentifizierung (noch zu klären)
  - Attachment-Handling für PDFs
  - Retry-Logik bei temporären Fehlern
  - Template-System für E-Mail-Inhalte
  - Alternative: Outlook COM-Objekt

### 3.2 OCR-Performance Optimierung
- [ ] **Batch-Verarbeitung**: Mehrere PDFs parallel verarbeiten
- [ ] **OCR-Caching**: Ergebnisse zwischenspeichern bei Duplikaten
- [ ] **Progress-Tracking**: Fortschritt für lange OCR-Vorgänge

### 3.2 Duplikatschutz & Hashing
- [ ] Hash-DB implementieren (in JSONL Logs)
- [ ] Performance-Optimierung für große Log-Dateien
- [ ] Hash-Collision Handling

### 3.3 Error-Handling & Recovery
- [ ] Try-Catch Blöcke für alle kritischen Operationen
- [ ] Retry-Mechanismus mit exponential backoff
- [ ] Dead-Letter-Queue für nicht verarbeitbare Dateien
- [ ] Health-Check Funktionen

## Phase 4: Windows Service Integration

### 4.1 NSSM Service Setup
- [ ] **Service Installation Script** (`scripts/setup-service.ps1`)
  - NSSM Download und Installation
  - Service-Konfiguration (Autostart, Recovery)
  - Windows Event Log Integration

- [ ] **Service Management Script** (`scripts/manage-service.ps1`)
  - Start/Stop/Restart Funktionen
  - Status-Abfrage
  - Log-Anzeige

### 4.2 Deployment Package
- [ ] **Installation Script** (`scripts/install.ps1`)
  - Abhängigkeiten prüfen (PowerShell Version, Module)
  - Verzeichnisstruktur erstellen
  - Berechtigungen setzen
  - Service einrichten

- [ ] **Deinstallation Script** (`scripts/uninstall.ps1`)
  - Service entfernen
  - Dateien sauber löschen (optional Logs behalten)

## Phase 5: Testing & Qualitätssicherung

### 5.1 Unit Tests (Pester)
- [ ] PDF-Parser Tests mit verschiedenen PDF-Formaten
- [ ] Excel-Lookup Tests mit Edge-Cases
- [ ] Logging Tests mit allen Status-Codes
- [ ] Hash-Funktionen Tests

### 5.2 Integration Tests
- [ ] End-to-End Workflow Tests
- [ ] Performance Tests (100+ PDFs)
- [ ] Error-Simulation Tests
- [ ] Windows Service Tests

### 5.3 User Acceptance Tests
- [ ] Test-Szenarien mit echten Praxis-Daten
- [ ] Usability-Tests für Installation/Wartung
- [ ] Dokumentations-Tests

## Phase 6: Dokumentation & Delivery

### 6.1 Technische Dokumentation
- [ ] Code-Kommentare vervollständigen
- [ ] Architektur-Dokumentation
- [ ] API-Referenz (falls benötigt)

### 6.2 Benutzerdokumentation
- [ ] README.md aktualisieren
- [ ] Schritt-für-Schritt Installationsanleitung
- [ ] Troubleshooting Guide
- [ ] FAQ mit häufigen Problemen

### 6.3 Delivery Package erstellen
- [ ] ZIP-Datei mit allen Komponenten
- [ ] Versionsnummer und Changelog
- [ ] Test-Zertifikat (falls benötigt)

## Phase 7: Abnahme & Support

### 7.1 Kunden-Abnahme
- [ ] Live-Demonstration
- [ ] Handover an Kunden
- [ ] Schulung (falls benötigt)

### 7.2 Support-Vorbereitung
- [ ] Monitoring-Setup
- [ ] Alerting-Konfiguration
- [ ] Wartungs-Dokumentation

## Kritische Abhängigkeiten

### BLOCKER (müssen geklärt werden):
1. **KIM-SMTP-Einstellungen** (Port, Auth, Header)
2. **Fehler-Email-Adresse** für Benachrichtigungen
3. **Performance-Anforderungen** (Wie viele PDFs pro Stunde?)

### Optional (nice-to-have):
1. **Test-Zugang** zum KIM-Dienst
2. **Benchmark**: OCR-Geschwindigkeit testen
3. **Monitoring**: Dashboard für Processing-Status

## Zeitplan (geschätzt)

- Phase 1: 1 Tag (OCR-Lösung definiert)
- Phase 2: 3-4 Tage (OCR + Tools Setup)
- Phase 3: 2-3 Tage (KIM + Performance)
- Phase 4: 1-2 Tage
- Phase 5: 2-3 Tage
- Phase 6: 1-2 Tage
- Phase 7: 1 Tag

**Gesamt: 11-16 Tage** (OCR erfordert 1-2 Tage extra)

## Risiken

### Hoch:
- **OCR-Genauigkeit**: 90-95% → Manuelle Nachprüfung erforderlich
- **Performance**: OCR langsamer als reine Text-Extraktion
- **Tool-Abhängigkeiten**: Tesseract + Ghostscript müssen mitgeliefert werden

### Mittel:
- KIM-Dienst hat spezielle Anforderungen
- Windows Service Berechtigungen für OCR-Tools

### Niedrig:
- CSV-Formatänderungen
- Netzwerkprobleme
