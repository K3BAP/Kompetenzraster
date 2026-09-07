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

## Datenschutz

Die App ist sandboxed. Datenbank und Einstellungen liegen unter
`~/Library/Containers/com.kompetenzraster.app/`. Schülerdaten verlassen den Mac nicht.

Der **einzige** Netzwerkzugriff ist die Suche nach Aktualisierungen: höchstens einmal täglich
wird `latest.json` vom GitHub-Release geladen und die Build-Nummer verglichen. Dabei wird nichts
gesendet — keine Klassen, keine Namen, keine Einträge, keine Kennung. Findet sich etwas Neueres,
erscheint ein Hinweis mit einem Knopf, der die Release-Seite im Browser öffnet; heruntergeladen
und installiert wird nichts von selbst. Abschaltbar unter **Einstellungen → Sicherheit**; danach
macht die App überhaupt keinen Netzwerkzugriff mehr.

Für Sicherungen, die weitergegeben oder auf einem Stick mitgenommen werden, gibt es die
Passwortverschlüsselung.

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
