import Foundation
import SwiftData

/// Einzelner Einstellungsdatensatz der App.
@Model
final class AppEinstellungen {
    var id: UUID = UUID()
    var schulname: String = ""
    var sperreAktiv: Bool = false
    var ersteinrichtungAbgeschlossen: Bool = false
    var letztesBackup: Date?
    var aktivesSchuljahr: String = ""
    var aktualisierungenPruefen: Bool = true

    init(
        id: UUID = UUID(),
        schulname: String = "",
        sperreAktiv: Bool = false,
        ersteinrichtungAbgeschlossen: Bool = false,
        letztesBackup: Date? = nil,
        aktivesSchuljahr: String = Schuljahr.aktuell,
        aktualisierungenPruefen: Bool = true
    ) {
        self.id = id
        self.schulname = schulname
        self.sperreAktiv = sperreAktiv
        self.ersteinrichtungAbgeschlossen = ersteinrichtungAbgeschlossen
        self.letztesBackup = letztesBackup
        self.aktivesSchuljahr = aktivesSchuljahr
        self.aktualisierungenPruefen = aktualisierungenPruefen
    }
}
