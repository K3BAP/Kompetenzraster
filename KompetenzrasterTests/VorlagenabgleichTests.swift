import Foundation
import SwiftData
import Testing
@testable import Kompetenzraster

/// Der Abgleich eines vorhandenen Rasters mit einer neueren Vorlage.
@MainActor
@Suite("Raster an die Vorlage angleichen")
struct VorlagenabgleichTests {
    private func kontext() throws -> ModelContext {
        ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
    }

    private func skala(in kontext: ModelContext) -> Bewertungsskala {
        let skala = Bewertungsskala.standard()
        kontext.insert(skala)
        for stufe in skala.stufen { kontext.insert(stufe) }
        return skala
    }

    private func vorlage(_ json: String) throws -> VorlagenDatei {
        try JSONDecoder().decode(VorlagenDatei.self, from: Data(json.utf8))
    }

    /// Eine kleine Vorlage, damit die Erwartungen im Test nachlesbar bleiben.
    private func kleineVorlage(mitZweiterKompetenz: Bool) throws -> VorlagenDatei {
        let zweite = mitZweiterKompetenz
            ? """
            , { "titel": "Zuhören", "code": "S2", "kinder": [ { "titel": "Nachfragen" } ] }
            """
            : ""
        return try vorlage("""
        { "schemaVersion": 1, "name": "Probe", "fach": "Probe", "quelle": "Quelle",
          "kompetenzen": [
            { "titel": "Sprechen", "code": "S", "kinder": [
              { "titel": "Gespräche führen", "code": "S1" }\(zweite)
            ] }
          ] }
        """)
    }

    @Test("Ein frisch eingefügtes Raster meldet keine Änderungen")
    func frischesRasterIstDeckungsgleich() throws {
        let kontext = try kontext()
        let skala = skala(in: kontext)
        for fach in VorlagenLader.verfuegbareFaecher {
            let datei = try VorlagenLader.datei(fach: fach)
            let raster = VorlagenLader.einfuegen(datei, in: kontext, skala: skala)
            let bericht = Vorlagenabgleich.bericht(fuer: raster, vorlage: datei)
            #expect(bericht.istLeer, "\(fach) weicht ab: \(bericht.neue.count) neu, \(bericht.geaenderte.count) geändert")
        }
    }

    @Test("Fehlende Kompetenzen werden ergänzt, Bewertungen und Eigenes bleiben")
    func ergaenztUndBewahrt() throws {
        let kontext = try kontext()
        let skala = skala(in: kontext)
        let raster = VorlagenLader.einfuegen(
            try kleineVorlage(mitZweiterKompetenz: false), in: kontext, skala: skala
        )

        // Eine eigene Ergänzung und eine Bewertung, die den Abgleich überleben müssen.
        let bereich = try #require(raster.wurzeln.first)
        let eigene = Kompetenz(titel: "Freies Erzählen", sortIndex: 9)
        kontext.insert(eigene)
        eigene.raster = raster
        eigene.eltern = bereich

        let kind = SchuelerIn(vorname: "Anna", nachname: "Berger")
        kontext.insert(kind)
        let bewertet = try #require(raster.blattKompetenzen.first { $0.code == "S1" })
        Erfassung.setze(skala.stufenSortiert.last, fuer: bewertet, schueler: kind, in: kontext)

        let neuere = try kleineVorlage(mitZweiterKompetenz: true)
        let vorschau = Vorlagenabgleich.bericht(fuer: raster, vorlage: neuere)
        #expect(vorschau.neue.map(\.titel) == ["Zuhören", "Nachfragen"], "Der Teilbaum zählt mit")
        #expect(vorschau.eigene.map(\.titel) == ["Freies Erzählen"])
        #expect(vorschau.geaenderte.isEmpty)

        let bericht = Vorlagenabgleich.wendeAn(neuere, auf: raster, in: kontext)
        #expect(bericht.neue.count == 2)
        #expect(raster.kompetenzen.count == 5)
        #expect(bereich.kinderSortiert.map(\.titel) == ["Gespräche führen", "Zuhören", "Freies Erzählen"],
                "Eigenes rutscht hinter die Vorlage, wird aber nicht gelöscht")
        #expect(Auswertung.eintrag(fuer: bewertet, schueler: kind)?.stufe?.name == "sicher")
    }

    @Test("Ein zweiter Abgleich ändert nichts mehr")
    func idempotent() throws {
        let kontext = try kontext()
        let skala = skala(in: kontext)
        let raster = VorlagenLader.einfuegen(
            try kleineVorlage(mitZweiterKompetenz: false), in: kontext, skala: skala
        )
        let neuere = try kleineVorlage(mitZweiterKompetenz: true)

        Vorlagenabgleich.wendeAn(neuere, auf: raster, in: kontext)
        let anzahl = raster.kompetenzen.count
        let zweiter = Vorlagenabgleich.wendeAn(neuere, auf: raster, in: kontext)

        #expect(zweiter.istLeer)
        #expect(raster.kompetenzen.count == anzahl, "Kein Doppel beim zweiten Durchgang")
    }

    @Test("Eine umbenannte Kompetenz wird über die Gliederungsnummer wiedererkannt")
    func umbenanntesWirdNichtVerdoppelt() throws {
        let kontext = try kontext()
        let skala = skala(in: kontext)
        let raster = VorlagenLader.einfuegen(
            try kleineVorlage(mitZweiterKompetenz: false), in: kontext, skala: skala
        )
        let blatt = try #require(raster.blattKompetenzen.first { $0.code == "S1" })
        blatt.titel = "Gespräche führen (eigene Fassung)"

        let bericht = Vorlagenabgleich.bericht(fuer: raster, vorlage: try kleineVorlage(mitZweiterKompetenz: false))
        #expect(bericht.neue.isEmpty)
        #expect(bericht.geaenderte.map(\.felder) == [["Titel"]])

        Vorlagenabgleich.wendeAn(try kleineVorlage(mitZweiterKompetenz: false), auf: raster, in: kontext)
        #expect(blatt.titel == "Gespräche führen")
    }

    @Test("Bewertungen an Kompetenzen, die Kinder bekommen, werden gemeldet und bleiben liegen")
    func verdeckteBewertungen() throws {
        let kontext = try kontext()
        let skala = skala(in: kontext)
        let raster = VorlagenLader.einfuegen(
            try kleineVorlage(mitZweiterKompetenz: false), in: kontext, skala: skala
        )
        // „Zuhören“ von Hand angelegt – die neuere Vorlage hängt „Nachfragen“ darunter.
        let bereich = try #require(raster.wurzeln.first)
        let zuhoeren = Kompetenz(titel: "Zuhören", sortIndex: 1)
        kontext.insert(zuhoeren)
        zuhoeren.raster = raster
        zuhoeren.eltern = bereich

        let kind = SchuelerIn(vorname: "Ben", nachname: "Cordes")
        kontext.insert(kind)
        Erfassung.setze(skala.stufenSortiert[1], fuer: zuhoeren, schueler: kind, in: kontext)

        let bericht = Vorlagenabgleich.wendeAn(
            try kleineVorlage(mitZweiterKompetenz: true), auf: raster, in: kontext
        )
        #expect(bericht.verdeckteBewertungen == 1)
        #expect(zuhoeren.code == "S2", "Der Knoten wurde erkannt, nicht neu angelegt")
        #expect(zuhoeren.kinderSortiert.map(\.titel) == ["Nachfragen"])
        #expect(Auswertung.eintrag(fuer: zuhoeren, schueler: kind) != nil, "Die Bewertung bleibt gespeichert")
    }

    @Test("Ein Mathematikraster ohne die prozessbezogenen Erwartungen wird vollständig")
    func mathematikWirdNachgezogen() throws {
        let kontext = try kontext()
        let skala = skala(in: kontext)
        let datei = try VorlagenLader.datei(fach: "Mathematik")
        let raster = VorlagenLader.einfuegen(datei, in: kontext, skala: skala)

        // Der Stand vor der Ergänzung: die fünf prozessbezogenen Kompetenzen als bloße Überschriften.
        let prozess = try #require(raster.wurzeln.first { $0.code == "2.2" })
        for oberkompetenz in prozess.kinderSortiert {
            for blatt in oberkompetenz.kinderSortiert { kontext.delete(blatt) }
        }
        try kontext.save()
        #expect(raster.blattKompetenzen.count == 32)

        let bericht = Vorlagenabgleich.wendeAn(datei, auf: raster, in: kontext)
        #expect(bericht.neue.count == 16)
        #expect(raster.kompetenzen.count == 60)
        #expect(raster.blattKompetenzen.count == 43)
        #expect(prozess.blaetterImTeilbaum.map(\.code).prefix(3) == ["D1", "D2", "D3"])
    }
}
