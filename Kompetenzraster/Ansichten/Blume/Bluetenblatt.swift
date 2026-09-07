import SwiftUI

/// Geometrie eines Blütenblatts der Kompetenzblume.
struct Bluetenblatt {
    var mitte: CGPoint
    /// Richtung der Blattachse im Bogenmaß; 0 zeigt nach rechts.
    var winkel: Double
    /// Abstand der Blattspitze von der Mitte.
    var laenge: CGFloat
    /// Öffnungswinkel des Blatts im Bogenmaß.
    var oeffnung: Double
    /// Wo das Blatt beginnt – lässt in der Mitte Platz für die Beschriftung.
    var innenradius: CGFloat

    private func punkt(winkel: Double, abstand: CGFloat) -> CGPoint {
        CGPoint(x: mitte.x + cos(winkel) * abstand, y: mitte.y + sin(winkel) * abstand)
    }

    var ansatz: CGPoint { punkt(winkel: winkel, abstand: innenradius) }
    var spitze: CGPoint { punkt(winkel: winkel, abstand: laenge) }

    /// Die Blattform aus zwei Kurven, die sich an Ansatz und Spitze treffen.
    var pfad: Path {
        let bauch = (laenge - innenradius) * 0.72
        var pfad = Path()
        pfad.move(to: ansatz)
        pfad.addQuadCurve(
            to: spitze,
            control: punkt(winkel: winkel - oeffnung / 2, abstand: innenradius + bauch)
        )
        pfad.addQuadCurve(
            to: ansatz,
            control: punkt(winkel: winkel + oeffnung / 2, abstand: innenradius + bauch)
        )
        pfad.closeSubpath()
        return pfad
    }

    /// Wo die Beschriftung sitzt – etwas außerhalb der längstmöglichen Blattspitze.
    func beschriftungsort(maximallaenge: CGFloat) -> CGPoint {
        punkt(winkel: winkel, abstand: maximallaenge + 18)
    }
}
