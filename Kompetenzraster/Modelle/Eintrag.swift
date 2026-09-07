import Foundation
import SwiftData

/// Die Bewertung einer Kompetenz für eine Schülerin oder einen Schüler.
///
/// Es gibt genau einen Eintrag je Paar (Schüler:in, Kompetenz); eine erneute Bewertung
/// aktualisiert ihn. Ein Verlauf mehrerer datierter Einträge ist bewusst nicht Teil dieser Version.
@Model
final class Eintrag {
    var id: UUID = UUID()
    var datum: Date = Date()
    var notiz: String = ""
    var geaendertAm: Date = Date()

    var schueler: SchuelerIn?
    var kompetenz: Kompetenz?
    var stufe: Bewertungsstufe?

    init(
        id: UUID = UUID(),
        datum: Date = Date(),
        notiz: String = "",
        geaendertAm: Date = Date()
    ) {
        self.id = id
        self.datum = datum
        self.notiz = notiz
        self.geaendertAm = geaendertAm
    }
}
