import SwiftUI

/// Ein Feld zum Ankreuzen: Klick setzt, Klick auf das gesetzte Feld nimmt zurück.
///
/// Der Kompetenzbogen und der Mitarbeitsbogen benutzen dasselbe Feld, damit beide sich gleich
/// anfühlen – aus demselben Grund, aus dem alle Stufensymbole durch ``BewertungsSymbol`` laufen.
/// Was im Feld steht, gibt die aufrufende Ansicht vor; `gewaehlt` wird durchgereicht, damit das
/// Symbol im gesetzten Zustand größer und kräftiger sein kann.
struct Ankreuzfeld<Inhalt: View>: View {
    let farbe: Color
    let gewaehlt: Bool
    let breite: CGFloat
    var hoehe: CGFloat = 34
    let beschriftung: String
    let tippen: () -> Void
    @ViewBuilder let inhalt: (Bool) -> Inhalt

    @State private var ueberfahren = false

    var body: some View {
        Button(action: tippen) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(gewaehlt ? farbe.opacity(0.18) : (ueberfahren ? farbe.opacity(0.09) : .clear))
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        gewaehlt ? farbe : farbe.opacity(ueberfahren ? 0.45 : 0),
                        lineWidth: 1.5
                    )
                inhalt(gewaehlt)
            }
            .frame(width: breite - 8, height: hoehe)
            .frame(width: breite)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { ueberfahren = $0 }
        .help(beschriftung)
        .accessibilityLabel(beschriftung)
        .accessibilityAddTraits(gewaehlt ? [.isSelected] : [])
    }
}
