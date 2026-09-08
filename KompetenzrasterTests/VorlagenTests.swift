import Foundation
import SwiftData
import Testing
@testable import Kompetenzraster

@MainActor
struct VorlagenTests {
    @Test("Alle drei mitgelieferten Raster lassen sich laden", arguments: VorlagenLader.verfuegbareFaecher)
    func vorlageLaedt(fach: String) throws {
        let vorlage = try VorlagenLader.datei(fach: fach)
        #expect(vorlage.fach == fach)
        #expect(vorlage.schemaVersion == 1)
        #expect(!vorlage.quelle.isEmpty, "Die Herkunft muss angegeben sein")
        #expect(vorlage.kompetenzen.count >= 4)
        // Jeder Bereich muss mindestens eine Oberkompetenz haben.
        for bereich in vorlage.kompetenzen {
            #expect((bereich.kinder ?? []).isEmpty == false, "„\(bereich.titel)“ hat keine Oberkompetenzen")
        }
    }

    @Test("Der Umfang der Vorlagen entspricht den Teilrahmenplänen")
    func umfang() throws {
        let erwartet = ["Deutsch": 22, "Mathematik": 60, "Sachunterricht": 33]
        for (fach, anzahl) in erwartet {
            #expect(try VorlagenLader.datei(fach: fach).anzahlKompetenzen == anzahl)
        }
    }

    @Test("Eine Vorlage wird als Baum in die Datenbank übernommen")
    func einfuegenBautDenBaum() throws {
        let kontext = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        let skala = Bewertungsskala.standard()
        kontext.insert(skala)
        for stufe in skala.stufen { kontext.insert(stufe) }

        let vorlage = try VorlagenLader.datei(fach: "Deutsch")
        let raster = VorlagenLader.einfuegen(vorlage, in: kontext, skala: skala)
        try kontext.save()

        #expect(raster.istVorlage)
        #expect(raster.kompetenzen.count == vorlage.anzahlKompetenzen)
        #expect(raster.wurzeln.count == 4)
        #expect(raster.wurzeln.first?.titel == "Sprechen und Zuhören")
        #expect(raster.blattKompetenzen.count == 18, "Bewertet werden nur die Oberkompetenzen")

        // Die Reihenfolge aus der Vorlage muss erhalten bleiben.
        #expect(raster.wurzeln.map(\.titel).last == "Sprache und Sprachgebrauch untersuchen")
        let ersterBereich = try #require(raster.wurzeln.first)
        #expect(ersterBereich.kinderSortiert.first?.titel == "zu anderen sprechen")
        #expect(ersterBereich.kinderSortiert.allSatisfy { $0.ebene == 1 })
    }

    @Test("Mathematik behält seine dreistufige Gliederung")
    func mathematikIstDreistufig() throws {
        let kontext = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        let skala = Bewertungsskala.standard()
        kontext.insert(skala)
        for stufe in skala.stufen { kontext.insert(stufe) }

        let raster = VorlagenLader.einfuegen(
            try VorlagenLader.datei(fach: "Mathematik"), in: kontext, skala: skala
        )
        try kontext.save()

        // Auch die prozessbezogenen Kompetenzen sind dreistufig: Bereich → Darstellen … → D1 …
        let prozess = try #require(raster.wurzeln.first { $0.code == "2.2" })
        #expect(prozess.kinderSortiert.map(\.titel) == [
            "Darstellen", "Kommunizieren", "Argumentieren", "Modellieren", "Problemlösen",
        ])
        #expect(prozess.kinderSortiert.allSatisfy { !$0.kinder.isEmpty }, "Sie sind Oberkompetenzen, keine Blätter")
        #expect(prozess.blaetterImTeilbaum.count == 16)
        #expect(prozess.blaetterImTeilbaum.first?.code == "D1")

        let raumUndForm = try #require(raster.wurzeln.first { $0.titel == "Raum und Form" })
        #expect(raumUndForm.code == "4.1")
        let orientieren = try #require(raumUndForm.kinderSortiert.first)
        #expect(orientieren.code == "4.1.1")
        #expect(orientieren.ebene == 1)
        #expect(orientieren.kinderSortiert.first?.ebene == 2)
        #expect(raster.kompetenzen.map(\.ebene).max() == 2)
    }

    @Test("Sicherung und Rückspielen überstehen einen tiefen Baum")
    func vorlageUeberlebtBackup() throws {
        let quelle = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        let skala = Bewertungsskala.standard()
        quelle.insert(skala)
        for stufe in skala.stufen { quelle.insert(stufe) }
        for fach in VorlagenLader.verfuegbareFaecher {
            VorlagenLader.einfuegen(try VorlagenLader.datei(fach: fach), in: quelle, skala: skala)
        }
        try quelle.save()

        let rohdaten = try BackupService.export(aus: quelle)
        let ziel = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        try BackupService.importiere(rohdaten, modus: .ersetzen, in: ziel)

        #expect(try ziel.fetchCount(FetchDescriptor<Kompetenz>()) == 22 + 60 + 33)
        let mathe = try #require(
            try ziel.fetch(FetchDescriptor<Kompetenzraster>()).first { $0.fach == "Mathematik" }
        )
        #expect(mathe.wurzeln.count == 5)
        #expect(mathe.kompetenzen.map(\.ebene).max() == 2, "Die Eltern-Kind-Kette muss erhalten bleiben")
    }
}

@MainActor
struct AuswertungTests {
    /// Ein Raster mit einem Bereich und drei Blättern.
    private func aufbau() throws -> (ModelContext, Kompetenzraster, SchuelerIn, [Kompetenz], Bewertungsskala) {
        let kontext = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        let skala = Bewertungsskala.standard()
        kontext.insert(skala)
        for stufe in skala.stufen { kontext.insert(stufe) }

        let raster = Kompetenzraster(name: "Test", fach: "Test")
        raster.skala = skala
        kontext.insert(raster)

        let bereich = Kompetenz(titel: "Bereich")
        kontext.insert(bereich)
        bereich.raster = raster

        var blaetter: [Kompetenz] = []
        for index in 0 ..< 3 {
            let blatt = Kompetenz(titel: "Blatt \(index)", sortIndex: index)
            kontext.insert(blatt)
            blatt.raster = raster
            blatt.eltern = bereich
            blaetter.append(blatt)
        }

        let person = SchuelerIn(vorname: "Test", nachname: "Kind")
        kontext.insert(person)
        try kontext.save()
        return (kontext, raster, person, blaetter, skala)
    }

    private func bewerte(_ kompetenz: Kompetenz, _ person: SchuelerIn, wert: Int,
                         skala: Bewertungsskala, in kontext: ModelContext) {
        let eintrag = Eintrag()
        kontext.insert(eintrag)
        eintrag.kompetenz = kompetenz
        eintrag.schueler = person
        eintrag.stufe = skala.stufenSortiert.first { $0.wert == wert }
    }

    @Test("Ohne Einträge bleibt das Ergebnis leer statt null")
    func leeresErgebnis() throws {
        let (_, raster, person, _, _) = try aufbau()
        let ergebnis = Auswertung.ergebnis(fuer: raster, schueler: person)
        #expect(ergebnis.istLeer)
        #expect(ergebnis.mittelwert == nil)
        #expect(ergebnis.bewertet == 0)
        #expect(ergebnis.gesamt == 3)
        #expect(ergebnis.anteilBewertet == 0)
    }

    @Test("Unbewertete Kompetenzen ziehen den Mittelwert nicht nach unten")
    func teilweiseBewertet() throws {
        let (kontext, raster, person, blaetter, skala) = try aufbau()
        bewerte(blaetter[0], person, wert: 3, skala: skala, in: kontext)
        bewerte(blaetter[1], person, wert: 1, skala: skala, in: kontext)
        try kontext.save()

        let ergebnis = Auswertung.ergebnis(fuer: raster, schueler: person)
        #expect(ergebnis.mittelwert == 2.0)
        #expect(ergebnis.bewertet == 2)
        #expect(ergebnis.gesamt == 3)

        // Der Bereich fasst dieselben Blätter zusammen.
        let bereich = try #require(raster.wurzeln.first)
        #expect(Auswertung.ergebnis(fuer: bereich, schueler: person).mittelwert == 2.0)
    }

    @Test("Einträge anderer Kinder bleiben unberücksichtigt")
    func trenntSchueler() throws {
        let (kontext, raster, person, blaetter, skala) = try aufbau()
        let andere = SchuelerIn(vorname: "Andere", nachname: "Person")
        kontext.insert(andere)
        bewerte(blaetter[0], person, wert: 0, skala: skala, in: kontext)
        bewerte(blaetter[0], andere, wert: 3, skala: skala, in: kontext)
        try kontext.save()

        #expect(Auswertung.ergebnis(fuer: raster, schueler: person).mittelwert == 0)
        #expect(Auswertung.ergebnis(fuer: raster, schueler: andere).mittelwert == 3)
    }

    @Test("Der Mittelwert wird auf die nächstgelegene Stufe abgebildet")
    func stufeFuerMittelwert() throws {
        let skala = Bewertungsskala.standard()
        #expect(skala.stufe(fuerMittelwert: 0)?.name == "noch nicht")
        #expect(skala.stufe(fuerMittelwert: 2.4)?.name == "überwiegend")
        #expect(skala.stufe(fuerMittelwert: 2.6)?.name == "sicher")
        #expect(skala.hoechsterWert == 3)
    }
}
