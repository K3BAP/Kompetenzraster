import Foundation

/// Der Inhalt einer `.kompetenzsicherung`-Datei.
///
/// Bewusst eine einzige, gut lesbare JSON-Datei: Ohne Server gibt es kein „Konto wiederherstellen“,
/// deshalb soll eine Sicherung auch dann noch verständlich sein, wenn diese App einmal nicht mehr läuft.
/// Alle Beziehungen laufen über UUIDs in flachen Listen, damit der Import unabhängig von der
/// Reihenfolge und wiederholbar ist.
struct BackupDatei: Codable, Sendable {
    /// 2: seit den Mitarbeitsstunden. Ältere Fassungen der App weisen neuere Dateien ab;
    /// Sicherungen im Format 1 lassen sich weiterhin einspielen.
    static let aktuelleSchemaVersion = 2

    var schemaVersion: Int = BackupDatei.aktuelleSchemaVersion
    var appVersion: String = ""
    var exportiertAm: Date = Date()
    var zaehler: BackupZaehler = BackupZaehler()
    var verschluesselt: Bool = false
    /// Bei unverschlüsselten Sicherungen gesetzt.
    var daten: BackupDaten?
    /// Bei verschlüsselten Sicherungen gesetzt; enthält ``BackupDaten`` als Geheimtext.
    var tresor: BackupTresor?
}

/// Bleibt auch bei verschlüsselten Sicherungen im Klartext, damit vor der Passwortabfrage
/// eine Vorschau möglich ist.
struct BackupZaehler: Codable, Sendable {
    var klassen = 0
    var schueler = 0
    var raster = 0
    var kompetenzen = 0
    var eintraege = 0
    /// Seit Format 2; bei älteren Sicherungen nicht vorhanden.
    var mitarbeitsstunden: Int?
}

struct BackupTresor: Codable, Sendable {
    var kdf = "PBKDF2-SHA256"
    var iterationen = 310_000
    var salt = ""
    var nonce = ""
    var ciphertext = ""
    var tag = ""
}

struct BackupDaten: Codable, Sendable {
    var klassen: [KlasseDTO] = []
    var schueler: [SchuelerDTO] = []
    var skalen: [SkalaDTO] = []
    var stufen: [StufeDTO] = []
    var raster: [RasterDTO] = []
    var kompetenzen: [KompetenzDTO] = []
    var eintraege: [EintragDTO] = []
    var einstellungen: EinstellungenDTO?
    // Seit Format 2. Optional, weil die synthetisierte `Decodable` bei fehlenden Schlüsseln
    // nicht auf Standardwerte zurückfällt – Sicherungen im Format 1 müssen lesbar bleiben.
    var mitarbeitsstunden: [MitarbeitsstundeDTO]?
    var mitarbeitseintraege: [MitarbeitseintragDTO]?
}

struct KlasseDTO: Codable, Sendable {
    var id: UUID
    var name: String
    var jahrgangsstufe: Int
    var schuljahr: String
    var notiz: String
    var erstelltAm: Date
    var sortIndex: Int
    /// Zugeordnete Raster.
    var rasterIDs: [UUID]
}

struct SchuelerDTO: Codable, Sendable {
    var id: UUID
    var vorname: String
    var nachname: String
    var kuerzel: String
    var geburtsdatum: Date?
    var notiz: String
    var sortIndex: Int
    var erstelltAm: Date
    var klasseID: UUID?
}

struct SkalaDTO: Codable, Sendable {
    var id: UUID
    var name: String
    var erstelltAm: Date
}

struct StufeDTO: Codable, Sendable {
    var id: UUID
    var name: String
    var wert: Int
    var farbeHex: String
    var symbol: SymbolQuelle
    var skalaID: UUID?
}

struct RasterDTO: Codable, Sendable {
    var id: UUID
    var name: String
    var fach: String
    var quelle: String
    var istVorlage: Bool
    var erstelltAm: Date
    var sortIndex: Int
    var skalaID: UUID?
}

struct KompetenzDTO: Codable, Sendable {
    var id: UUID
    var titel: String
    var beschreibung: String
    var code: String
    var jahrgangsHinweis: String
    var sortIndex: Int
    var rasterID: UUID?
    var elternID: UUID?
}

struct EintragDTO: Codable, Sendable {
    var id: UUID
    var datum: Date
    var notiz: String
    var geaendertAm: Date
    var schuelerID: UUID?
    var kompetenzID: UUID?
    var stufeID: UUID?
}

struct MitarbeitsstundeDTO: Codable, Sendable {
    var id: UUID
    var datum: Date
    var fach: String
    var thema: String
    var erstelltAm: Date
    var klasseID: UUID?
}

struct MitarbeitseintragDTO: Codable, Sendable {
    var id: UUID
    var arbeitsverhalten: Int?
    var haeufigkeit: Int?
    var qualitaet: Int?
    var anwesend: Bool
    var notiz: String
    var geaendertAm: Date
    var stundeID: UUID?
    var schuelerID: UUID?
}

struct EinstellungenDTO: Codable, Sendable {
    var schulname: String
    var aktivesSchuljahr: String
}
