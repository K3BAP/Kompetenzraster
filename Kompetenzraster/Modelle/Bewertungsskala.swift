import Foundation
import SwiftData

/// Die Spalten eines Kompetenzrasters: die Entwicklungsstufen.
@Model
final class Bewertungsskala {
    var id: UUID = UUID()
    var name: String = ""
    var erstelltAm: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Bewertungsstufe.skala)
    var stufen: [Bewertungsstufe] = []

    @Relationship(inverse: \Kompetenzraster.skala)
    var raster: [Kompetenzraster] = []

    init(id: UUID = UUID(), name: String = "", erstelltAm: Date = Date()) {
        self.id = id
        self.name = name
        self.erstelltAm = erstelltAm
    }

    var stufenSortiert: [Bewertungsstufe] {
        stufen.sorted { $0.wert < $1.wert }
    }

    var hoechsterWert: Int { stufenSortiert.last?.wert ?? 0 }

    /// Die Stufe, die einem (auch gebrochenen) Mittelwert am nächsten kommt.
    func stufe(fuerMittelwert mittelwert: Double) -> Bewertungsstufe? {
        let sortiert = stufenSortiert
        guard !sortiert.isEmpty else { return nil }
        let ziel = Int(mittelwert.rounded())
        return sortiert.min { abs($0.wert - ziel) < abs($1.wert - ziel) }
    }

    /// Der Standard: vier Wachstumsstufen, wie in Digidoo als Pflanze dargestellt.
    static func standard() -> Bewertungsskala {
        let skala = Bewertungsskala(name: "Pflanzenwachstum")
        let vorgaben: [(String, String)] = [
            ("noch nicht", "#C8CBD0"),
            ("ansatzweise", "#E0A02E"),
            ("überwiegend", "#7FB236"),
            ("sicher", "#2E8B4A"),
        ]
        skala.stufen = vorgaben.enumerated().map { index, vorgabe in
            Bewertungsstufe(
                name: vorgabe.0,
                wert: index,
                farbeHex: vorgabe.1,
                symbol: .pflanze(stufe: index)
            )
        }
        return skala
    }
}
