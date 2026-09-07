import Foundation
import SwiftData

@Model
final class Klasse {
    var id: UUID = UUID()
    var name: String = ""
    /// 1–4 in der Grundschule.
    var jahrgangsstufe: Int = 1
    var schuljahr: String = ""
    var notiz: String = ""
    var erstelltAm: Date = Date()
    var sortIndex: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \SchuelerIn.klasse)
    var schueler: [SchuelerIn] = []

    /// Welche Raster in dieser Klasse verwendet werden (n:m, ohne Löschweitergabe).
    var raster: [Kompetenzraster] = []

    init(
        id: UUID = UUID(),
        name: String = "",
        jahrgangsstufe: Int = 1,
        schuljahr: String = Schuljahr.aktuell,
        notiz: String = "",
        erstelltAm: Date = Date(),
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.jahrgangsstufe = jahrgangsstufe
        self.schuljahr = schuljahr
        self.notiz = notiz
        self.erstelltAm = erstelltAm
        self.sortIndex = sortIndex
    }

    /// Nach Nachname, dann Vorname – die im Klassenbuch übliche Reihenfolge.
    var schuelerSortiert: [SchuelerIn] {
        schueler.sorted { links, rechts in
            let a = (links.nachname, links.vorname)
            let b = (rechts.nachname, rechts.vorname)
            return a < b
        }
    }
}

/// Hilfen rund um die Schuljahresbezeichnung „2025/26“.
enum Schuljahr {
    static var aktuell: String { bezeichnung(fuer: Date()) }

    static func bezeichnung(fuer datum: Date, kalender: Calendar = .current) -> String {
        let teile = kalender.dateComponents([.year, .month], from: datum)
        guard let jahr = teile.year, let monat = teile.month else { return "" }
        // Ein Schuljahr beginnt im August.
        let startjahr = monat >= 8 ? jahr : jahr - 1
        return "\(startjahr)/\(String(format: "%02d", (startjahr + 1) % 100))"
    }
}
