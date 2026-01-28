Ich will den fehleranfälligen, manuellen Schritt unseres eRezept-Versands ablösen. Nach der Freigabe erzeugt unser PDFCreator bereits korrekt benannte PDFs; aktuell verschiebt das Praxis­team diese Dateien jedoch von Hand in apotheken­spezifische Unterordner und hängt sie anschließend im Arztprogramm per KIM an. Dabei passieren Übertragungsfehler, Doppelversand und falsche Zuordnungen.

Deine Aufgabe ist ein PowerShell-Skript, das diesen Prozess vollständig automatisiert:

• Patientennamen direkt aus jedem neu abgelegten PDF auslesen.
• In einer bestehenden Excel-Tabelle den zugehörigen Eintrag „Patientenname → Apotheke“ nachschlagen.
• Das PDF in den richtigen, apotheken­spezifischen Unterordner verschieben.
• In einer bestehenden Excel-Tabelle den zugehörigen Eintrag „Apotheke → KIM-(EMail-Adresse“ nachschlagen.
• Aus den Unterordnern per KIM-Dienst an die richtige Apotheke per Mail versendet.


Rahmenbedingungen
– Skript läuft als Windows-Dienst über NSSM.
– Alle Pfade und Dateinamen sollen am Skriptanfang in Variablen zentral gepflegt werden (relativ, keine Festpfade).
– Kommentiere jeden einzelnen Schritt verständlich; erkläre zusätzlich den Gesamtaufbau im Kopfbereich des Skripts. Eine kurze Anleitung zur Installation und Ausführung (README) soll beiliegen.
– Nutze ausschließlich PowerShell-Bordmittel bzw. gängige Module für PDF-Parsing und Excel-Zugriff (z. B. ImportExcel oder COM-Interop) – bitte im Code referenzieren.
- Logging der Vorgänge im einem Ordner, Audit-/Revisionsnähe: append-only Log (z. B. JSONL) mit SHA-256 pro PDF, Timestamp, ApoKey, Patient-Identifier (datensparsam), Status (ROUTED/SENT/DUPLICATE_BLOCKED/UNKLAR). Zusätzlich Doppelversand-Schutz über Hash.

Lieferumfang
1. Vollständig funktionsfähiges .ps1-Skript, lauffähig unter Windows 10/11 und Windows Server als Dienst.
2. Ausführliche Inline-Kommentare plus erklärender Abschnitt zur Gesamtlogik.
3. Separate Installationsanleitung inkl. NSSM-Einrichtung und ggf. Modul-Installation.

Eine ausführliche Beschreibung des gewünschten Ablaufs liegt vor.
Bei Rückfragen zu bestehenden Ordnerstrukturen oder zur Excel-Datei liefere ich Beispiele. Ich freue mich auf deine Lösung, die unseren Praxisablauf spürbar beschleunigt und Fehlerquellen eliminiert.