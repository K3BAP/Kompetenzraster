import Foundation
import SwiftData

/// Was in einer Stunde zu einem Kind beobachtet wurde.
///
/// Es gibt **genau einen Eintrag je Paar (Stunde, Schüler:in)**; alle Änderungen laufen über
/// ``Mitarbeitserfassung``. Jede Achse darf leer bleiben: In einer Stunde fällt selten zu jedem
/// Kind alles auf, und eine erzwungene Bewertung wäre eine erfundene.
@Model
final class Mitarbeitseintrag {
    var id: UUID = UUID()
    var arbeitsverhalten: Mitarbeitsstufe?
    var haeufigkeit: Mitarbeitsstufe?
    var qualitaet: Mitarbeitsstufe?
    /// Wer nicht da war, wird nicht beobachtet – und verdirbt auch die Quote nicht.
    var anwesend: Bool = true
    var notiz: String = ""
    var geaendertAm: Date = Date()

    var stunde: Mitarbeitsstunde?
    var schueler: SchuelerIn?

    init(
        id: UUID = UUID(),
        anwesend: Bool = true,
        notiz: String = "",
        geaendertAm: Date = Date()
    ) {
        self.id = id
        self.anwesend = anwesend
        self.notiz = notiz
        self.geaendertAm = geaendertAm
    }

    /// Zugriff über die Achse, damit Ansichten und Auswertung über die drei schleifen können,
    /// statt denselben Code dreimal zu tragen.
    subscript(achse: Mitarbeitsachse) -> Mitarbeitsstufe? {
        get {
            switch achse {
            case .arbeitsverhalten: arbeitsverhalten
            case .haeufigkeit: haeufigkeit
            case .qualitaet: qualitaet
            }
        }
        set {
            switch achse {
            case .arbeitsverhalten: arbeitsverhalten = newValue
            case .haeufigkeit: haeufigkeit = newValue
            case .qualitaet: qualitaet = newValue
            }
        }
    }

    /// Ein Eintrag ohne Beobachtung, ohne Notiz und mit anwesendem Kind trägt nichts.
    var istLeer: Bool {
        anwesend && notiz.isEmpty && Mitarbeitsachse.allCases.allSatisfy { self[$0] == nil }
    }
}
