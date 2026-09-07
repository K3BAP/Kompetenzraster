import SwiftUI

/// Die vier Wachstumsstufen als eigene Vektorgrafik.
///
/// SF Symbols bieten keine durchgehende Serie vom Samenkorn bis zur Blüte, deshalb sind die
/// Stufen hier gezeichnet. Alles liegt in einem Einheitsquadrat und skaliert dadurch beliebig.
struct PflanzenSymbol: View {
    var stufe: PflanzenStufe
    var farbe: Color
    /// Blasse Darstellung für „noch nicht bewertet“.
    var gedaempft: Bool = false

    var body: some View {
        Canvas { kontext, groesse in
            let kante = min(groesse.width, groesse.height)
            let versatz = CGPoint(
                x: (groesse.width - kante) / 2,
                y: (groesse.height - kante) / 2
            )
            let zeichnung = Pflanzenzeichnung(stufe: stufe, kante: kante, versatz: versatz)

            let deckkraft = gedaempft ? 0.28 : 1.0
            kontext.stroke(
                zeichnung.stiel,
                with: .color(farbe.opacity(deckkraft)),
                style: StrokeStyle(lineWidth: kante * 0.07, lineCap: .round)
            )
            kontext.fill(zeichnung.fuellungen, with: .color(farbe.opacity(deckkraft)))
            if let kern = zeichnung.bluetenkern {
                kontext.fill(kern, with: .color(farbe.opacity(deckkraft * 0.45)))
            }
        }
        .accessibilityLabel(stufe.bezeichnung)
    }
}

/// Berechnet die Pfade einer Wachstumsstufe.
private struct Pflanzenzeichnung {
    let stufe: PflanzenStufe
    let kante: CGFloat
    let versatz: CGPoint

    private func punkt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: versatz.x + x * kante, y: versatz.y + y * kante)
    }

    private var boden: CGFloat { 0.9 }

    /// Wie hoch der Stiel je Stufe reicht.
    private var stielspitze: CGFloat {
        switch stufe {
        case .samen: boden
        case .keimling: 0.52
        case .pflanze: 0.3
        case .bluete: 0.36
        }
    }

    var stiel: Path {
        guard stufe != .samen else { return Path() }
        var pfad = Path()
        pfad.move(to: punkt(0.5, boden))
        pfad.addQuadCurve(
            to: punkt(0.5, stielspitze),
            control: punkt(0.42, (boden + stielspitze) / 2)
        )
        return pfad
    }

    /// Alle gefüllten Formen: Samenkorn, Blätter und Blütenblätter.
    var fuellungen: Path {
        var pfad = Path()
        switch stufe {
        case .samen:
            pfad.addEllipse(in: CGRect(
                x: punkt(0.33, 0).x, y: punkt(0, 0.5).y,
                width: kante * 0.34, height: kante * 0.44
            ))
        case .keimling:
            pfad.addPath(blatt(ansatz: punkt(0.5, 0.66), spitze: punkt(0.2, 0.5), bauch: 0.3))
            pfad.addPath(blatt(ansatz: punkt(0.5, 0.6), spitze: punkt(0.8, 0.46), bauch: -0.3))
        case .pflanze:
            pfad.addPath(blatt(ansatz: punkt(0.5, 0.72), spitze: punkt(0.14, 0.54), bauch: 0.34))
            pfad.addPath(blatt(ansatz: punkt(0.5, 0.64), spitze: punkt(0.86, 0.46), bauch: -0.34))
            pfad.addPath(blatt(ansatz: punkt(0.5, 0.48), spitze: punkt(0.22, 0.3), bauch: 0.3))
            pfad.addPath(blatt(ansatz: punkt(0.5, 0.42), spitze: punkt(0.78, 0.26), bauch: -0.3))
        case .bluete:
            pfad.addPath(blatt(ansatz: punkt(0.5, 0.74), spitze: punkt(0.16, 0.56), bauch: 0.34))
            pfad.addPath(blatt(ansatz: punkt(0.5, 0.66), spitze: punkt(0.84, 0.48), bauch: -0.34))
            pfad.addPath(bluete(mitte: punkt(0.5, 0.28), radius: kante * 0.2))
        }
        return pfad
    }

    var bluetenkern: Path? {
        guard stufe == .bluete else { return nil }
        let mitte = punkt(0.5, 0.28)
        let radius = kante * 0.075
        return Path(ellipseIn: CGRect(
            x: mitte.x - radius, y: mitte.y - radius,
            width: radius * 2, height: radius * 2
        ))
    }

    /// Ein Blatt als Linse aus zwei Kurven; `bauch` steuert die Wölbung und ihre Richtung.
    private func blatt(ansatz: CGPoint, spitze: CGPoint, bauch: CGFloat) -> Path {
        let dx = spitze.x - ansatz.x
        let dy = spitze.y - ansatz.y
        let mitte = CGPoint(x: (ansatz.x + spitze.x) / 2, y: (ansatz.y + spitze.y) / 2)
        // Senkrecht zur Blattachse, damit die Wölbung unabhängig von der Neigung stimmt.
        let normale = CGPoint(x: -dy * bauch, y: dx * bauch)

        var pfad = Path()
        pfad.move(to: ansatz)
        pfad.addQuadCurve(to: spitze, control: CGPoint(x: mitte.x + normale.x, y: mitte.y + normale.y))
        pfad.addQuadCurve(to: ansatz, control: CGPoint(x: mitte.x - normale.x, y: mitte.y - normale.y))
        pfad.closeSubpath()
        return pfad
    }

    private func bluete(mitte: CGPoint, radius: CGFloat) -> Path {
        var pfad = Path()
        let anzahl = 6
        for index in 0 ..< anzahl {
            let winkel = (Double(index) / Double(anzahl)) * 2 * .pi - .pi / 2
            let spitze = CGPoint(
                x: mitte.x + cos(winkel) * radius,
                y: mitte.y + sin(winkel) * radius
            )
            pfad.addPath(blatt(ansatz: mitte, spitze: spitze, bauch: 0.55))
        }
        return pfad
    }
}
