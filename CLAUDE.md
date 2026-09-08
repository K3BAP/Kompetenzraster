# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Sprache

**Code und Kommentare sind durchgängig deutsch** — Typen, Eigenschaften, Methoden, Dateinamen
(`Bewertungsskala`, `blattKompetenzen`, `pruefe(erzwungen:)`, `Selbstaktualisierung.swift`).
Nur Framework-Bezeichner sind englisch. Neuer Code folgt dem; eine englische Variable fällt hier
sofort auf. Die Oberfläche ist einsprachig deutsch, ohne String-Katalog.

## Befehle

```bash
make run       # bauen und starten
make build     # Debug bauen
make test      # alle Tests
make release   # dist/Kompetenzraster.zip + dist/latest.json
make icon      # App-Symbol neu zeichnen
make clean
```

Das Xcode-Projekt wird von XcodeGen aus `project.yml` erzeugt und liegt **nicht** im Repository.
`make` ruft `xcodegen generate` selbst auf; nach dem Anlegen oder Verschieben von Dateien muss es
laufen, sonst kennt das Projekt sie nicht.

Einzelne Tests (Swift Testing unter xcodebuild):

```bash
xcodebuild -scheme Kompetenzraster -configuration Debug test -only-testing:KompetenzrasterTests/BackupTests
xcodebuild -scheme Kompetenzraster -configuration Debug test -only-testing:'KompetenzrasterTests/PruefsummeTests/bekannterWert()'
```

Auf Funktionsebene sind die **Klammern Pflicht** — ohne sie läuft der Aufruf durch und meldet
„0 tests passed“, was leicht als Erfolg missverstanden wird.

`xcodebuild` schreibt zwischen die Testergebnisse zahlreiche `linkd.autoShortcut`-Warnungen des
Systems; sie sind bedeutungslos. Nützlich filtert `grep -E "^✘|error:|Test run with|\*\* TEST"`.

## Architektur

SwiftUI + SwiftData, macOS 15+, Swift 6. Eine lokale App für Lehrpersonen: Kompetenzraster,
Bewertungen je Schüler:in × Kompetenz, Kompetenzblume als Auswertung.

### Der Kompetenzbaum

`Kompetenzraster.kompetenzen` hält **alle** Kompetenzen flach; die Hierarchie entsteht
ausschließlich über `Kompetenz.eltern`/`.kinder`. Daraus folgen die zentralen Zugriffe:
`raster.wurzeln` (Knoten ohne Eltern, das sind die Kompetenzbereiche) und `raster.blattKompetenzen`
(Knoten ohne Kinder — **nur diese werden bewertet**). Die Tiefe ist bewusst unbegrenzt: Deutsch und
Sachunterricht sind zweistufig, Mathematik dreistufig.

Beim Verschieben schützt `Kompetenz.istVorfahrVon(_:)` vor Zyklen.

### Bewertungen

`Eintrag` existiert **genau einmal je Paar (SchuelerIn, Kompetenz)**. Alle Änderungen laufen über
`Erfassung.setze(_:fuer:schueler:in:)`; `nil` löscht. Wer den Eintrag direkt anlegt, bricht die
Invariante. Ein Verlauf mehrerer datierter Einträge ist bewusst nicht Teil dieser Fassung.

Zwei Ansichten schreiben dieselben Einträge: `SchuelerErfassungView` (der Bogen für ein Kind –
Zeile je Kompetenz, Spalte je Stufe, ein Klick auf die gesetzte Stufe nimmt sie zurück) und
`RasterMatrixView` (Klassenüberblick, Kinder als Spalten). `Kompetenz.blattgruppen` gliedert die
Zeilen des Bogens: eine Zwischenüberschrift nur dort, wo das Raster wirklich drei Ebenen hat.

### Mitarbeit

Eine `Mitarbeitsstunde` gehört zu **Klasse + Fach** (Freitext, nicht an ein Raster gebunden – in
Sport gibt es Mitarbeit auch ohne Kompetenzraster). Je Stunde und Kind gibt es **genau einen**
`Mitarbeitseintrag` mit drei Achsen (`Mitarbeitsachse`: Arbeitsverhalten, Häufigkeit, Qualität) zu
je vier festen Stufen. Anders als `Bewertungsskala` ist diese Skala bewusst **nicht** konfigurierbar:
Das Eintragen nach der Stunde muss in Sekunden gehen, und die Zahlen sollen über ein Schuljahr
vergleichbar bleiben.

Alle Änderungen laufen über `Mitarbeitserfassung`; ein Eintrag ohne Beobachtung, ohne Notiz und mit
anwesendem Kind wird wieder gelöscht, sonst zählte die Quote leere Zeilen mit. `Mitarbeitsauswertung`
rechnet: **abwesende Stunden und nicht beobachtete Achsen gehen weder in Mittelwert noch in die
Quote ein** – dieselbe Regel wie bei den Kompetenzen. `Halbjahr` leitet den Zeitraum aus der
Schuljahresbezeichnung ab (1.8.–31.1. bzw. 1.2.–31.7.).

Mitarbeit fließt **nicht** in Kompetenzblume und `Auswertung`. Sie ist keine Lehrplankompetenz, und
einzelne Stunden werden nicht benotet – gezeigt werden Mittelwerte und Verläufe, nicht Noten.

`Auswertung` bildet Teilbaum-Mittelwerte für Blume und Matrix. Wichtig: **unbewertete Kompetenzen
gehen nicht in den Mittelwert ein** — sie erscheinen als blasser Umriss, statt den Stand nach unten
zu ziehen.

### Skalen und Symbole

`Bewertungsskala` ist frei konfigurierbar (Anzahl, Namen, Farben, Symbole); `Bewertungsstufe.wert`
ist ein lückenloser Ordinalwert ab 0 und geht so in Mittelwerte ein. `Skalenverwaltung.entferne`
hängt die Einträge einer gelöschten Stufe an die nächstgelegene um und vergibt die Werte neu —
Bewertungen dürfen beim Umbau einer Skala nicht verloren gehen.

`SymbolQuelle` ist ein `Codable`-Enum mit vier Fällen. Der Standard `.pflanze` wird in
`PflanzenSymbol` selbst gezeichnet, weil SF Symbols keine Serie vom Samenkorn bis zur Blüte kennt.
Alles geht über `BewertungsSymbol`/`StufenSymbol`, damit Matrix, Blume, Skala-Editor und Legende
dasselbe Bild zeigen.

### Sicherungen

Eine `.kompetenzsicherung` ist **eine einzelne, lesbare JSON-Datei** — ohne Server soll eine
Sicherung auch dann verständlich bleiben, wenn diese App nicht mehr läuft. Die DTOs in
`BackupDTO.swift` sind **flache Listen mit UUID-Verweisen**, nicht verschachtelt. `BackupService`
schreibt daher **zweiphasig**: erst alle Objekte anlegen oder aktualisieren, dann sämtliche
Beziehungen knüpfen. Das macht den Import reihenfolgeunabhängig und wiederholbar (`.zusammenfuehren`
ist idempotent).

Verschlüsselung ist optional: AES-GCM, Schlüssel aus PBKDF2-SHA256. Zähler und Exportdatum bleiben
im Klartext, damit die Vorschau vor der Passworteingabe etwas zeigen kann.

Wird das Schema geändert, muss `BackupDatei.aktuelleSchemaVersion` mitziehen; der Import weist
neuere Formate ab. **Neue Listen in `BackupDaten` müssen optional sein** (`[...]?` mit `?? []` an
der Auswertungsstelle): Die synthetisierte `Decodable` greift bei fehlenden Schlüsseln nicht auf
Standardwerte zurück, ältere Sicherungen wären sonst nicht mehr lesbar.

### Mitgelieferte Kompetenzraster

Zweistufig und bewusst getrennt:

1. `Tools/RasterExtractor` (SPM-Werkzeug, **läuft nicht in der App**) legt den Text der drei
   RLP-Teilrahmenpläne offen — PDFKit für Deutsch und Mathematik, Vision-OCR für den gescannten
   Sachunterricht.
2. Daraus werden `Kompetenzraster/Resources/Vorlagen/*.json` **von Hand** gepflegt.

Die App liest nur dieses JSON. Die Quell-PDFs sind nicht im Repository (siehe
`Tools/RasterExtractor/Quellen/README.md`). `VorlagenTests` prüft die Knotenzahlen fest
(22/60/33) — ändert sich eine Vorlage, müssen diese Zahlen mit.

Ein eingefügtes Raster ist eine **Kopie**; wächst die Vorlage später, erfährt es davon nichts.
`Vorlagenabgleich` zieht das nach (Knopf „Mit Vorlage abgleichen“ im Raster-Editor): je
Geschwistergruppe erst über `code`, dann über den Titel zuordnen, Fehlendes ergänzen, Texte
nachziehen. **Gelöscht wird nie** — an jeder Kompetenz können Bewertungen hängen. Bekommt eine
bewertete Kompetenz dabei Unterkompetenzen, fällt ihre Bewertung aus der Auswertung; der Bericht
weist das vorher aus.

### Aktualisierung

`Aktualisierungspruefer` lädt `latest.json` als **Release-Anhang** (nicht über `api.github.com`,
das hat ein Zugriffslimit) und vergleicht die **Build-Nummer**, nicht die Versionszeichenkette —
die Build-Nummer kommt aus `github.run_number` und wächst verlässlich.

Zwei Zustände steuern den Streifen über dem Fenster: `zeigtHinweis` (neue Fassung) und
`zeigtRueckmeldung` (Rückmeldung auf eine **von Hand** angestoßene Suche). Die stille Prüfung beim
Start meldet nichts, wenn alles aktuell ist.

`Selbstaktualisierung` ersetzt die App. Vor dem Austausch wird jedes Mal geprüft: HTTPS →
SHA-256 aus dem Manifest → gleiche Programmkennung → tatsächlich neuere Fassung → intakte Signatur.
Keine dieser Prüfungen ist verzichtbar.

**Die App läuft ohne App Sandbox, und das muss so bleiben, solange sie nicht notarisiert ist.**
Eine sandboxed App darf ihr Bundle zwar ersetzen, aber das dabei gesetzte Quarantäne-Merkmal nicht
entfernen (`removexattr` scheitert mit `EPERM`); Gatekeeper verweigert der ad-hoc signierten Kopie
danach den Start. Der Grund steht ausführlich in `Kompetenzraster.entitlements` und im README.

`Datenumzug` holt den Bestand einmalig aus dem alten Sandbox-Container und lässt das Original
liegen. Läuft beim Öffnen des Containers in `Datenbestand.container(imArbeitsspeicher:)`.

### Testbarkeit

Was Netz, Dateidialoge oder Prozesse anfasst, ist über den Initialisierer austauschbar:
`Aktualisierungspruefer(laden:)`, `Selbstaktualisierung(lader:ordnerzugriff:)`,
`Datenumzug.ausAlterSandbox(neuerOrdner:alterOrdner:)`. Ohne das liefe ein Test in einen
NSOpenPanel. Tests nutzen `Datenbestand.container(imArbeitsspeicher: true)`.

## Veröffentlichen

Jeder Push auf `main` baut über `.github/workflows/release.yml`, lässt die Tests laufen und
aktualisiert das rollierende Release `latest` mit `Kompetenzraster.zip` und `latest.json`.
Die Versionsnummer steht als `MARKETING_VERSION` in `project.yml`, die Build-Nummer kommt aus dem
Arbeitslauf. Signiert wird nur ad-hoc.

## Import aus anderen Werkzeugen

Auf diesem Rechner liegen eine OpenAI-Codex- und eine Gemini-CLI-Konfiguration. Antworte `/import`,
wenn ich auflisten soll, was daraus übernehmbar wäre (MCP-Server, Slash-Befehle, Subagents, Skills,
Anweisungen); mit `/import --yes=<digest>` wird es dann angewendet.
