import Foundation
import SwiftData

@Model
final class Kompetenzraster {
    var id: UUID = UUID()
    var name: String = ""
    var fach: String = ""
    /// Herkunftsangabe, z. B. „Teilrahmenplan Deutsch, Rahmenplan Grundschule Rheinland-Pfalz“.
    var quelle: String = ""
    /// Mitgelieferte Vorlagen werden markiert, damit sie sich von eigenen Rastern unterscheiden.
    var istVorlage: Bool = false
    var erstelltAm: Date = Date()
    var sortIndex: Int = 0

    var skala: Bewertungsskala?

    /// Alle Kompetenzen des Rasters flach; der Baum ergibt sich aus ``Kompetenz/eltern``.
    @Relationship(deleteRule: .cascade, inverse: \Kompetenz.raster)
    var kompetenzen: [Kompetenz] = []

    @Relationship(inverse: \Klasse.raster)
    var klassen: [Klasse] = []

    init(
        id: UUID = UUID(),
        name: String = "",
        fach: String = "",
        quelle: String = "",
        istVorlage: Bool = false,
        erstelltAm: Date = Date(),
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.fach = fach
        self.quelle = quelle
        self.istVorlage = istVorlage
        self.erstelltAm = erstelltAm
        self.sortIndex = sortIndex
    }

    /// Die obersten Knoten (Kompetenzbereiche), in Anzeigereihenfolge.
    var wurzeln: [Kompetenz] {
        kompetenzen.filter { $0.eltern == nil }.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Kompetenzen ohne Kinder – nur diese werden bewertet.
    var blattKompetenzen: [Kompetenz] {
        kompetenzen.filter { $0.kinder.isEmpty }
    }
}
