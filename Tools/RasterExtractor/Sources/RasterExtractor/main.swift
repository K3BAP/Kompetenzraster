import AppKit
import Foundation
import PDFKit
import Vision

// Entwicklungswerkzeug: legt den Text der drei RLP-Teilrahmenpläne offen, damit die
// Kompetenzvorlagen daraus kuratiert werden können. Läuft NICHT in der App.
//
//   swift run RasterExtractor            – alle drei Fächer
//   swift run RasterExtractor Deutsch    – nur ein Fach

struct Quelle {
    let fach: String
    let datei: String
    /// Manche Teilrahmenpläne liegen nur als Scan vor und brauchen Texterkennung.
    let brauchtOCR: Bool
}

let quellen = [
    Quelle(fach: "Deutsch", datei: "TRP_Deutsch.pdf", brauchtOCR: false),
    Quelle(fach: "Mathematik", datei: "TRP_Mathematik.pdf", brauchtOCR: false),
    Quelle(fach: "Sachunterricht", datei: "TRP_Sachunterricht.pdf", brauchtOCR: true),
]

let wurzel = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()   // RasterExtractor
    .deletingLastPathComponent()   // Sources
    .deletingLastPathComponent()   // Paketwurzel
let quellenOrdner = wurzel.appending(path: "Quellen")
let ausgabeOrdner = wurzel.appending(path: "Ausgabe")

/// Rendert eine Seite und erkennt den Text darauf.
func texterkennung(seite: PDFPage, skalierung: CGFloat = 2.5) -> String {
    let rahmen = seite.bounds(for: .mediaBox)
    let bild = NSImage(size: NSSize(width: rahmen.width * skalierung, height: rahmen.height * skalierung))
    bild.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: bild.size).fill()
    if let kontext = NSGraphicsContext.current?.cgContext {
        kontext.scaleBy(x: skalierung, y: skalierung)
        seite.draw(with: .mediaBox, to: kontext)
    }
    bild.unlockFocus()

    guard let tiff = bild.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let cgBild = bitmap.cgImage
    else { return "" }

    let anfrage = VNRecognizeTextRequest()
    anfrage.recognitionLevel = .accurate
    anfrage.recognitionLanguages = ["de-DE"]
    anfrage.usesLanguageCorrection = true
    try? VNImageRequestHandler(cgImage: cgBild, options: [:]).perform([anfrage])

    return (anfrage.results ?? [])
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
}

func verarbeite(_ quelle: Quelle) throws {
    let pfad = quellenOrdner.appending(path: quelle.datei)
    guard let dokument = PDFDocument(url: pfad) else {
        throw NSError(domain: "RasterExtractor", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "PDF nicht lesbar: \(pfad.path)"])
    }

    var zeilen: [String] = [
        "# \(quelle.fach)",
        "# Quelle: \(quelle.datei), \(dokument.pageCount) Seiten",
        "# Verfahren: \(quelle.brauchtOCR ? "Vision-Texterkennung (de-DE)" : "PDFKit-Textextraktion")",
        "",
    ]

    for index in 0 ..< dokument.pageCount {
        guard let seite = dokument.page(at: index) else { continue }
        let roh = seite.string ?? ""
        let text = quelle.brauchtOCR || roh.trimmingCharacters(in: .whitespacesAndNewlines).count < 50
            ? texterkennung(seite: seite)
            : roh
        zeilen.append("===== Seite \(index + 1) =====")
        zeilen.append(text)
        FileHandle.standardError.write(Data("\(quelle.fach): Seite \(index + 1)/\(dokument.pageCount)\r".utf8))
    }

    try FileManager.default.createDirectory(at: ausgabeOrdner, withIntermediateDirectories: true)
    let ziel = ausgabeOrdner.appending(path: "\(quelle.fach).txt")
    try zeilen.joined(separator: "\n").write(to: ziel, atomically: true, encoding: .utf8)
    print("\n\(quelle.fach) → \(ziel.path)")
}

let gewaehlt = CommandLine.arguments.dropFirst()
let zuVerarbeiten = gewaehlt.isEmpty
    ? quellen
    : quellen.filter { gewaehlt.contains($0.fach) }

for quelle in zuVerarbeiten {
    try verarbeite(quelle)
}
