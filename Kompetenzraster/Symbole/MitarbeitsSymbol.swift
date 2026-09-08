import SwiftUI

/// Die Stufe einer Mitarbeitsachse als Füllstand aus vier Punkten.
///
/// Bewusst nicht die Pflanze der Kompetenzen: Mitarbeit ist eine Beobachtung einer einzelnen
/// Stunde, kein Entwicklungsstand. Zwei Sachen, zwei Bilder.
struct MitarbeitsSymbol: View {
    var stufe: Mitarbeitsstufe
    var punktgroesse: CGFloat = 7
    var gedaempft: Bool = false

    private var farbe: Color { Color(hex: stufe.farbeHex) }

    var body: some View {
        HStack(spacing: punktgroesse * 0.4) {
            ForEach(Mitarbeitsstufe.allCases) { punkt in
                Circle()
                    .fill(punkt.rawValue <= stufe.rawValue ? farbe : .clear)
                    .overlay {
                        Circle().strokeBorder(farbe.opacity(0.45), lineWidth: 1)
                    }
                    .frame(width: punktgroesse, height: punktgroesse)
            }
        }
        .opacity(gedaempft ? 0.35 : 1)
    }
}

extension Mitarbeitsstufe {
    var farbe: Color { Color(hex: farbeHex) }
}
