import Foundation

/// Holt den Datenbestand einmalig aus dem alten Sandbox-Container.
///
/// Bis Version 1.0 lief die App in einer Sandbox; ihr Datenbestand lag deshalb unter
/// `~/Library/Containers/…`. Seit der Selbst-Aktualisierung läuft sie ohne Sandbox und
/// sucht in `~/Library/Application Support`. Ohne diesen Umzug stünde die Lehrperson
/// nach dem Umstieg vor einer leeren App, obwohl ihre Daten noch da sind.
enum Datenumzug {
    static let containerkennung = "com.kompetenzraster.app"

    /// Kopiert den alten Bestand, sofern am neuen Ort noch keiner liegt.
    /// Das Original bleibt liegen – ein Umzug soll nichts vernichten können.
    @discardableResult
    static func ausAlterSandbox(
        dateiverwaltung: FileManager = .default,
        neuerOrdner: URL? = nil,
        alterOrdner: URL? = nil
    ) -> Bool {
        guard let ziel = neuerOrdner ?? standardZiel(dateiverwaltung) else { return false }
        let quelle = alterOrdner ?? standardQuelle(dateiverwaltung)

        let name = Datenbestand.speichername
        let hauptdatei = ziel.appending(path: "\(name).store")
        // Am neuen Ort ist schon etwas – dann ist der Umzug entweder gelaufen
        // oder es wurde bereits ohne Sandbox gearbeitet.
        guard !dateiverwaltung.fileExists(atPath: hauptdatei.path) else { return false }
        guard dateiverwaltung.fileExists(atPath: quelle.appending(path: "\(name).store").path) else {
            return false
        }

        do {
            try dateiverwaltung.createDirectory(at: ziel, withIntermediateDirectories: true)
            // SQLite besteht aus drei Dateien; ohne -wal fehlten die letzten Änderungen.
            for endung in ["", "-wal", "-shm"] {
                let von = quelle.appending(path: "\(name).store\(endung)")
                let nach = ziel.appending(path: "\(name).store\(endung)")
                guard dateiverwaltung.fileExists(atPath: von.path) else { continue }
                try dateiverwaltung.copyItem(at: von, to: nach)
            }
            return true
        } catch {
            // Lieber leer starten als gar nicht starten – der alte Bestand bleibt unberührt.
            return false
        }
    }

    private static func standardZiel(_ dateiverwaltung: FileManager) -> URL? {
        try? dateiverwaltung.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
    }

    private static func standardQuelle(_ dateiverwaltung: FileManager) -> URL {
        dateiverwaltung.homeDirectoryForCurrentUser
            .appending(path: "Library/Containers/\(containerkennung)/Data/Library/Application Support")
    }
}
