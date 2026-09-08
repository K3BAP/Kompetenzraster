import Foundation
import Testing
@testable import Kompetenzraster

/// Der einmalige Umzug aus dem alten Sandbox-Container.
struct DatenumzugTests {
    private func ordnerpaar() throws -> (alt: URL, neu: URL) {
        let wurzel = FileManager.default.temporaryDirectory.appending(path: "umzug-\(UUID().uuidString)")
        let alt = wurzel.appending(path: "alt")
        let neu = wurzel.appending(path: "neu")
        try FileManager.default.createDirectory(at: alt, withIntermediateDirectories: true)
        return (alt, neu)
    }

    private func lege(_ dateien: [String: String], nach ordner: URL) throws {
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        for (name, inhalt) in dateien {
            try Data(inhalt.utf8).write(to: ordner.appending(path: name))
        }
    }

    private func inhalt(_ ordner: URL, _ name: String) -> String? {
        try? String(contentsOf: ordner.appending(path: name), encoding: .utf8)
    }

    @Test("Der alte Bestand wird samt Journaldateien übernommen")
    func uebernimmtAllesDrei() throws {
        let (alt, neu) = try ordnerpaar()
        defer { try? FileManager.default.removeItem(at: alt.deletingLastPathComponent()) }

        try lege([
            "Kompetenzraster.store": "haupt",
            "Kompetenzraster.store-wal": "journal",
            "Kompetenzraster.store-shm": "gemeinsam",
        ], nach: alt)

        #expect(Datenumzug.ausAlterSandbox(neuerOrdner: neu, alterOrdner: alt))
        #expect(inhalt(neu, "Kompetenzraster.store") == "haupt")
        #expect(inhalt(neu, "Kompetenzraster.store-wal") == "journal",
                "Ohne die WAL-Datei fehlten die zuletzt erfassten Einträge")
        #expect(inhalt(neu, "Kompetenzraster.store-shm") == "gemeinsam")
    }

    @Test("Der alte Bestand bleibt unangetastet")
    func lässtDasOriginalLiegen() throws {
        let (alt, neu) = try ordnerpaar()
        defer { try? FileManager.default.removeItem(at: alt.deletingLastPathComponent()) }
        try lege(["Kompetenzraster.store": "haupt"], nach: alt)

        #expect(Datenumzug.ausAlterSandbox(neuerOrdner: neu, alterOrdner: alt))
        #expect(inhalt(alt, "Kompetenzraster.store") == "haupt")
    }

    @Test("Ein vorhandener neuer Bestand wird nicht überschrieben")
    func ueberschreibtNichts() throws {
        let (alt, neu) = try ordnerpaar()
        defer { try? FileManager.default.removeItem(at: alt.deletingLastPathComponent()) }
        try lege(["Kompetenzraster.store": "alt"], nach: alt)
        try lege(["Kompetenzraster.store": "neu und in Benutzung"], nach: neu)

        #expect(Datenumzug.ausAlterSandbox(neuerOrdner: neu, alterOrdner: alt) == false)
        #expect(inhalt(neu, "Kompetenzraster.store") == "neu und in Benutzung")
    }

    @Test("Ohne alten Bestand passiert nichts")
    func ohneAltbestand() throws {
        let (alt, neu) = try ordnerpaar()
        defer { try? FileManager.default.removeItem(at: alt.deletingLastPathComponent()) }

        #expect(Datenumzug.ausAlterSandbox(neuerOrdner: neu, alterOrdner: alt) == false)
        #expect(FileManager.default.fileExists(atPath: neu.appending(path: "Kompetenzraster.store").path) == false)
    }

    @Test("Fehlende Journaldateien sind kein Hindernis")
    func nurHauptdatei() throws {
        let (alt, neu) = try ordnerpaar()
        defer { try? FileManager.default.removeItem(at: alt.deletingLastPathComponent()) }
        try lege(["Kompetenzraster.store": "haupt"], nach: alt)

        #expect(Datenumzug.ausAlterSandbox(neuerOrdner: neu, alterOrdner: alt))
        #expect(inhalt(neu, "Kompetenzraster.store") == "haupt")
        #expect(FileManager.default.fileExists(
            atPath: neu.appending(path: "Kompetenzraster.store-wal").path) == false)
    }
}
