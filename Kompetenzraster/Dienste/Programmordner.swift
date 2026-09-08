import AppKit
import Foundation

/// Verschafft der App Schreibrecht auf den Ordner, in dem sie selbst liegt.
///
/// Die Sandbox verbietet das von sich aus. Statt sie aufzugeben, wird der Ordner einmalig
/// von der Lehrperson bestätigt und als sicherheitsbeschränktes Lesezeichen gemerkt –
/// danach läuft jede weitere Aktualisierung ohne Nachfrage, und die App bekommt trotzdem
/// keinen Zugriff auf irgendetwas anderes.
@MainActor
enum Programmordner {
    private static let schluessel = "aktualisierung.programmordner"

    /// Ob die App in einer Sandbox läuft. Nur dann braucht es überhaupt eine Freigabe.
    static var laeuftInSandbox: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    /// Das eigene Programm, z. B. `/Applications/Kompetenzraster.app`.
    static var eigenesProgramm: URL { Bundle.main.bundleURL }

    /// Der Ordner darüber – dort muss geschrieben werden, um das Programm zu ersetzen.
    static var ordner: URL { eigenesProgramm.deletingLastPathComponent() }

    /// Ein bereits erteiltes Recht, falls vorhanden und noch gültig.
    static func gemerkterZugriff(speicher: UserDefaults = .standard) -> URL? {
        guard laeuftInSandbox else { return ordner }
        guard let daten = speicher.data(forKey: schluessel) else { return nil }
        var veraltet = false
        guard let url = try? URL(
            resolvingBookmarkData: daten,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &veraltet
        ) else {
            speicher.removeObject(forKey: schluessel)
            return nil
        }
        // Nach einem Verschieben der App zeigt das Lesezeichen woandershin.
        guard url.standardizedFileURL == ordner.standardizedFileURL else {
            speicher.removeObject(forKey: schluessel)
            return nil
        }
        if veraltet { merke(url, speicher: speicher) }
        return url
    }

    /// Fragt einmalig nach dem Ordner. Gibt `nil` zurück, wenn abgebrochen wurde.
    static func erfrageZugriff(speicher: UserDefaults = .standard) -> URL? {
        let dialog = NSOpenPanel()
        dialog.message = """
        Damit sich Kompetenzraster selbst aktualisieren darf, bestätige bitte einmalig den \
        Ordner, in dem das Programm liegt. Danach wird nicht mehr gefragt.
        """
        dialog.prompt = "Zugriff erlauben"
        dialog.canChooseDirectories = true
        dialog.canChooseFiles = false
        dialog.allowsMultipleSelection = false
        dialog.canCreateDirectories = false
        dialog.directoryURL = ordner

        guard dialog.runModal() == .OK, let gewaehlt = dialog.url else { return nil }
        guard gewaehlt.standardizedFileURL == ordner.standardizedFileURL else { return nil }

        merke(gewaehlt, speicher: speicher)
        return gewaehlt
    }

    private static func merke(_ url: URL, speicher: UserDefaults) {
        guard let daten = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        speicher.set(daten, forKey: schluessel)
    }

    static func vergiss(speicher: UserDefaults = .standard) {
        speicher.removeObject(forKey: schluessel)
    }
}
