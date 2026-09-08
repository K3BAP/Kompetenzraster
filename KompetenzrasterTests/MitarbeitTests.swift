import Foundation
import SwiftData
import Testing
@testable import Kompetenzraster

/// Erfassung der Mitarbeit: genau ein Eintrag je Stunde und Kind, keine leeren Zeilen.
@MainActor
@Suite("Mitarbeit erfassen")
struct MitarbeitserfassungTests {
    private func aufbau() throws -> (ModelContext, Klasse, SchuelerIn, Mitarbeitsstunde) {
        let kontext = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        let klasse = Klasse(name: "3a", jahrgangsstufe: 3, schuljahr: "2025/26")
        kontext.insert(klasse)
        let kind = SchuelerIn(vorname: "Anna", nachname: "Berger")
        kontext.insert(kind)
        kind.klasse = klasse
        let stunde = Mitarbeitserfassung.neueStunde(fuer: klasse, fach: "Mathematik", in: kontext)
        return (kontext, klasse, kind, stunde)
    }

    @Test("Erneutes Beobachten legt keinen zweiten Eintrag an")
    func genauEinEintrag() throws {
        let (kontext, _, kind, stunde) = try aufbau()
        Mitarbeitserfassung.setze(.gut, achse: .haeufigkeit, fuer: kind, in: stunde, kontext: kontext)
        Mitarbeitserfassung.setze(.sehrGut, achse: .haeufigkeit, fuer: kind, in: stunde, kontext: kontext)
        Mitarbeitserfassung.setze(.ansatzweise, achse: .qualitaet, fuer: kind, in: stunde, kontext: kontext)

        #expect(try kontext.fetchCount(FetchDescriptor<Mitarbeitseintrag>()) == 1)
        let eintrag = try #require(stunde.eintrag(fuer: kind))
        #expect(eintrag.haeufigkeit == .sehrGut)
        #expect(eintrag.qualitaet == .ansatzweise)
        #expect(eintrag.arbeitsverhalten == nil, "Was nicht beobachtet wurde, bleibt leer")
    }

    @Test("Ein Eintrag ohne Beobachtung, Notiz und Abwesenheit wird wieder gelöscht")
    func leereEintraegeVerschwinden() throws {
        let (kontext, _, kind, stunde) = try aufbau()
        Mitarbeitserfassung.setze(.gut, achse: .qualitaet, fuer: kind, in: stunde, kontext: kontext)
        Mitarbeitserfassung.setze(nil, achse: .qualitaet, fuer: kind, in: stunde, kontext: kontext)

        #expect(try kontext.fetchCount(FetchDescriptor<Mitarbeitseintrag>()) == 0)
        #expect(stunde.anzahlErfasst == 0, "Sonst zählte die Quote leere Zeilen mit")
    }

    @Test("Notiz und Abwesenheit halten einen Eintrag am Leben")
    func notizUndAbwesenheitBleiben() throws {
        let (kontext, _, kind, stunde) = try aufbau()
        Mitarbeitserfassung.setzeNotiz("hat gestockt", fuer: kind, in: stunde, kontext: kontext)
        #expect(stunde.eintrag(fuer: kind)?.notiz == "hat gestockt")

        let (kontext2, _, kind2, stunde2) = try aufbau()
        Mitarbeitserfassung.setzeAnwesenheit(false, fuer: kind2, in: stunde2, kontext: kontext2)
        #expect(stunde2.eintrag(fuer: kind2)?.anwesend == false)
    }

    @Test("Wer als abwesend eingetragen wird, verliert die Beobachtungen dieser Stunde")
    func abwesenheitRaeumtAuf() throws {
        let (kontext, _, kind, stunde) = try aufbau()
        Mitarbeitserfassung.setze(.gut, achse: .haeufigkeit, fuer: kind, in: stunde, kontext: kontext)
        Mitarbeitserfassung.setzeAnwesenheit(false, fuer: kind, in: stunde, kontext: kontext)

        let eintrag = try #require(stunde.eintrag(fuer: kind))
        #expect(eintrag.haeufigkeit == nil)
        #expect(eintrag.anwesend == false)
    }

    @Test("Eine gelöschte Stunde nimmt ihre Beobachtungen mit")
    func stundeLoeschen() throws {
        let (kontext, _, kind, stunde) = try aufbau()
        Mitarbeitserfassung.setze(.gut, achse: .qualitaet, fuer: kind, in: stunde, kontext: kontext)
        Mitarbeitserfassung.loesche(stunde, in: kontext)

        #expect(try kontext.fetchCount(FetchDescriptor<Mitarbeitsstunde>()) == 0)
        #expect(try kontext.fetchCount(FetchDescriptor<Mitarbeitseintrag>()) == 0)
    }
}

/// Halbjahre, Mittelwerte, Quote und Trend.
@MainActor
@Suite("Mitarbeit auswerten")
struct MitarbeitsauswertungTests {
    private let kalender = Calendar(identifier: .gregorian)

    private func datum(_ jahr: Int, _ monat: Int, _ tag: Int) -> Date {
        kalender.date(from: DateComponents(year: jahr, month: monat, day: tag)) ?? .distantPast
    }

    private func aufbau() throws -> (ModelContext, Klasse, SchuelerIn) {
        let kontext = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        let klasse = Klasse(name: "3a", jahrgangsstufe: 3, schuljahr: "2025/26")
        kontext.insert(klasse)
        let kind = SchuelerIn(vorname: "Ben", nachname: "Cordes")
        kontext.insert(kind)
        kind.klasse = klasse
        return (kontext, klasse, kind)
    }

    @discardableResult
    private func stunde(
        _ klasse: Klasse, _ datum: Date, in kontext: ModelContext
    ) -> Mitarbeitsstunde {
        Mitarbeitserfassung.neueStunde(
            fuer: klasse, fach: "Deutsch", datum: datum, in: kontext, kalender: kalender
        )
    }

    @Test("Das erste Halbjahr endet mit dem Januar")
    func halbjahresgrenzen() throws {
        let erstes = try #require(Halbjahr.erstes.zeitraum(imSchuljahr: "2025/26", kalender: kalender))
        let zweites = try #require(Halbjahr.zweites.zeitraum(imSchuljahr: "2025/26", kalender: kalender))

        #expect(erstes.contains(datum(2025, 8, 1)))
        #expect(erstes.contains(datum(2026, 1, 31)), "Der 31. Januar gehört noch ins erste Halbjahr")
        #expect(!erstes.contains(datum(2026, 2, 1)))
        #expect(zweites.contains(datum(2026, 2, 1)))
        #expect(zweites.contains(datum(2026, 7, 31)))
        #expect(!zweites.contains(datum(2026, 8, 1)), "Da beginnt schon das nächste Schuljahr")
    }

    @Test("Der Zeitraum filtert die Stunden")
    func stundenImZeitraum() throws {
        let (kontext, klasse, _) = try aufbau()
        stunde(klasse, datum(2025, 11, 12), in: kontext)
        stunde(klasse, datum(2026, 3, 4), in: kontext)

        let erstes = Halbjahr.erstes.zeitraum(imSchuljahr: klasse.schuljahr, kalender: kalender)
        let ganzes = Halbjahr.ganzesJahr.zeitraum(imSchuljahr: klasse.schuljahr, kalender: kalender)

        #expect(Mitarbeitsauswertung.stunden(in: klasse, fach: "Deutsch", zeitraum: erstes).count == 1)
        #expect(Mitarbeitsauswertung.stunden(in: klasse, fach: "Deutsch", zeitraum: ganzes).count == 2)
        #expect(Mitarbeitsauswertung.stunden(in: klasse, fach: "Mathematik", zeitraum: ganzes).isEmpty)
    }

    @Test("Nicht beobachtete Achsen und Fehlstunden bleiben aus Mittelwert und Quote heraus")
    func mittelwertUndQuote() throws {
        let (kontext, klasse, kind) = try aufbau()
        let erste = stunde(klasse, datum(2025, 9, 1), in: kontext)
        let zweite = stunde(klasse, datum(2025, 9, 8), in: kontext)
        let dritte = stunde(klasse, datum(2025, 9, 15), in: kontext)
        let vierte = stunde(klasse, datum(2025, 9, 22), in: kontext)

        Mitarbeitserfassung.setze(.ansatzweise, achse: .qualitaet, fuer: kind, in: erste, kontext: kontext)
        Mitarbeitserfassung.setze(.sehrGut, achse: .qualitaet, fuer: kind, in: zweite, kontext: kontext)
        Mitarbeitserfassung.setze(.gut, achse: .haeufigkeit, fuer: kind, in: zweite, kontext: kontext)
        Mitarbeitserfassung.setzeAnwesenheit(false, fuer: kind, in: dritte, kontext: kontext)
        // In der vierten Stunde ist nichts aufgefallen – das ist keine schlechte Bewertung.

        let stunden = Mitarbeitsauswertung.stunden(
            in: klasse, fach: "Deutsch",
            zeitraum: Halbjahr.ganzesJahr.zeitraum(imSchuljahr: klasse.schuljahr, kalender: kalender)
        )
        let ergebnis = Mitarbeitsauswertung.ergebnis(fuer: kind, stunden: stunden)

        #expect(ergebnis.stundenGesamt == 4)
        #expect(ergebnis.fehlzeiten == 1)
        #expect(ergebnis.erfassteStunden == 2)
        #expect(ergebnis.quote == 2.0 / 3.0, "Die Fehlstunde zählt nicht gegen das Kind")
        #expect(ergebnis.mittelwert(.qualitaet) == 2.0)
        #expect(ergebnis.mittelwert(.haeufigkeit) == 2.0)
        #expect(ergebnis.mittelwert(.arbeitsverhalten) == nil, "Nie beobachtet – kein Wert")
    }

    @Test("Der Trend zeigt die Steigerung innerhalb des Zeitraums")
    func trend() throws {
        let (kontext, klasse, kind) = try aufbau()
        let werte: [(Int, Mitarbeitsstufe)] = [
            (1, .kaum), (8, .ansatzweise), (15, .gut), (22, .sehrGut),
        ]
        for (tag, stufe) in werte {
            let einheit = stunde(klasse, datum(2025, 9, tag), in: kontext)
            Mitarbeitserfassung.setze(stufe, achse: .haeufigkeit, fuer: kind, in: einheit, kontext: kontext)
        }

        let stunden = Mitarbeitsauswertung.stunden(in: klasse, fach: "Deutsch", zeitraum: nil)
        let ergebnis = Mitarbeitsauswertung.ergebnis(fuer: kind, stunden: stunden)

        #expect(ergebnis.mittelwert(.haeufigkeit) == 1.5)
        #expect(ergebnis.trend(.haeufigkeit) == 2.0, "Von (0+1)/2 auf (2+3)/2")
        #expect(ergebnis.trend(.qualitaet) == nil)
    }

    @Test("Der Verlauf ist zeitlich sortiert und enthält nur Beobachtetes")
    func verlauf() throws {
        let (kontext, klasse, kind) = try aufbau()
        let spaet = stunde(klasse, datum(2025, 10, 20), in: kontext)
        let frueh = stunde(klasse, datum(2025, 10, 6), in: kontext)
        let ohne = stunde(klasse, datum(2025, 10, 13), in: kontext)
        Mitarbeitserfassung.setze(.gut, achse: .qualitaet, fuer: kind, in: spaet, kontext: kontext)
        Mitarbeitserfassung.setze(.kaum, achse: .qualitaet, fuer: kind, in: frueh, kontext: kontext)
        Mitarbeitserfassung.setzeNotiz("nur eine Notiz", fuer: kind, in: ohne, kontext: kontext)

        let punkte = Mitarbeitsauswertung.verlauf(
            fuer: kind, achse: .qualitaet,
            stunden: Mitarbeitsauswertung.stunden(in: klasse, fach: "Deutsch", zeitraum: nil)
        )
        #expect(punkte.map(\.wert) == [0, 2])
        #expect(punkte.first?.datum == kalender.startOfDay(for: datum(2025, 10, 6)))
    }
}

/// Mitarbeit muss die Sicherung überstehen – und alte Sicherungen müssen weiter einlesbar sein.
@MainActor
@Suite("Mitarbeit sichern")
struct MitarbeitsSicherungTests {
    @Test("Stunden und Beobachtungen überstehen Export und Import")
    func roundtrip() throws {
        let kontext = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        let klasse = Klasse(name: "3a", jahrgangsstufe: 3, schuljahr: "2025/26")
        kontext.insert(klasse)
        let kind = SchuelerIn(vorname: "Clara", nachname: "Dorn")
        kontext.insert(kind)
        kind.klasse = klasse
        let stunde = Mitarbeitserfassung.neueStunde(
            fuer: klasse, fach: "Sport", thema: "Ballschule", in: kontext
        )
        Mitarbeitserfassung.setze(.sehrGut, achse: .arbeitsverhalten, fuer: kind, in: stunde, kontext: kontext)
        Mitarbeitserfassung.setzeNotiz("hat der Gruppe geholfen", fuer: kind, in: stunde, kontext: kontext)

        let daten = try BackupService.export(aus: kontext)
        let vorschau = try BackupService.vorschau(daten)
        #expect(vorschau.zaehler.mitarbeitsstunden == 1)

        let ziel = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        try BackupService.importiere(daten, modus: .ersetzen, in: ziel)

        let stunden = try ziel.fetch(FetchDescriptor<Mitarbeitsstunde>())
        #expect(stunden.count == 1)
        #expect(stunden.first?.thema == "Ballschule")
        #expect(stunden.first?.klasse?.name == "3a")
        let eintrag = try #require(stunden.first?.eintraege.first)
        #expect(eintrag.arbeitsverhalten == .sehrGut)
        #expect(eintrag.notiz == "hat der Gruppe geholfen")
        #expect(eintrag.schueler?.vorname == "Clara")
    }

    @Test("Eine Sicherung im Format 1 lässt sich weiterhin einspielen")
    func alteSicherung() throws {
        let alt = """
        {
          "schemaVersion" : 1,
          "appVersion" : "1.0",
          "exportiertAm" : "2025-09-01T10:00:00Z",
          "verschluesselt" : false,
          "zaehler" : { "klassen" : 1, "schueler" : 1, "raster" : 0, "kompetenzen" : 0, "eintraege" : 0 },
          "daten" : {
            "klassen" : [ { "id" : "11111111-1111-1111-1111-111111111111", "name" : "4b",
              "jahrgangsstufe" : 4, "schuljahr" : "2025/26", "notiz" : "", "sortIndex" : 0,
              "erstelltAm" : "2025-09-01T10:00:00Z", "rasterIDs" : [] } ],
            "schueler" : [ { "id" : "22222222-2222-2222-2222-222222222222", "vorname" : "David",
              "nachname" : "Engel", "kuerzel" : "DE", "notiz" : "", "sortIndex" : 0,
              "erstelltAm" : "2025-09-01T10:00:00Z",
              "klasseID" : "11111111-1111-1111-1111-111111111111" } ],
            "skalen" : [], "stufen" : [], "raster" : [], "kompetenzen" : [], "eintraege" : []
          }
        }
        """
        let ziel = ModelContext(try Datenbestand.container(imArbeitsspeicher: true))
        try BackupService.importiere(Data(alt.utf8), modus: .ersetzen, in: ziel)

        #expect(try ziel.fetch(FetchDescriptor<Klasse>()).first?.name == "4b")
        #expect(try ziel.fetchCount(FetchDescriptor<Mitarbeitsstunde>()) == 0)
    }
}
