import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Zeichnet das 1024er Master-Symbol: eine Kompetenzblume mit unterschiedlich langen
// Blütenblättern auf grünem Grund – dasselbe Bild, das die App als Auswertung zeigt.

let kante = 1024.0
let rand = 100.0
let koerper = CGRect(x: rand, y: rand, width: kante - 2 * rand, height: kante - 2 * rand)
let eckradius = 185.0

let farbraum = CGColorSpaceCreateDeviceRGB()
guard let kontext = CGContext(
    data: nil, width: Int(kante), height: Int(kante),
    bitsPerComponent: 8, bytesPerRow: 0, space: farbraum,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Kontext konnte nicht angelegt werden") }

// Grundform
let form = CGPath(roundedRect: koerper, cornerWidth: eckradius, cornerHeight: eckradius, transform: nil)
kontext.saveGState()
kontext.addPath(form)
kontext.clip()

let verlauf = CGGradient(
    colorsSpace: farbraum,
    colors: [
        CGColor(red: 0.30, green: 0.68, blue: 0.40, alpha: 1),
        CGColor(red: 0.11, green: 0.40, blue: 0.24, alpha: 1),
    ] as CFArray,
    locations: [0, 1]
)!
kontext.drawLinearGradient(
    verlauf,
    start: CGPoint(x: koerper.minX, y: koerper.maxY),
    end: CGPoint(x: koerper.maxX, y: koerper.minY),
    options: []
)

/// Ein Blütenblatt als Linse aus zwei Kurven – wie in der App.
func bluetenblatt(mitte: CGPoint, winkel: Double, laenge: Double, innen: Double, oeffnung: Double) -> CGPath {
    func punkt(_ w: Double, _ abstand: Double) -> CGPoint {
        CGPoint(x: mitte.x + cos(w) * abstand, y: mitte.y + sin(w) * abstand)
    }
    let ansatz = punkt(winkel, innen)
    let spitze = punkt(winkel, laenge)
    let bauch = innen + (laenge - innen) * 0.72

    let pfad = CGMutablePath()
    pfad.move(to: ansatz)
    pfad.addQuadCurve(to: spitze, control: punkt(winkel - oeffnung / 2, bauch))
    pfad.addQuadCurve(to: ansatz, control: punkt(winkel + oeffnung / 2, bauch))
    pfad.closeSubpath()
    return pfad
}

let mitte = CGPoint(x: koerper.midX, y: koerper.midY)
let innen = 54.0
let maximum = 305.0
// Unterschiedlich weit entwickelte Kompetenzen – genau darum geht es in der App.
let anteile = [1.0, 0.64, 0.92, 0.52, 0.86, 0.70]
let scheibe = 2 * Double.pi / Double(anteile.count)

for (index, anteil) in anteile.enumerated() {
    let winkel = Double.pi / 2 - scheibe * Double(index)
    let blatt = bluetenblatt(
        mitte: mitte,
        winkel: winkel,
        laenge: innen + (maximum - innen) * anteil,
        innen: innen,
        oeffnung: scheibe * 0.78
    )
    kontext.addPath(blatt)
    kontext.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.90))
    kontext.fillPath()
}

// Blütenmitte
kontext.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
kontext.fillEllipse(in: CGRect(x: mitte.x - 42, y: mitte.y - 42, width: 84, height: 84))
kontext.setFillColor(CGColor(red: 0.11, green: 0.40, blue: 0.24, alpha: 1))
kontext.fillEllipse(in: CGRect(x: mitte.x - 17, y: mitte.y - 17, width: 34, height: 34))

kontext.restoreGState()

// Feine Kante, damit die Form auch auf hellem Grund sitzt
kontext.addPath(form)
kontext.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.12))
kontext.setLineWidth(3)
kontext.strokePath()

guard let bild = kontext.makeImage() else { fatalError("Bild konnte nicht erzeugt werden") }

let ziel = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appending(path: "Kompetenzraster/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png")
guard let senke = CGImageDestinationCreateWithURL(ziel as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Datei konnte nicht angelegt werden: \(ziel.path)")
}
CGImageDestinationAddImage(senke, bild, nil)
guard CGImageDestinationFinalize(senke) else { fatalError("PNG konnte nicht geschrieben werden") }
print("icon: \(ziel.path)")
