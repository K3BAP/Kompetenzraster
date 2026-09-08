import Foundation

/// Wo die App nach neuen Fassungen sucht.
enum Veroeffentlichung {
    static let benutzer = "K3BAP"
    static let projekt = "Kompetenzraster"

    /// Die Seite, die beim Klick auf „Herunterladen“ im Browser aufgeht.
    static var releaseSeite: URL {
        URL(string: "https://github.com/\(benutzer)/\(projekt)/releases/tag/latest")!
    }

    /// Kleine Beschreibungsdatei, die neben dem ZIP am Release hängt.
    ///
    /// Bewusst der Anhang und nicht `api.github.com`: Anhänge unterliegen keiner
    /// Zugriffsbegrenzung, und es wird kein API-Aufruf mit Kopfzeilen nötig.
    static var manifestURL: URL {
        URL(string: "https://github.com/\(benutzer)/\(projekt)/releases/download/latest/latest.json")!
    }
}

/// Der Inhalt von `latest.json`, erzeugt beim Bauen der Veröffentlichung.
struct Versionsmanifest: Codable, Equatable, Sendable {
    var version: String
    var build: Int
    var veroeffentlichtAm: String?
    var download: String?
    /// Prüfsumme des ZIPs, hexadezimal. Ohne sie wird nicht installiert.
    var sha256: String?
    var groesse: Int?
    var hinweise: String?

    var downloadURL: URL? { download.flatMap(URL.init(string:)) }
}

/// Die eigene Fassung, wie sie in der Info.plist steht.
struct EigeneVersion: Equatable, Sendable {
    var version: String
    var build: Int

    static func ausBundle(_ bundle: Bundle = .main) -> EigeneVersion {
        EigeneVersion(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            build: Int(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0
        )
    }

    var beschriftung: String { "\(version) (Build \(build))" }
}

/// Vergleicht die eigene Fassung mit der veröffentlichten.
///
/// Verglichen wird die fortlaufende Build-Nummer, nicht die Versionszeichenkette:
/// Sie wird beim Bauen aus der Nummer des Arbeitslaufs gesetzt und wächst zuverlässig.
enum Versionsvergleich {
    static func istNeuer(_ manifest: Versionsmanifest, als eigene: EigeneVersion) -> Bool {
        manifest.build > eigene.build
    }
}

@MainActor
@Observable
final class Aktualisierungspruefer {
    enum Stand: Equatable {
        case ruhend
        case laeuft
        case aktuell
        case neueVersion(Versionsmanifest)
        case fehler(String)
    }

    static let shared = Aktualisierungspruefer()

    private(set) var stand: Stand = .ruhend
    /// Wird gesetzt, wenn die Lehrperson den Hinweis für diese Fassung weggeklickt hat.
    private(set) var ausgeblendet = false
    /// Ob die letzte Prüfung von Hand angestoßen wurde. Nur dann meldet die App auch,
    /// dass alles aktuell ist – beim stillen Start wäre das nur Lärm.
    private(set) var letztePruefungManuell = false
    private(set) var rueckmeldungAusgeblendet = false

    private var ausblendAufgabe: Task<Void, Never>?
    /// Wie lange die Bestätigung „alles aktuell“ stehen bleibt.
    var bestaetigungsdauer: Duration = .seconds(6)

    private let eigene: EigeneVersion
    private let laden: @Sendable (URL) async throws -> Data
    private let speicher: UserDefaults

    private static let schluesselLetztePruefung = "aktualisierung.letztePruefung"
    private static let schluesselUebersprungenerBuild = "aktualisierung.uebersprungenerBuild"

    init(
        eigene: EigeneVersion = .ausBundle(),
        speicher: UserDefaults = .standard,
        laden: @escaping @Sendable (URL) async throws -> Data = { url in
            var anfrage = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            anfrage.httpMethod = "GET"
            let (daten, antwort) = try await URLSession.shared.data(for: anfrage)
            guard let http = antwort as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            return daten
        }
    ) {
        self.eigene = eigene
        self.speicher = speicher
        self.laden = laden
    }

    var eigeneBeschriftung: String { eigene.beschriftung }

    /// Nur einmal am Tag von selbst nachsehen; ein Klick in den Einstellungen erzwingt es.
    func pruefe(erzwungen: Bool) async {
        if !erzwungen, let letzte = speicher.object(forKey: Self.schluesselLetztePruefung) as? Date,
           Date().timeIntervalSince(letzte) < 60 * 60 * 24 {
            return
        }

        letztePruefungManuell = erzwungen
        rueckmeldungAusgeblendet = false
        ausblendAufgabe?.cancel()
        stand = .laeuft
        do {
            let daten = try await laden(Veroeffentlichung.manifestURL)
            let manifest = try JSONDecoder().decode(Versionsmanifest.self, from: daten)
            speicher.set(Date(), forKey: Self.schluesselLetztePruefung)

            if Versionsvergleich.istNeuer(manifest, als: eigene) {
                // Eine weggeklickte Fassung bleibt weggeklickt – auch bei einer erzwungenen
                // Prüfung. Rückmeldung gibt dann der Stand in den Einstellungen, nicht der
                // Streifen über dem Fenster. Erst eine noch neuere Fassung meldet sich wieder.
                ausgeblendet = speicher.integer(forKey: Self.schluesselUebersprungenerBuild) >= manifest.build
                stand = .neueVersion(manifest)
            } else {
                stand = .aktuell
                blendeBestaetigungAus()
            }
        } catch {
            // Kein Netz ist kein Fehlerfall, über den die Lehrperson stolpern soll –
            // beim stillen Start bleibt er unsichtbar, nach einem Klick nicht.
            stand = .fehler(error.localizedDescription)
        }
    }

    /// Die Bestätigung verschwindet von selbst wieder; ein Fehler bleibt stehen.
    private func blendeBestaetigungAus() {
        ausblendAufgabe = Task { [weak self, dauer = bestaetigungsdauer] in
            try? await Task.sleep(for: dauer)
            guard !Task.isCancelled else { return }
            self?.rueckmeldungAusgeblendet = true
        }
    }

    /// Schließt die Rückmeldung zu einer von Hand angestoßenen Prüfung.
    func rueckmeldungSchliessen() {
        ausblendAufgabe?.cancel()
        rueckmeldungAusgeblendet = true
    }

    /// Blendet den Hinweis für genau diese Fassung aus.
    func spaeter() {
        if case .neueVersion(let manifest) = stand {
            speicher.set(manifest.build, forKey: Self.schluesselUebersprungenerBuild)
        }
        ausgeblendet = true
    }

    /// Der Streifen für eine neue Fassung.
    var zeigtHinweis: Bool {
        if case .neueVersion = stand { return !ausgeblendet }
        return false
    }

    /// Die Rückmeldung auf einen Klick in Menü oder Einstellungen: läuft, ist aktuell,
    /// hat nicht geklappt. Ohne sie sieht es so aus, als sei nichts passiert.
    var zeigtRueckmeldung: Bool {
        guard letztePruefungManuell, !rueckmeldungAusgeblendet else { return false }
        switch stand {
        case .laeuft, .aktuell, .fehler: return true
        case .ruhend, .neueVersion: return false
        }
    }

    /// Ob überhaupt etwas über dem Fenster liegt.
    var zeigtStreifen: Bool { zeigtHinweis || zeigtRueckmeldung }
}
