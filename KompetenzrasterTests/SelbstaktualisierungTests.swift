import Foundation
import Testing
@testable import Kompetenzraster

@Suite("Prüfsumme")
struct PruefsummeTests {
    @Test("SHA-256 entspricht dem, was shasum ausgibt")
    func bekannterWert() {
        // shasum -a 256 <<< "" bzw. der Hash der leeren Eingabe
        #expect(Pruefsumme.sha256(Data()) ==
                "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(Pruefsumme.sha256(Data("abc".utf8)) ==
                "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test("Der Vergleich verzeiht Schreibweise und Leerzeichen")
    func vergleich() {
        let daten = Data("abc".utf8)
        let hash = "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD"
        #expect(Pruefsumme.stimmt(daten, mit: hash))
        #expect(Pruefsumme.stimmt(daten, mit: "  \(hash.lowercased())\n"))
    }

    @Test("Falsche oder unvollständige Prüfsummen werden abgelehnt")
    func abgelehnt() {
        let daten = Data("abc".utf8)
        #expect(Pruefsumme.stimmt(daten, mit: String(repeating: "a", count: 64)) == false)
        #expect(Pruefsumme.stimmt(daten, mit: "ba7816bf") == false, "Zu kurz zählt nicht")
        #expect(Pruefsumme.stimmt(daten, mit: "") == false)
        #expect(Pruefsumme.stimmt(Data("abd".utf8),
                                  mit: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") == false)
    }
}

@Suite("Paketprüfung")
struct PaketpruefungTests {
    private func angaben(kennung: String, build: Int) -> Paketpruefung.Angaben {
        Paketpruefung.Angaben(kennung: kennung, version: "1.0", build: build)
    }

    @Test("Ein neueres Paket mit gleicher Kennung wird angenommen")
    func angenommen() throws {
        try Paketpruefung.pruefe(
            angaben: angaben(kennung: "com.kompetenzraster.app", build: 5),
            erwarteteKennung: "com.kompetenzraster.app",
            eigenerBuild: 4
        )
    }

    @Test("Ein fremdes Programm wird abgelehnt")
    func fremdesProgramm() {
        #expect(throws: Installationsfehler.fremdesProgramm("com.beispiel.anderes")) {
            try Paketpruefung.pruefe(
                angaben: angaben(kennung: "com.beispiel.anderes", build: 9),
                erwarteteKennung: "com.kompetenzraster.app",
                eigenerBuild: 4
            )
        }
    }

    @Test("Gleiche oder ältere Fassungen werden nicht installiert", arguments: [4, 3])
    func keineRueckstufung(build: Int) {
        #expect(throws: Installationsfehler.aeltereFassung) {
            try Paketpruefung.pruefe(
                angaben: angaben(kennung: "com.kompetenzraster.app", build: build),
                erwarteteKennung: "com.kompetenzraster.app",
                eigenerBuild: 4
            )
        }
    }

    @Test("Ohne lesbare Angaben gilt das Paket als leer")
    func ohneAngaben() {
        #expect(throws: Installationsfehler.keinProgrammImPaket) {
            try Paketpruefung.pruefe(angaben: nil, erwarteteKennung: "x", eigenerBuild: 0)
        }
    }

    @Test("Angaben werden aus der Info.plist eines Bundles gelesen")
    func liestInfoPlist() throws {
        let ordner = FileManager.default.temporaryDirectory
            .appending(path: "test-\(UUID().uuidString)/Beispiel.app/Contents")
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: ordner.deletingLastPathComponent()) }

        let inhalt: [String: Any] = [
            "CFBundleIdentifier": "com.kompetenzraster.app",
            "CFBundleShortVersionString": "1.2",
            "CFBundleVersion": "17",
        ]
        try PropertyListSerialization
            .data(fromPropertyList: inhalt, format: .xml, options: 0)
            .write(to: ordner.appending(path: "Info.plist"))

        let gelesen = try #require(Paketpruefung.angaben(zu: ordner.deletingLastPathComponent()))
        #expect(gelesen.kennung == "com.kompetenzraster.app")
        #expect(gelesen.version == "1.2")
        #expect(gelesen.build == 17)
    }

    @Test("Ein Ordner ohne Info.plist liefert keine Angaben")
    func ohneInfoPlist() {
        #expect(Paketpruefung.angaben(zu: FileManager.default.temporaryDirectory) == nil)
    }
}

@MainActor
struct SelbstaktualisierungTests {
    private func manifest(sha: String?, adresse: String? = "https://example.invalid/p.zip") -> Versionsmanifest {
        Versionsmanifest(version: "1.1", build: 9, veroeffentlichtAm: nil,
                         download: adresse, sha256: sha, groesse: nil, hinweise: nil)
    }

    /// Bricht ab, bevor irgendetwas am Dateisystem passiert.
    private func werkzeug(
        ordner: URL?,
        daten: @escaping @Sendable () -> Data = { Data("nicht wirklich ein ZIP".utf8) }
    ) -> Selbstaktualisierung {
        Selbstaktualisierung(
            eigene: EigeneVersion(version: "1.0", build: 4),
            kennung: "com.kompetenzraster.app",
            lader: { _, fortschritt in
                fortschritt(1)
                return daten()
            },
            ordnerzugriff: { ordner }
        )
    }

    private func fehlertext(_ fehler: Installationsfehler) -> String {
        fehler.errorDescription ?? ""
    }

    @Test("Ohne Prüfsumme in der Veröffentlichung wird nichts installiert")
    func ohnePruefsumme() async {
        let werkzeug = werkzeug(ordner: FileManager.default.temporaryDirectory)
        await werkzeug.aktualisiere(auf: manifest(sha: nil))
        #expect(werkzeug.phase == .fehler(fehlertext(.pruefsummeFehlt)))
    }

    @Test("Ohne Downloadadresse wird nichts installiert")
    func ohneAdresse() async {
        let werkzeug = werkzeug(ordner: FileManager.default.temporaryDirectory)
        await werkzeug.aktualisiere(auf: manifest(sha: String(repeating: "a", count: 64), adresse: nil))
        #expect(werkzeug.phase == .fehler(fehlertext(.keineDownloadadresse)))
    }

    @Test("Ohne Freigabe des Programmordners bricht der Vorgang ab")
    func ohneOrdnerfreigabe() async {
        let werkzeug = werkzeug(ordner: nil)
        await werkzeug.aktualisiere(auf: manifest(sha: String(repeating: "a", count: 64)))
        #expect(werkzeug.phase == .fehler(fehlertext(.ordnerNichtFreigegeben)))
    }

    @Test("Eine nicht passende Prüfsumme stoppt vor dem Entpacken")
    func falschePruefsumme() async {
        let werkzeug = werkzeug(ordner: FileManager.default.temporaryDirectory)
        await werkzeug.aktualisiere(auf: manifest(sha: String(repeating: "b", count: 64)))
        #expect(werkzeug.phase == .fehler(fehlertext(.pruefsummeFalsch)))
    }

    @Test("Stimmt die Prüfsumme, aber das Paket ist kein ZIP, scheitert das Entpacken")
    func kaputtesPaket() async {
        let inhalt = Data("nicht wirklich ein ZIP".utf8)
        let werkzeug = werkzeug(ordner: FileManager.default.temporaryDirectory) { inhalt }
        await werkzeug.aktualisiere(auf: manifest(sha: Pruefsumme.sha256(inhalt)))

        guard case .fehler(let text) = werkzeug.phase else {
            Issue.record("Erwartet wurde ein Fehler, gefunden: \(werkzeug.phase)")
            return
        }
        #expect(text.contains("entpacken"), "Gefunden: \(text)")
    }

    @Test("Nach einem Fehler lässt sich der Streifen zurücksetzen")
    func zuruecksetzen() async {
        let werkzeug = werkzeug(ordner: nil)
        await werkzeug.aktualisiere(auf: manifest(sha: String(repeating: "a", count: 64)))
        #expect(werkzeug.laeuft == false)

        werkzeug.zuruecksetzen()
        #expect(werkzeug.phase == .ruhend)
        #expect(werkzeug.beschreibung == nil)
    }

    @Test("Die Beschreibung nennt den Fortschritt in Prozent")
    func beschreibung() {
        let werkzeug = Selbstaktualisierung(
            eigene: EigeneVersion(version: "1.0", build: 1), kennung: "x",
            lader: { _, _ in Data() }, ordnerzugriff: { nil }
        )
        #expect(werkzeug.beschreibung == nil)
        #expect(werkzeug.laeuft == false)
    }
}
