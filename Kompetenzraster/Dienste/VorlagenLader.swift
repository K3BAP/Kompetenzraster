import Foundation
import SwiftData

/// Aufbau der mitgelieferten Vorlagen-JSONs unter `Resources/Vorlagen`.
struct VorlagenDatei: Decodable, Sendable {
    var schemaVersion: Int
    var name: String
    var fach: String
    var quelle: String
    var hinweis: String?
    var kompetenzen: [VorlagenKnoten]

    /// Zahl aller Knoten im Baum – für die Vorschau in der Ersteinrichtung.
    var anzahlKompetenzen: Int {
        kompetenzen.reduce(0) { $0 + $1.anzahlImTeilbaum }
    }
}

struct VorlagenKnoten: Decodable, Sendable {
    var titel: String
    var beschreibung: String?
    var code: String?
    var jahrgangsHinweis: String?
    var kinder: [VorlagenKnoten]?

    var anzahlImTeilbaum: Int {
        1 + (kinder ?? []).reduce(0) { $0 + $1.anzahlImTeilbaum }
    }
}

/// Lädt die mitgelieferten Kompetenzraster aus dem App-Bundle in die Datenbank.
enum VorlagenLader {
    static let verfuegbareFaecher = ["Deutsch", "Mathematik", "Sachunterricht"]

    enum Fehler: LocalizedError {
        case nichtGefunden(String)

        var errorDescription: String? {
            switch self {
            case .nichtGefunden(let fach):
                "Die Vorlage für „\(fach)“ ist nicht im Programm enthalten."
            }
        }
    }

    static func datei(fach: String, bundle: Bundle = .main) throws -> VorlagenDatei {
        guard let url = bundle.url(forResource: fach, withExtension: "json") else {
            throw Fehler.nichtGefunden(fach)
        }
        return try JSONDecoder().decode(VorlagenDatei.self, from: Data(contentsOf: url))
    }

    /// Alle Vorlagen, die sich laden lassen – Grundlage der Auswahl im Willkommensfenster.
    static func alleVorlagen(bundle: Bundle = .main) -> [VorlagenDatei] {
        verfuegbareFaecher.compactMap { try? datei(fach: $0, bundle: bundle) }
    }

    /// Legt aus einer Vorlage ein neues Raster an und fügt es dem Kontext hinzu.
    @discardableResult
    static func einfuegen(
        _ vorlage: VorlagenDatei,
        in kontext: ModelContext,
        skala: Bewertungsskala
    ) -> Kompetenzraster {
        let raster = Kompetenzraster(
            name: vorlage.name,
            fach: vorlage.fach,
            quelle: [vorlage.quelle, vorlage.hinweis].compactMap { $0 }.joined(separator: "\n\n"),
            istVorlage: true
        )
        raster.skala = skala
        kontext.insert(raster)

        for (index, knoten) in vorlage.kompetenzen.enumerated() {
            baue(knoten, elternteil: nil, raster: raster, sortIndex: index, in: kontext)
        }
        return raster
    }

    private static func baue(
        _ knoten: VorlagenKnoten,
        elternteil: Kompetenz?,
        raster: Kompetenzraster,
        sortIndex: Int,
        in kontext: ModelContext
    ) {
        let kompetenz = Kompetenz(
            titel: knoten.titel,
            beschreibung: knoten.beschreibung ?? "",
            code: knoten.code ?? "",
            jahrgangsHinweis: knoten.jahrgangsHinweis ?? "",
            sortIndex: sortIndex
        )
        kontext.insert(kompetenz)
        kompetenz.raster = raster
        kompetenz.eltern = elternteil

        for (index, kind) in (knoten.kinder ?? []).enumerated() {
            baue(kind, elternteil: kompetenz, raster: raster, sortIndex: index, in: kontext)
        }
    }
}
