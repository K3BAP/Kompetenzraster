import Foundation
import Testing
@testable import Kompetenzraster

/// Zählt die Abrufe des Prüfers über Aufgabengrenzen hinweg.
private final class Abrufzaehler: @unchecked Sendable {
    private let sperre = NSLock()
    private var wert = 0

    func zaehle() {
        sperre.lock(); defer { sperre.unlock() }
        wert += 1
    }

    var stand: Int {
        sperre.lock(); defer { sperre.unlock() }
        return wert
    }
}

/// Baut eine Antwort, wie sie am Release hängt. Bewusst außerhalb des MainActor,
/// damit die Ladeschließung sie nutzen kann.
private func manifestDaten(build: Int, version: String = "1.1") -> Data {
    try! JSONEncoder().encode(
        Versionsmanifest(version: version, build: build, veroeffentlichtAm: nil,
                         download: nil, hinweise: "Testbau")
    )
}

@MainActor
struct AktualisierungTests {
    private func frischerSpeicher() -> UserDefaults {
        UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    }

    private func pruefer(
        eigenerBuild: Int,
        speicher: UserDefaults,
        zaehler: Abrufzaehler = Abrufzaehler(),
        antwort: @escaping @Sendable () throws -> Data
    ) -> Aktualisierungspruefer {
        Aktualisierungspruefer(
            eigene: EigeneVersion(version: "1.0", build: eigenerBuild),
            speicher: speicher
        ) { _ in
            zaehler.zaehle()
            return try antwort()
        }
    }

    @Test("Ein höherer Build wird als neue Version gemeldet")
    func neueVersion() async {
        let werkzeug = pruefer(eigenerBuild: 4, speicher: frischerSpeicher()) { manifestDaten(build: 7) }
        await werkzeug.pruefe(erzwungen: true)

        guard case .neueVersion(let gefunden) = werkzeug.stand else {
            Issue.record("Erwartet wurde eine neue Version, gefunden: \(werkzeug.stand)")
            return
        }
        #expect(gefunden.build == 7)
        #expect(gefunden.version == "1.1")
        #expect(werkzeug.zeigtHinweis)
    }

    @Test("Gleicher oder älterer Build gilt als aktuell", arguments: [12, 5])
    func keineNeueVersion(entfernterBuild: Int) async {
        let werkzeug = pruefer(eigenerBuild: 12, speicher: frischerSpeicher()) {
            manifestDaten(build: entfernterBuild)
        }
        await werkzeug.pruefe(erzwungen: true)

        #expect(werkzeug.stand == .aktuell)
        #expect(werkzeug.zeigtHinweis == false)
    }

    @Test("Ohne Netz bleibt es bei einer stillen Meldung")
    func netzfehler() async {
        let werkzeug = pruefer(eigenerBuild: 1, speicher: frischerSpeicher()) {
            throw URLError(.notConnectedToInternet)
        }
        await werkzeug.pruefe(erzwungen: true)

        guard case .fehler = werkzeug.stand else {
            Issue.record("Erwartet wurde ein Fehlerstand, gefunden: \(werkzeug.stand)")
            return
        }
        #expect(werkzeug.zeigtHinweis == false, "Ein Netzfehler darf keinen Hinweis auslösen")
    }

    @Test("Unlesbare Antworten führen nicht zum Absturz")
    func kaputteAntwort() async {
        let werkzeug = pruefer(eigenerBuild: 1, speicher: frischerSpeicher()) {
            Data("<html>404</html>".utf8)
        }
        await werkzeug.pruefe(erzwungen: true)

        guard case .fehler = werkzeug.stand else {
            Issue.record("Erwartet wurde ein Fehlerstand, gefunden: \(werkzeug.stand)")
            return
        }
    }

    @Test("Von selbst wird höchstens einmal am Tag nachgesehen")
    func tagesbremse() async {
        let speicher = frischerSpeicher()
        let zaehler = Abrufzaehler()

        let erster = pruefer(eigenerBuild: 9, speicher: speicher, zaehler: zaehler) {
            manifestDaten(build: 9)
        }
        await erster.pruefe(erzwungen: false)
        #expect(zaehler.stand == 1)

        // Ein zweiter Start am selben Tag darf nicht erneut anfragen.
        let zweiter = pruefer(eigenerBuild: 9, speicher: speicher, zaehler: zaehler) {
            manifestDaten(build: 9)
        }
        await zweiter.pruefe(erzwungen: false)
        #expect(zaehler.stand == 1)

        // Der Knopf in den Einstellungen umgeht die Bremse.
        await zweiter.pruefe(erzwungen: true)
        #expect(zaehler.stand == 2)
    }

    @Test("„Später“ blendet genau diese Fassung dauerhaft aus")
    func spaeter() async {
        let speicher = frischerSpeicher()

        let erster = pruefer(eigenerBuild: 3, speicher: speicher) { manifestDaten(build: 8) }
        await erster.pruefe(erzwungen: true)
        #expect(erster.zeigtHinweis)
        erster.spaeter()
        #expect(erster.zeigtHinweis == false)

        // Beim nächsten Start bleibt derselbe Build stumm …
        let zweiter = pruefer(eigenerBuild: 3, speicher: speicher) { manifestDaten(build: 8) }
        await zweiter.pruefe(erzwungen: true)
        #expect(zweiter.zeigtHinweis == false)

        // … eine noch neuere Fassung meldet sich aber wieder.
        let dritter = pruefer(eigenerBuild: 3, speicher: speicher) { manifestDaten(build: 9) }
        await dritter.pruefe(erzwungen: true)
        #expect(dritter.zeigtHinweis)
    }

    @Test("Die eigene Fassung wird aus der Info.plist gelesen")
    func eigeneVersionAusBundle() {
        let eigene = EigeneVersion.ausBundle(.main)
        #expect(!eigene.version.isEmpty)
        #expect(eigene.build >= 0)
        #expect(eigene.beschriftung.contains("Build"))
    }

    @Test("Der Vergleich richtet sich nach der Build-Nummer")
    func vergleich() {
        let eigene = EigeneVersion(version: "1.0", build: 10)
        let neuer = Versionsmanifest(version: "1.0", build: 11, veroeffentlichtAm: nil, download: nil, hinweise: nil)
        let gleich = Versionsmanifest(version: "2.0", build: 10, veroeffentlichtAm: nil, download: nil, hinweise: nil)

        #expect(Versionsvergleich.istNeuer(neuer, als: eigene))
        #expect(Versionsvergleich.istNeuer(gleich, als: eigene) == false,
                "Eine höhere Versionszeichenkette allein reicht nicht")
    }
}
