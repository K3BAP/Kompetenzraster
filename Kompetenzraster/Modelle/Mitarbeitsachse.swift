import Foundation

/// Die drei Achsen, auf denen Mitarbeit beobachtet wird.
///
/// Anders als bei den Kompetenzen ist diese Skala **nicht** frei konfigurierbar: Die Achsen und
/// ihre vier Stufen stehen fest, damit das Eintragen nach der Stunde in wenigen Klicks erledigt
/// ist und die Zahlen über ein Schuljahr hinweg vergleichbar bleiben.
enum Mitarbeitsachse: String, Codable, CaseIterable, Identifiable, Sendable {
    case arbeitsverhalten
    case haeufigkeit
    case qualitaet

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .arbeitsverhalten: "Arbeitsverhalten"
        case .haeufigkeit: "Häufigkeit"
        case .qualitaet: "Qualität"
        }
    }

    /// Was die Achse beobachtet – als Erklärung am Spaltenkopf.
    var erklaerung: String {
        switch self {
        case .arbeitsverhalten: "Wie das Kind an der Arbeit bleibt"
        case .haeufigkeit: "Wie oft es sich eingebracht hat"
        case .qualitaet: "Was seine Beiträge getragen haben"
        }
    }

    /// Die Namen der vier Stufen in aufsteigender Reihenfolge.
    var stufennamen: [String] {
        switch self {
        case .arbeitsverhalten: ["stört", "braucht Anstöße", "arbeitet mit", "vorbildlich"]
        case .haeufigkeit: ["gar nicht", "selten", "oft", "sehr oft"]
        case .qualitaet: ["unsicher", "brauchbar", "gut", "herausragend"]
        }
    }

    func name(fuer stufe: Mitarbeitsstufe) -> String {
        stufennamen[stufe.rawValue]
    }
}

/// Eine der vier Beobachtungsstufen; der Rohwert geht als Ordinalzahl in die Mittelwerte ein.
enum Mitarbeitsstufe: Int, Codable, CaseIterable, Identifiable, Sendable {
    case kaum = 0
    case ansatzweise = 1
    case gut = 2
    case sehrGut = 3

    var id: Int { rawValue }

    /// Dieselbe Farbrampe wie die Standardskala der Kompetenzen – ein Haus, eine Sprache.
    var farbeHex: String {
        switch self {
        case .kaum: "#C8CBD0"
        case .ansatzweise: "#E0A02E"
        case .gut: "#7FB236"
        case .sehrGut: "#2E8B4A"
        }
    }

    /// Die Farbe, die zu einem (auch gebrochenen) Mittelwert am besten passt.
    static func fuer(mittelwert: Double) -> Mitarbeitsstufe {
        Mitarbeitsstufe(rawValue: Int(mittelwert.rounded())) ?? .kaum
    }
}
