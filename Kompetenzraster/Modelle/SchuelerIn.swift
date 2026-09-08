import Foundation
import SwiftData

@Model
final class SchuelerIn {
    var id: UUID = UUID()
    var vorname: String = ""
    var nachname: String = ""
    /// Kürzel für platzsparende Darstellungen, z. B. in der Erfassungsmatrix.
    var kuerzel: String = ""
    var geburtsdatum: Date?
    var notiz: String = ""
    var sortIndex: Int = 0
    var erstelltAm: Date = Date()

    var klasse: Klasse?

    @Relationship(deleteRule: .cascade, inverse: \Eintrag.schueler)
    var eintraege: [Eintrag] = []

    @Relationship(deleteRule: .cascade, inverse: \Mitarbeitseintrag.schueler)
    var mitarbeit: [Mitarbeitseintrag] = []

    init(
        id: UUID = UUID(),
        vorname: String = "",
        nachname: String = "",
        kuerzel: String = "",
        geburtsdatum: Date? = nil,
        notiz: String = "",
        sortIndex: Int = 0,
        erstelltAm: Date = Date()
    ) {
        self.id = id
        self.vorname = vorname
        self.nachname = nachname
        self.kuerzel = kuerzel.isEmpty ? Self.kuerzelVorschlag(vorname: vorname, nachname: nachname) : kuerzel
        self.geburtsdatum = geburtsdatum
        self.notiz = notiz
        self.sortIndex = sortIndex
        self.erstelltAm = erstelltAm
    }

    var vollerName: String {
        [vorname, nachname].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// „Anna Müller“ → „Anna M.“ – eindeutig genug für die Klassenliste, aber kurz.
    var anzeigename: String {
        guard !nachname.isEmpty else { return vorname }
        guard !vorname.isEmpty else { return nachname }
        return "\(vorname) \(nachname.prefix(1))."
    }

    static func kuerzelVorschlag(vorname: String, nachname: String) -> String {
        let a = vorname.first.map(String.init) ?? ""
        let b = nachname.first.map(String.init) ?? ""
        return (a + b).uppercased()
    }
}
