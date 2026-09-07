import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Der in der Info.plist deklarierte Dateityp der Sicherungen.
    static let kompetenzSicherung = UTType(exportedAs: "com.kompetenzraster.sicherung")
}

/// Ein bereits erzeugtes Backup, das über den Sichern-Dialog geschrieben wird.
struct SicherungsDokument: FileDocument {
    static let readableContentTypes: [UTType] = [.kompetenzSicherung, .json]

    var inhalt: Data

    init(inhalt: Data) { self.inhalt = inhalt }

    init(configuration: ReadConfiguration) throws {
        inhalt = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: inhalt)
    }
}

enum Sicherungsname {
    /// „Kompetenzraster-Sicherung 2026-09-07“ – sortiert sich im Finder von selbst.
    static var vorschlag: String {
        let formatierer = DateFormatter()
        formatierer.dateFormat = "yyyy-MM-dd"
        return "Kompetenzraster-Sicherung \(formatierer.string(from: Date()))"
    }
}

/// Liest eine Sicherungsdatei und hält den Zustand des Imports.
/// Wird von der Ersteinrichtung und den Einstellungen gemeinsam genutzt.
@MainActor
@Observable
final class SicherungsImport {
    var rohdaten: Data?
    var vorschau: BackupDatei?
    var passwort = ""
    var fehler: String?

    var brauchtPasswort: Bool { vorschau?.verschluesselt == true }
    var bereit: Bool { rohdaten != nil && (!brauchtPasswort || !passwort.isEmpty) }

    func lade(von url: URL) {
        fehler = nil
        vorschau = nil
        rohdaten = nil

        // In der Sandbox muss der Zugriff auf eine gewählte Datei ausdrücklich geöffnet werden.
        let zugriff = url.startAccessingSecurityScopedResource()
        defer { if zugriff { url.stopAccessingSecurityScopedResource() } }

        do {
            let daten = try Data(contentsOf: url)
            vorschau = try BackupService.vorschau(daten)
            rohdaten = daten
        } catch {
            fehler = error.localizedDescription
        }
    }

    /// Gibt zurück, ob der Import geklappt hat.
    func fuehreAus(modus: BackupService.Importmodus, in kontext: ModelContext) -> Bool {
        guard let rohdaten else { return false }
        do {
            try BackupService.importiere(
                rohdaten, modus: modus,
                passwort: passwort.isEmpty ? nil : passwort,
                in: kontext
            )
            fehler = nil
            return true
        } catch {
            fehler = error.localizedDescription
            return false
        }
    }
}
