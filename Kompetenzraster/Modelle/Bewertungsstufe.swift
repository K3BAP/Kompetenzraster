import Foundation
import SwiftData

/// Eine einzelne Entwicklungsstufe, z. B. „überwiegend“.
@Model
final class Bewertungsstufe {
    var id: UUID = UUID()
    var name: String = ""
    /// Ordinalwert 0 … n. Bestimmt Reihenfolge und geht in Mittelwerte ein.
    var wert: Int = 0
    var farbeHex: String = "#888888"
    var symbol: SymbolQuelle = SymbolQuelle.punkt

    var skala: Bewertungsskala?

    @Relationship(inverse: \Eintrag.stufe)
    var eintraege: [Eintrag] = []

    init(
        id: UUID = UUID(),
        name: String = "",
        wert: Int = 0,
        farbeHex: String = "#888888",
        symbol: SymbolQuelle = .punkt
    ) {
        self.id = id
        self.name = name
        self.wert = wert
        self.farbeHex = farbeHex
        self.symbol = symbol
    }
}
