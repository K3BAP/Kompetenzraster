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
    var hinweise: String?
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
            }
        } catch {
            // Kein Netz ist kein Fehlerfall, über den die Lehrperson stolpern soll.
            stand = .fehler(error.localizedDescription)
        }
    }

    /// Blendet den Hinweis für genau diese Fassung aus.
    func spaeter() {
        if case .neueVersion(let manifest) = stand {
            speicher.set(manifest.build, forKey: Self.schluesselUebersprungenerBuild)
        }
        ausgeblendet = true
    }

    var zeigtHinweis: Bool {
        if case .neueVersion = stand { return !ausgeblendet }
        return false
    }
}
