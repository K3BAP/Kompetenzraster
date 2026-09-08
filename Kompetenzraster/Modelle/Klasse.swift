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

    @Relationship(deleteRule: .cascade, inverse: \Mitarbeitsstunde.klasse)
    var mitarbeitsstunden: [Mitarbeitsstunde] = []

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

    /// Die Fächer, in denen bereits Mitarbeit festgehalten wurde, plus die der Raster.
    var faecher: [String] {
        let ausRastern = raster.map(\.fach)
        let ausStunden = mitarbeitsstunden.map(\.fach)
        return Set(ausRastern + ausStunden).filter { !$0.isEmpty }.sorted()
    }

    /// Alle Stunden eines Faches, jüngste zuerst.
    func stunden(fach: String) -> [Mitarbeitsstunde] {
        mitarbeitsstunden
            .filter { $0.fach == fach }
            .sorted { ($0.datum, $0.erstelltAm) > ($1.datum, $1.erstelltAm) }
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

    /// Das Jahr, in dem das Schuljahr „2025/26“ beginnt – hier 2025.
    static func startjahr(aus bezeichnung: String) -> Int? {
        Int(bezeichnung.prefix(while: \.isNumber))
    }

    static func bezeichnung(fuer datum: Date, kalender: Calendar = .current) -> String {
        let teile = kalender.dateComponents([.year, .month], from: datum)
        guard let jahr = teile.year, let monat = teile.month else { return "" }
        // Ein Schuljahr beginnt im August.
        let startjahr = monat >= 8 ? jahr : jahr - 1
        return "\(startjahr)/\(String(format: "%02d", (startjahr + 1) % 100))"
    }
}
