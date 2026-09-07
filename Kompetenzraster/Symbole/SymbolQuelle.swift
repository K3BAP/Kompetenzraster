import Foundation

/// Woher das Symbol einer Bewertungsstufe stammt.
///
/// Digidoo zeigt den Entwicklungsstand nicht nur farblich, sondern als wachsende Pflanze.
/// Deshalb ist `.pflanze` der Standard; SF Symbols kennen keine durchgehende Wachstums-Serie
/// (es gibt `leaf` und `tree`, aber kein Samenkorn und keinen Keimling), darum wird sie in
/// ``PflanzenSymbol`` selbst gezeichnet.
enum SymbolQuelle: Codable, Hashable, Sendable {
    /// Eine der vier selbst gezeichneten Wachstumsstufen, siehe ``PflanzenStufe``.
    case pflanze(stufe: Int)
    /// Beliebiges SF Symbol, von der Lehrperson gewählt.
    case sfSymbol(name: String)
    /// Ein Emoji, z. B. 🌱.
    case emoji(String)
    /// Schlichter gefüllter Kreis – der reine Farbmodus.
    case punkt
}

extension SymbolQuelle {
    /// Kurzbezeichnung für Auswahlmenüs.
    var artBezeichnung: String {
        switch self {
        case .pflanze: "Pflanze"
        case .sfSymbol: "SF Symbol"
        case .emoji: "Emoji"
        case .punkt: "Punkt"
        }
    }
}

/// Die vier gezeichneten Wachstumsstufen in aufsteigender Reihenfolge.
enum PflanzenStufe: Int, CaseIterable, Sendable {
    case samen = 0
    case keimling = 1
    case pflanze = 2
    case bluete = 3

    var bezeichnung: String {
        switch self {
        case .samen: "Samenkorn"
        case .keimling: "Keimling"
        case .pflanze: "Pflanze"
        case .bluete: "Blüte"
        }
    }

    /// Bildet eine beliebige Stufenposition auf eine der vier Zeichnungen ab,
    /// damit auch Skalen mit mehr oder weniger als vier Stufen sinnvoll aussehen.
    static func fuer(position: Int, von anzahl: Int) -> PflanzenStufe {
        guard anzahl > 1 else { return .bluete }
        let anteil = Double(position) / Double(anzahl - 1)
        let index = Int((anteil * Double(allCases.count - 1)).rounded())
        return PflanzenStufe(rawValue: min(max(index, 0), allCases.count - 1)) ?? .samen
    }
}
