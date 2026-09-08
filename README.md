# Kompetenzraster

Kompetenzorientierte Lernfortschrittsdokumentation als native macOS-App — lokal auf dem eigenen
Mac, ohne Cloud und ohne Konto.

Nachbau des Kerns von [Digidoo](https://www.digidoo.com/de/): Kompetenzraster, Einträge je
Schüler:in × Kompetenz und die Kompetenzblume als Bild des Entwicklungsstands.

## Herunterladen

Fertige Fassung unter **[Releases → Latest build](https://github.com/K3BAP/Kompetenzraster/releases/tag/latest)**:
`Kompetenzraster.zip` laden, entpacken, nach „Programme“ ziehen.

Die App ist nur ad-hoc signiert, nicht notarisiert. Beim ersten Start deshalb mit der rechten
Maustaste darauf klicken und **Öffnen** wählen. Alternativ:

```bash
xattr -dr com.apple.quarantine /Applications/Kompetenzraster.app
```

## Selbst bauen

```bash
make run
```

Weitere Ziele: `make build`, `make test`, `make release` (baut `dist/Kompetenzraster.zip`),
`make install` (nach `/Applications`), `make icon`, `make clean`.

Das Xcode-Projekt wird aus `project.yml` erzeugt und liegt deshalb nicht im Repository:

```bash
xcodegen generate && open Kompetenzraster.xcodeproj
```

Voraussetzungen: macOS 15 oder neuer, Xcode 16 oder neuer,
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

## Was die App kann

- **Klassen und Schüler:innen** verwalten; Klassenlisten aus einer Tabelle einfügen
  (Semikolon, Komma, Tabulator oder Leerzeichen als Trenner, Kopfzeile wird erkannt).
- **Kompetenzraster** als Baum beliebiger Tiefe: Kompetenzbereich → Oberkompetenz →
  Unterkompetenz. Anlegen, umbenennen, verschieben, duplizieren.
- **Erfassung** als Gitter Schüler:innen × Kompetenzen. Ein Stift wird gewählt, danach genügt
  ein Klick je Bewertung; per Rechtsklick gibt es einzelne Stufen, Notizen und das Entfernen.
- **Kompetenzblume** mit Drill-down: je Kind des aktuellen Knotens ein Blütenblatt, dessen Länge
  dem Mittelwert der Einträge darunter entspricht. Ein Klick zoomt eine Ebene tiefer.
  Unbewertetes erscheint als gestrichelter Umriss und zieht den Mittelwert nicht nach unten.
- **Bewertungsskalen** frei konfigurierbar: Stufenanzahl, Namen, Farben und Symbole.
  Standard sind vier Wachstumsstufen, gezeichnet als Samenkorn → Keimling → Pflanze → Blüte.
  Wird eine Stufe entfernt, rücken vorhandene Bewertungen auf die nächstgelegene Stufe.
- **Sicherung** als einzelne, lesbare JSON-Datei (`.kompetenzsicherung`), optional mit Passwort
  verschlüsselt (AES-GCM, Schlüssel aus PBKDF2-SHA256). Einspielen wahlweise ersetzend oder
  zusammenführend; das Zusammenführen ist idempotent.
- **Ersteinrichtung** mit drei Wegen: Sicherung einspielen, mit fertigen Rastern starten oder
  leer beginnen.
- **App-Sperre** über Touch ID beziehungsweise Anmeldepasswort (optional).
- **Selbst-Aktualisierung**: Ein Klick lädt die neue Fassung, prüft sie, ersetzt die App
  und startet sie neu.

## Mitgelieferte Kompetenzraster

Grundlage sind die Teilrahmenpläne der Grundschule in Rheinland-Pfalz
(Ministerium für Bildung), gegliedert bis zur Ebene der Oberkompetenzen:

| Fach | Aufbau | Knoten |
|---|---|---|
| Deutsch | 4 Kompetenzbereiche → 18 Oberkompetenzen | 22 |
| Mathematik | 5 Bereiche → Unterbereiche → Oberkompetenzen | 44 |
| Sachunterricht | 5 Erfahrungsbereiche → 28 Oberkompetenzen | 33 |

Die feingliedrigen Kompetenzerwartungen der Teilrahmenpläne sind bewusst nicht enthalten.
Das Datenmodell trägt beliebige Tiefe, eigene Unterkompetenzen lassen sich also jederzeit
darunter ergänzen.

## Aktualisierung

Höchstens einmal täglich lädt die App `latest.json` vom GitHub-Release und vergleicht die
Build-Nummer. Gibt es etwas Neueres, erscheint ein Streifen über dem Fenster; ein Klick auf
**Aktualisieren** erledigt den Rest.

Vor dem Austausch wird jedes Mal geprüft:

1. Geladen wird nur über HTTPS.
2. Die **SHA-256-Prüfsumme** muss der entsprechen, die in `latest.json` steht.
3. Das Paket muss dieselbe **Programmkennung** tragen wie die laufende App.
4. Die enthaltene Fassung muss tatsächlich **neuer** sein — keine Rückstufung.
5. Die **Signatur** des Pakets muss in sich stimmig sein.

Erst danach wird die App ersetzt und neu gestartet. Klappt der Neustart nicht, meldet die App
das und die neue Fassung läuft ab dem nächsten Start.

Abschaltbar unter **Einstellungen → Sicherheit**. Ist die Prüfung aus, macht die App überhaupt
keinen Netzwerkzugriff mehr.

## Datenschutz

Schülerdaten verlassen den Mac nicht. Datenbank und Einstellungen liegen unter
`~/Library/Application Support/Kompetenzraster.store`. Beim Abruf der Versionsdatei wird nichts
gesendet — keine Klassen, keine Namen, keine Einträge, keine Kennung.

Für Sicherungen, die weitergegeben oder auf einem Stick mitgenommen werden, gibt es die
Passwortverschlüsselung.

### Warum ohne App Sandbox

Bis Version 1.0 lief die App in einer Sandbox. Das ließ sich mit der Selbst-Aktualisierung
nicht vereinbaren: Eine sandboxed App darf zwar mit einer Ordnerfreigabe ihr eigenes Bundle
ersetzen — das funktioniert —, aber das Quarantäne-Merkmal, das die Sandbox dabei setzt, nicht
wieder entfernen; `removexattr` scheitert mit `EPERM`. Gatekeeper verweigert der nur ad-hoc
signierten Kopie danach den Start, die App hätte sich also selbst unbrauchbar gemacht.

Der Hardened Runtime bleibt aktiv. Wer die Sandbox zurückhaben will, braucht ein
Apple-Entwicklerkonto: mit Developer-ID-Signatur und Notarisierung stört die Quarantäne nicht
mehr, und `com.apple.security.app-sandbox` kann in
[`Kompetenzraster.entitlements`](Kompetenzraster/Resources/Kompetenzraster.entitlements)
wieder auf `true`.

Beim ersten Start ohne Sandbox holt sich die App den Datenbestand einmalig aus dem alten
Container (`~/Library/Containers/com.kompetenzraster.app/`) — siehe
[`Datenumzug.swift`](Kompetenzraster/Modelle/Datenumzug.swift). Das Original bleibt liegen.

## Aufbau

```
Kompetenzraster/
  App/          Einstiegspunkt, App-Sperre, Ersteinrichtung
  Modelle/      SwiftData-Modelle und Container
  Ansichten/    Oberfläche, nach Bereichen sortiert
  Dienste/      Sicherung, Vorlagen, Erfassung, Auswertung, CSV, Aktualisierung
  Symbole/      Gezeichnete Pflanzenstufen und Symboldarstellung
  Resources/    Vorlagen-JSON, Info.plist, Entitlements, App-Symbol
scripts/                 Symbol- und Manifest-Erzeugung
Tools/RasterExtractor/   Entwicklungswerkzeug für die Vorlagen
```

### Datenmodell

`Klasse` ─< `SchuelerIn` ─< `Eintrag` >─ `Kompetenz` (selbstreferenzieller Baum) und
`Eintrag` >─ `Bewertungsstufe` ─< `Bewertungsskala`. Ein `Kompetenzraster` hält seine
Kompetenzen flach; der Baum ergibt sich aus `Kompetenz.eltern`. Je Paar aus Schüler:in und
Kompetenz gibt es genau einen Eintrag.

## Veröffentlichen

Jeder Push auf `main` baut über
[`.github/workflows/release.yml`](.github/workflows/release.yml), lässt die Tests laufen und
aktualisiert das rollierende Release `latest` mit `Kompetenzraster.zip` und `latest.json`.
Die Build-Nummer ist die Nummer des Arbeitslaufs; genau sie vergleicht die App bei der
Update-Suche. Die Versionsnummer selbst steht als `MARKETING_VERSION` in `project.yml`.

## Vorlagen erneuern

`Tools/RasterExtractor` legt den Text der drei Teilrahmenpläne offen, damit die Vorlagen daraus
kuratiert werden können. Die PDFs sind nicht Teil des Repositories —
siehe [`Tools/RasterExtractor/Quellen/README.md`](Tools/RasterExtractor/Quellen/README.md).

```bash
cd Tools/RasterExtractor && swift run RasterExtractor
```

Das Ergebnis landet in `Tools/RasterExtractor/Ausgabe/`. Daraus werden die Dateien in
`Kompetenzraster/Resources/Vorlagen/` von Hand gepflegt — die App liest ausschließlich dieses
JSON, es wird zur Laufzeit kein PDF gelesen und keines mitgeliefert.

## Noch nicht enthalten

Leistungsfeststellungen und Notenvorschläge (die deutsche Skala 1–6 steht bereits als
`Note` bereit), Berichte mit PDF-Export, Förderplanung, Klassen-Heatmap und ein
Entwicklungsverlauf mit mehreren datierten Einträgen je Kompetenz.
