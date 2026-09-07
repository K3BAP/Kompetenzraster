import Foundation
import SwiftData
import Testing
@testable import Kompetenzraster

@MainActor
struct BackupTests {
    /// Baut einen kleinen, aber vollständig verknüpften Bestand auf.
    private func beispielbestand() throws -> ModelContext {
        let container = try Datenbestand.container(imArbeitsspeicher: true)
        let kontext = ModelContext(container)

        let skala = Bewertungsskala.standard()
        kontext.insert(skala)
        for stufe in skala.stufen { kontext.insert(stufe) }

        let raster = Kompetenzraster(name: "Deutsch", fach: "Deutsch", quelle: "Test")
        raster.skala = skala
        kontext.insert(raster)

        let bereich = Kompetenz(titel: "Sprechen und Zuhören", sortIndex: 0)
        kontext.insert(bereich)
        bereich.raster = raster

        var blaetter: [Kompetenz] = []
        for (index, titel) in ["Gespräche führen", "verstehend zuhören"].enumerated() {
            let blatt = Kompetenz(titel: titel, sortIndex: index)
            kontext.insert(blatt)
            blatt.raster = raster
            blatt.eltern = bereich
            blaetter.append(blatt)
        }

        let klasse = Klasse(name: "3a", jahrgangsstufe: 3, schuljahr: "2025/26")
        kontext.insert(klasse)
        klasse.raster = [raster]

        let anna = SchuelerIn(vorname: "Anna", nachname: "Muster")
        kontext.insert(anna)
        anna.klasse = klasse

        let eintrag = Eintrag(notiz: "sehr aufmerksam")
        kontext.insert(eintrag)
        eintrag.schueler = anna
        eintrag.kompetenz = blaetter[0]
        eintrag.stufe = skala.stufenSortiert.last

        try kontext.save()
        return kontext
    }

    private func zaehle(_ kontext: ModelContext) throws -> [String: Int] {
        [
            "klassen": try kontext.fetchCount(FetchDescriptor<Klasse>()),
            "schueler": try kontext.fetchCount(FetchDescriptor<SchuelerIn>()),
            "raster": try kontext.fetchCount(FetchDescriptor<Kompetenzraster>()),
            "kompetenzen": try kontext.fetchCount(FetchDescriptor<Kompetenz>()),
            "skalen": try kontext.fetchCount(FetchDescriptor<Bewertungsskala>()),
            "stufen": try kontext.fetchCount(FetchDescriptor<Bewertungsstufe>()),
            "eintraege": try kontext.fetchCount(FetchDescriptor<Eintrag>()),
        ]
    }

    @Test("Sicherung und Wiederherstellung ergeben denselben Bestand")
    func roundtrip() throws {
        let quelle = try beispielbestand()
        let erwartet = try zaehle(quelle)
        let rohdaten = try BackupService.export(aus: quelle)

        let ziel = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        try BackupService.importiere(rohdaten, modus: .ersetzen, in: ziel)

        #expect(try zaehle(ziel) == erwartet)

        // Stichprobe: Beziehungen müssen den Weg durch die Datei überstanden haben.
        let anna = try #require(try ziel.fetch(FetchDescriptor<SchuelerIn>()).first)
        #expect(anna.vorname == "Anna")
        #expect(anna.klasse?.name == "3a")
        #expect(anna.eintraege.count == 1)

        let eintrag = try #require(anna.eintraege.first)
        #expect(eintrag.kompetenz?.titel == "Gespräche führen")
        #expect(eintrag.kompetenz?.eltern?.titel == "Sprechen und Zuhören")
        #expect(eintrag.stufe?.name == "sicher")
        #expect(eintrag.notiz == "sehr aufmerksam")

        let klasse = try #require(try ziel.fetch(FetchDescriptor<Klasse>()).first)
        #expect(klasse.raster.first?.fach == "Deutsch")
        #expect(klasse.raster.first?.skala?.stufen.count == 4)
    }

    @Test("Die Sicherung ist lesbares JSON mit Zählern im Klartext")
    func lesbaresFormat() throws {
        let rohdaten = try BackupService.export(aus: try beispielbestand())
        let text = try #require(String(data: rohdaten, encoding: .utf8))
        #expect(text.contains("\"schemaVersion\""))
        #expect(text.contains("Anna"))

        let vorschau = try BackupService.vorschau(rohdaten)
        #expect(vorschau.verschluesselt == false)
        #expect(vorschau.zaehler.schueler == 1)
        #expect(vorschau.zaehler.kompetenzen == 3)
    }

    @Test("Verschlüsselte Sicherung lässt sich mit dem Passwort wieder einlesen")
    func verschluesselterRoundtrip() throws {
        let rohdaten = try BackupService.export(aus: try beispielbestand(), passwort: "Geheim!123")

        // Ohne Passwort dürfen keine Schülerdaten in der Datei stehen.
        let text = try #require(String(data: rohdaten, encoding: .utf8))
        #expect(!text.contains("Anna"))

        let vorschau = try BackupService.vorschau(rohdaten)
        #expect(vorschau.verschluesselt)
        #expect(vorschau.zaehler.schueler == 1, "Die Vorschau muss auch verschlüsselt lesbar bleiben")

        let ziel = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        try BackupService.importiere(rohdaten, modus: .ersetzen, passwort: "Geheim!123", in: ziel)
        #expect(try ziel.fetch(FetchDescriptor<SchuelerIn>()).first?.vorname == "Anna")
    }

    @Test("Falsches oder fehlendes Passwort schlägt sauber fehl")
    func falschesPasswort() throws {
        let rohdaten = try BackupService.export(aus: try beispielbestand(), passwort: "richtig")
        let ziel = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))

        #expect(throws: BackupService.Fehler.passwortFalsch) {
            try BackupService.importiere(rohdaten, modus: .ersetzen, passwort: "falsch", in: ziel)
        }
        #expect(throws: BackupService.Fehler.passwortFehlt) {
            try BackupService.importiere(rohdaten, modus: .ersetzen, in: ziel)
        }
        #expect(try ziel.fetchCount(FetchDescriptor<SchuelerIn>()) == 0)
    }

    @Test("Zweimal zusammenführen erzeugt keine Duplikate")
    func zusammenfuehrenIstIdempotent() throws {
        let quelle = try beispielbestand()
        let erwartet = try zaehle(quelle)
        let rohdaten = try BackupService.export(aus: quelle)

        let ziel = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        try BackupService.importiere(rohdaten, modus: .zusammenfuehren, in: ziel)
        try BackupService.importiere(rohdaten, modus: .zusammenfuehren, in: ziel)

        #expect(try zaehle(ziel) == erwartet)
        #expect(try ziel.fetch(FetchDescriptor<SchuelerIn>()).first?.eintraege.count == 1)
    }

    @Test("Beschädigte Dateien werden abgewiesen")
    func beschaedigteDatei() throws {
        let ziel = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        #expect(throws: BackupService.Fehler.beschaedigt) {
            try BackupService.importiere(Data("kein JSON".utf8), modus: .ersetzen, in: ziel)
        }
    }
}
