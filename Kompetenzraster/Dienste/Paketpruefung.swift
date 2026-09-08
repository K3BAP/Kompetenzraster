import CryptoKit
import Foundation

enum Pruefsumme {
    /// SHA-256 in Kleinbuchstaben, wie `shasum -a 256` sie ausgibt.
    static func sha256(_ daten: Data) -> String {
        SHA256.hash(data: daten).map { String(format: "%02x", $0) }.joined()
    }

    static func stimmt(_ daten: Data, mit erwartet: String) -> Bool {
        // Gegen Groß-/Kleinschreibung und Leerzeichen unempfindlich.
        let sauber = erwartet.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard sauber.count == 64 else { return false }
        return sha256(daten) == sauber
    }
}

enum Installationsfehler: LocalizedError, Equatable {
    case keineDownloadadresse
    case pruefsummeFehlt
    case pruefsummeFalsch
    case entpackenFehlgeschlagen(String)
    case keinProgrammImPaket
    case fremdesProgramm(String)
    case aeltereFassung
    case signaturUngueltig
    case ordnerNichtFreigegeben
    case austauschFehlgeschlagen(String)
    case neustartFehlgeschlagen(String)

    var errorDescription: String? {
        switch self {
        case .keineDownloadadresse:
            "Zu dieser Fassung ist keine Datei hinterlegt."
        case .pruefsummeFehlt:
            "Die Veröffentlichung nennt keine Prüfsumme – es wird nichts installiert."
        case .pruefsummeFalsch:
            "Die geladene Datei stimmt nicht mit der angegebenen Prüfsumme überein."
        case .entpackenFehlgeschlagen(let grund):
            "Das Paket ließ sich nicht entpacken: \(grund)"
        case .keinProgrammImPaket:
            "Im Paket steckt kein Programm."
        case .fremdesProgramm(let kennung):
            "Das Paket enthält ein anderes Programm (\(kennung))."
        case .aeltereFassung:
            "Das Paket enthält keine neuere Fassung."
        case .signaturUngueltig:
            "Die Signatur des Pakets ist beschädigt."
        case .ordnerNichtFreigegeben:
            "Ohne Zugriff auf den Programmordner kann sich Kompetenzraster nicht ersetzen."
        case .austauschFehlgeschlagen(let grund):
            "Das Programm ließ sich nicht ersetzen: \(grund)"
        case .neustartFehlgeschlagen(let grund):
            "Die neue Fassung ist installiert, ließ sich aber nicht selbst starten: \(grund)"
        }
    }
}

/// Prüft, ob ein entpacktes Bundle wirklich eine neuere Fassung dieser App ist.
enum Paketpruefung {
    struct Angaben: Equatable {
        var kennung: String
        var version: String
        var build: Int
    }

    static func angaben(zu programm: URL) -> Angaben? {
        let plist = programm.appending(path: "Contents/Info.plist")
        guard let daten = try? Data(contentsOf: plist),
              let inhalt = try? PropertyListSerialization.propertyList(from: daten, format: nil)
                  as? [String: Any],
              let kennung = inhalt["CFBundleIdentifier"] as? String
        else { return nil }

        return Angaben(
            kennung: kennung,
            version: inhalt["CFBundleShortVersionString"] as? String ?? "0",
            build: Int(inhalt["CFBundleVersion"] as? String ?? "0") ?? 0
        )
    }

    /// Wirft, wenn das Paket nicht zu dieser App gehört oder nicht neuer ist.
    static func pruefe(
        angaben: Angaben?,
        erwarteteKennung: String,
        eigenerBuild: Int
    ) throws {
        guard let angaben else { throw Installationsfehler.keinProgrammImPaket }
        guard angaben.kennung == erwarteteKennung else {
            throw Installationsfehler.fremdesProgramm(angaben.kennung)
        }
        guard angaben.build > eigenerBuild else {
            throw Installationsfehler.aeltereFassung
        }
    }
}
