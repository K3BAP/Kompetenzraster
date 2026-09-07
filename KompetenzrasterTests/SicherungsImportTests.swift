import Foundation
import SwiftData
import Testing
@testable import Kompetenzraster

/// Deckt den Weg ab, den die Oberfläche geht: Datei von der Platte lesen, Vorschau zeigen,
/// Passwort prüfen, einspielen.
@MainActor
struct SicherungsImportTests {
    private func bestandMitEinemKind() throws -> ModelContext {
        let kontext = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        let skala = Bewertungsskala.standard()
        kontext.insert(skala)
        for stufe in skala.stufen { kontext.insert(stufe) }

        let raster = VorlagenLader.einfuegen(
            try VorlagenLader.datei(fach: "Deutsch"), in: kontext, skala: skala
        )
        let klasse = Klasse(name: "3a", jahrgangsstufe: 3)
        kontext.insert(klasse)
        klasse.raster = [raster]

        let kind = SchuelerIn(vorname: "Anna", nachname: "Berger")
        kontext.insert(kind)
        kind.klasse = klasse

        let blatt = try #require(raster.blattKompetenzen.first)
        Erfassung.setze(skala.stufenSortiert.last, fuer: blatt, schueler: kind, in: kontext)
        try kontext.save()
        return kontext
    }

    private func schreibeTempdatei(_ daten: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "test-\(UUID().uuidString).\(BackupService.dateiendung)")
        try daten.write(to: url)
        return url
    }

    @Test("Eine Datei von der Platte wird gelesen und eingespielt")
    func ladenUndEinspielen() throws {
        let url = try schreibeTempdatei(try BackupService.export(aus: try bestandMitEinemKind()))
        defer { try? FileManager.default.removeItem(at: url) }

        let importeur = SicherungsImport()
        importeur.lade(von: url)

        #expect(importeur.fehler == nil)
        #expect(importeur.brauchtPasswort == false)
        #expect(importeur.bereit)
        #expect(importeur.vorschau?.zaehler.schueler == 1)
        #expect(importeur.vorschau?.zaehler.kompetenzen == 22)
        #expect(importeur.vorschau?.zaehler.eintraege == 1)

        let ziel = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        #expect(importeur.fuehreAus(modus: .ersetzen, in: ziel))
        #expect(try ziel.fetch(FetchDescriptor<SchuelerIn>()).first?.klasse?.name == "3a")
        #expect(try ziel.fetchCount(FetchDescriptor<Eintrag>()) == 1)
    }

    @Test("Bei einer verschlüsselten Datei wird erst das Passwort verlangt")
    func passwortWirdVerlangt() throws {
        let daten = try BackupService.export(aus: try bestandMitEinemKind(), passwort: "geheim")
        let url = try schreibeTempdatei(daten)
        defer { try? FileManager.default.removeItem(at: url) }

        let importeur = SicherungsImport()
        importeur.lade(von: url)

        #expect(importeur.brauchtPasswort)
        #expect(!importeur.bereit, "Ohne Passwort darf der Knopf nicht freigegeben werden")
        // Die Vorschau muss trotzdem etwas zeigen können.
        #expect(importeur.vorschau?.zaehler.klassen == 1)

        let ziel = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        importeur.passwort = "falsch"
        #expect(importeur.fuehreAus(modus: .ersetzen, in: ziel) == false)
        #expect(importeur.fehler != nil)

        importeur.passwort = "geheim"
        #expect(importeur.fuehreAus(modus: .ersetzen, in: ziel))
        #expect(importeur.fehler == nil)
        #expect(try ziel.fetch(FetchDescriptor<SchuelerIn>()).first?.vorname == "Anna")
    }

    @Test("Eine Datei, die keine Sicherung ist, wird als Fehler gemeldet")
    func fremdeDatei() throws {
        let url = try schreibeTempdatei(Data("{\"irgendwas\": true}".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        let importeur = SicherungsImport()
        importeur.lade(von: url)
        #expect(importeur.rohdaten == nil)
        #expect(importeur.fehler != nil)
        #expect(importeur.bereit == false)
    }
}

/// Die Erfassung selbst: genau ein Eintrag je Paar, Notizen, Entfernen.
@MainActor
struct ErfassungTests {
    private func aufbau() throws -> (ModelContext, Kompetenz, SchuelerIn, Bewertungsskala) {
        let kontext = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        let skala = Bewertungsskala.standard()
        kontext.insert(skala)
        for stufe in skala.stufen { kontext.insert(stufe) }

        let kompetenz = Kompetenz(titel: "Gespräche führen")
        kontext.insert(kompetenz)
        let kind = SchuelerIn(vorname: "Ben", nachname: "Cordes")
        kontext.insert(kind)
        try kontext.save()
        return (kontext, kompetenz, kind, skala)
    }

    @Test("Erneutes Bewerten legt keinen zweiten Eintrag an")
    func genauEinEintrag() throws {
        let (kontext, kompetenz, kind, skala) = try aufbau()
        Erfassung.setze(skala.stufenSortiert[1], fuer: kompetenz, schueler: kind, in: kontext)
        Erfassung.setze(skala.stufenSortiert[3], fuer: kompetenz, schueler: kind, in: kontext)

        #expect(try kontext.fetchCount(FetchDescriptor<Eintrag>()) == 1)
        #expect(Auswertung.eintrag(fuer: kompetenz, schueler: kind)?.stufe?.name == "sicher")
    }

    @Test("Notizen bleiben beim Ändern der Stufe erhalten")
    func notizUeberlebtStufenwechsel() throws {
        let (kontext, kompetenz, kind, skala) = try aufbau()
        Erfassung.setze(skala.stufenSortiert[1], fuer: kompetenz, schueler: kind, in: kontext)
        Erfassung.setzeNotiz("hört gut zu", fuer: kompetenz, schueler: kind, in: kontext)
        Erfassung.setze(skala.stufenSortiert[2], fuer: kompetenz, schueler: kind, in: kontext)

        let eintrag = try #require(Auswertung.eintrag(fuer: kompetenz, schueler: kind))
        #expect(eintrag.notiz == "hört gut zu")
        #expect(eintrag.stufe?.name == "überwiegend")
    }

    @Test("Der Radierer entfernt den Eintrag vollständig")
    func entfernen() throws {
        let (kontext, kompetenz, kind, skala) = try aufbau()
        Erfassung.setze(skala.stufenSortiert[2], fuer: kompetenz, schueler: kind, in: kontext)
        Erfassung.setze(nil, fuer: kompetenz, schueler: kind, in: kontext)

        #expect(try kontext.fetchCount(FetchDescriptor<Eintrag>()) == 0)
        #expect(Auswertung.eintrag(fuer: kompetenz, schueler: kind) == nil)
    }

    @Test("Eine entfernte Stufe hängt ihre Einträge an die Nachbarstufe um")
    func stufeEntfernenHaengtEintraegeUm() throws {
        let (kontext, kompetenz, kind, skala) = try aufbau()
        let hoechste = try #require(skala.stufenSortiert.last)
        Erfassung.setze(hoechste, fuer: kompetenz, schueler: kind, in: kontext)

        Skalenverwaltung.entferne(hoechste, in: kontext)

        #expect(skala.stufen.count == 3)
        #expect(skala.stufenSortiert.map(\.wert) == [0, 1, 2], "Die Werte müssen lückenlos bleiben")
        let eintrag = try #require(Auswertung.eintrag(fuer: kompetenz, schueler: kind))
        #expect(eintrag.stufe?.name == "überwiegend", "Die Bewertung darf nicht verloren gehen")
    }
}

@Suite("Klassenlisten einlesen")
struct CSVImportTests {
    @Test("Semikolon, Komma, Tabulator und Leerzeichen werden erkannt")
    func trennzeichen() {
        let zeilen = CSVSchuelerImport.lese("""
        Anna;Berger
        Ben,Cordes
        Clara\tDahl
        David Engel
        """)
        #expect(zeilen.map(\.vorname) == ["Anna", "Ben", "Clara", "David"])
        #expect(zeilen.map(\.nachname) == ["Berger", "Cordes", "Dahl", "Engel"])
    }

    @Test("Kopfzeilen und Leerzeilen werden übersprungen")
    func kopfzeile() {
        let zeilen = CSVSchuelerImport.lese("""
        Vorname;Nachname

        Anna;Berger

        """)
        #expect(zeilen.count == 1)
        #expect(zeilen.first?.vorname == "Anna")
    }

    @Test("Mehrteilige Vornamen bleiben zusammen")
    func mehrteiligerName() {
        let zeilen = CSVSchuelerImport.lese("Anna Lena Berger")
        #expect(zeilen.first?.vorname == "Anna Lena")
        #expect(zeilen.first?.nachname == "Berger")
    }

    @Test("Kürzel werden aus dem Namen abgeleitet")
    func kuerzel() {
        #expect(SchuelerIn.kuerzelVorschlag(vorname: "Anna", nachname: "Berger") == "AB")
        #expect(SchuelerIn(vorname: "Ben", nachname: "Cordes").kuerzel == "BC")
        #expect(SchuelerIn(vorname: "Ben", nachname: "Cordes").anzeigename == "Ben C.")
    }
}
