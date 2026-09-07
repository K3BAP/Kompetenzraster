import SwiftUI

/// Zeigt das Symbol einer Bewertungsstufe – gleich welcher Art.
struct BewertungsSymbol: View {
    var quelle: SymbolQuelle
    var farbe: Color
    var groesse: CGFloat = 18
    var gedaempft: Bool = false

    var body: some View {
        switch quelle {
        case .pflanze(let stufe):
            PflanzenSymbol(
                stufe: PflanzenStufe(rawValue: stufe) ?? .samen,
                farbe: farbe,
                gedaempft: gedaempft
            )
            .frame(width: groesse, height: groesse)

        case .sfSymbol(let name):
            Image(systemName: name)
                .font(.system(size: groesse * 0.8))
                .foregroundStyle(farbe.opacity(gedaempft ? 0.28 : 1))
                .frame(width: groesse, height: groesse)

        case .emoji(let zeichen):
            Text(zeichen)
                .font(.system(size: groesse * 0.85))
                .opacity(gedaempft ? 0.28 : 1)
                .frame(width: groesse, height: groesse)

        case .punkt:
            Circle()
                .fill(farbe.opacity(gedaempft ? 0.28 : 1))
                .frame(width: groesse * 0.62, height: groesse * 0.62)
                .frame(width: groesse, height: groesse)
        }
    }
}

extension Bewertungsstufe {
    var farbe: Color { Color(hex: farbeHex) }
}

/// Das Symbol einer konkreten Stufe, oder ein leerer Platzhalter, wenn nichts bewertet ist.
struct StufenSymbol: View {
    var stufe: Bewertungsstufe?
    var groesse: CGFloat = 18
    /// Wird gezeigt, wenn `stufe` nil ist – als blasser Umriss der niedrigsten Stufe.
    var platzhalter: SymbolQuelle = .punkt

    var body: some View {
        if let stufe {
            BewertungsSymbol(quelle: stufe.symbol, farbe: stufe.farbe, groesse: groesse)
                .help(stufe.name)
        } else {
            BewertungsSymbol(quelle: platzhalter, farbe: .secondary, groesse: groesse, gedaempft: true)
                .help("noch nicht bewertet")
        }
    }
}
