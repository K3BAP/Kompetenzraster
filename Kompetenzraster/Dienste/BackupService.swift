import CommonCrypto
import CryptoKit
import Foundation
import SwiftData

/// Sichert den gesamten Datenbestand in eine Datei und liest ihn wieder ein.
@MainActor
enum BackupService {
    static let dateiendung = "kompetenzsicherung"

    enum Importmodus {
        /// Vorhandene Daten werden gelöscht, danach wird die Sicherung eingespielt.
        case ersetzen
        /// Die Sicherung wird über den Bestand gelegt; gleiche IDs werden aktualisiert.
        case zusammenfuehren
    }

    enum Fehler: LocalizedError, Equatable {
        case passwortFehlt
        case passwortFalsch
        case zukuenftigesSchema(Int)
        case beschaedigt

        var errorDescription: String? {
            switch self {
            case .passwortFehlt:
                "Diese Sicherung ist verschlüsselt. Bitte das Passwort eingeben."
            case .passwortFalsch:
                "Das Passwort passt nicht zu dieser Sicherung."
            case .zukuenftigesSchema(let version):
                "Die Sicherung wurde mit einer neueren Programmversion erstellt (Format \(version))."
            case .beschaedigt:
                "Die Sicherungsdatei ist unvollständig oder beschädigt."
            }
        }
    }

    // MARK: - Kodierung

    static func kodierer() -> JSONEncoder {
        let kodierer = JSONEncoder()
        kodierer.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        kodierer.dateEncodingStrategy = .iso8601
        return kodierer
    }

    static func dekodierer() -> JSONDecoder {
        let dekodierer = JSONDecoder()
        dekodierer.dateDecodingStrategy = .iso8601
        return dekodierer
    }

    // MARK: - Export

    /// Liest den Bestand aus und baut die Sicherungsdatei auf.
    static func export(aus kontext: ModelContext, passwort: String? = nil) throws -> Data {
        let daten = try sammle(aus: kontext)

        var datei = BackupDatei()
        datei.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        datei.zaehler = BackupZaehler(
            klassen: daten.klassen.count,
            schueler: daten.schueler.count,
            raster: daten.raster.count,
            kompetenzen: daten.kompetenzen.count,
            eintraege: daten.eintraege.count,
            mitarbeitsstunden: (daten.mitarbeitsstunden ?? []).count
        )

        if let passwort, !passwort.isEmpty {
            datei.verschluesselt = true
            datei.tresor = try verschluessele(daten, passwort: passwort)
        } else {
            datei.daten = daten
        }

        return try kodierer().encode(datei)
    }

    private static func sammle(aus kontext: ModelContext) throws -> BackupDaten {
        var daten = BackupDaten()

        daten.klassen = try kontext.fetch(FetchDescriptor<Klasse>()).map { klasse in
            KlasseDTO(
                id: klasse.id, name: klasse.name, jahrgangsstufe: klasse.jahrgangsstufe,
                schuljahr: klasse.schuljahr, notiz: klasse.notiz, erstelltAm: klasse.erstelltAm,
                sortIndex: klasse.sortIndex, rasterIDs: klasse.raster.map(\.id)
            )
        }
        daten.schueler = try kontext.fetch(FetchDescriptor<SchuelerIn>()).map { person in
            SchuelerDTO(
                id: person.id, vorname: person.vorname, nachname: person.nachname,
                kuerzel: person.kuerzel, geburtsdatum: person.geburtsdatum, notiz: person.notiz,
                sortIndex: person.sortIndex, erstelltAm: person.erstelltAm, klasseID: person.klasse?.id
            )
        }
        daten.skalen = try kontext.fetch(FetchDescriptor<Bewertungsskala>()).map {
            SkalaDTO(id: $0.id, name: $0.name, erstelltAm: $0.erstelltAm)
        }
        daten.stufen = try kontext.fetch(FetchDescriptor<Bewertungsstufe>()).map {
            StufeDTO(id: $0.id, name: $0.name, wert: $0.wert, farbeHex: $0.farbeHex,
                     symbol: $0.symbol, skalaID: $0.skala?.id)
        }
        daten.raster = try kontext.fetch(FetchDescriptor<Kompetenzraster>()).map {
            RasterDTO(id: $0.id, name: $0.name, fach: $0.fach, quelle: $0.quelle,
                      istVorlage: $0.istVorlage, erstelltAm: $0.erstelltAm,
                      sortIndex: $0.sortIndex, skalaID: $0.skala?.id)
        }
        daten.kompetenzen = try kontext.fetch(FetchDescriptor<Kompetenz>()).map {
            KompetenzDTO(id: $0.id, titel: $0.titel, beschreibung: $0.beschreibung, code: $0.code,
                         jahrgangsHinweis: $0.jahrgangsHinweis, sortIndex: $0.sortIndex,
                         rasterID: $0.raster?.id, elternID: $0.eltern?.id)
        }
        daten.eintraege = try kontext.fetch(FetchDescriptor<Eintrag>()).map {
            EintragDTO(id: $0.id, datum: $0.datum, notiz: $0.notiz, geaendertAm: $0.geaendertAm,
                       schuelerID: $0.schueler?.id, kompetenzID: $0.kompetenz?.id, stufeID: $0.stufe?.id)
        }
        daten.mitarbeitsstunden = try kontext.fetch(FetchDescriptor<Mitarbeitsstunde>()).map {
            MitarbeitsstundeDTO(id: $0.id, datum: $0.datum, fach: $0.fach, thema: $0.thema,
                                erstelltAm: $0.erstelltAm, klasseID: $0.klasse?.id)
        }
        daten.mitarbeitseintraege = try kontext.fetch(FetchDescriptor<Mitarbeitseintrag>()).map {
            MitarbeitseintragDTO(
                id: $0.id, arbeitsverhalten: $0.arbeitsverhalten?.rawValue,
                haeufigkeit: $0.haeufigkeit?.rawValue, qualitaet: $0.qualitaet?.rawValue,
                anwesend: $0.anwesend, notiz: $0.notiz, geaendertAm: $0.geaendertAm,
                stundeID: $0.stunde?.id, schuelerID: $0.schueler?.id
            )
        }
        if let einstellungen = try kontext.fetch(FetchDescriptor<AppEinstellungen>()).first {
            daten.einstellungen = EinstellungenDTO(
                schulname: einstellungen.schulname,
                aktivesSchuljahr: einstellungen.aktivesSchuljahr
            )
        }
        return daten
    }

    // MARK: - Import

    /// Liest die Hülle einer Sicherung, ohne sie zu entschlüsseln – für die Vorschau.
    static func vorschau(_ rohdaten: Data) throws -> BackupDatei {
        let datei: BackupDatei
        do {
            datei = try dekodierer().decode(BackupDatei.self, from: rohdaten)
        } catch {
            throw Fehler.beschaedigt
        }
        guard datei.schemaVersion <= BackupDatei.aktuelleSchemaVersion else {
            throw Fehler.zukuenftigesSchema(datei.schemaVersion)
        }
        return datei
    }

    static func importiere(
        _ rohdaten: Data,
        modus: Importmodus,
        passwort: String? = nil,
        in kontext: ModelContext
    ) throws {
        let datei = try vorschau(rohdaten)

        let daten: BackupDaten
        if datei.verschluesselt {
            guard let tresor = datei.tresor else { throw Fehler.beschaedigt }
            guard let passwort, !passwort.isEmpty else { throw Fehler.passwortFehlt }
            daten = try entschluessele(tresor, passwort: passwort)
        } else {
            guard let klartext = datei.daten else { throw Fehler.beschaedigt }
            daten = klartext
        }

        if modus == .ersetzen {
            try kontext.alleDatenLoeschen()
        }
        try schreibe(daten, in: kontext)
        try kontext.save()
    }

    /// Legt die Objekte an oder aktualisiert vorhandene mit gleicher ID und knüpft danach
    /// alle Beziehungen. Erst am Ende zu verknüpfen erspart eine Sortierung nach Abhängigkeiten.
    private static func schreibe(_ daten: BackupDaten, in kontext: ModelContext) throws {
        var skalen: [UUID: Bewertungsskala] = try vorhandene(in: kontext)
        var stufen: [UUID: Bewertungsstufe] = try vorhandene(in: kontext)
        var raster: [UUID: Kompetenzraster] = try vorhandene(in: kontext)
        var kompetenzen: [UUID: Kompetenz] = try vorhandene(in: kontext)
        var klassen: [UUID: Klasse] = try vorhandene(in: kontext)
        var personen: [UUID: SchuelerIn] = try vorhandene(in: kontext)
        var eintraege: [UUID: Eintrag] = try vorhandene(in: kontext)
        var stunden: [UUID: Mitarbeitsstunde] = try vorhandene(in: kontext)
        var mitarbeit: [UUID: Mitarbeitseintrag] = try vorhandene(in: kontext)

        for dto in daten.skalen {
            let objekt = skalen[dto.id] ?? {
                let neu = Bewertungsskala(id: dto.id); kontext.insert(neu); skalen[dto.id] = neu; return neu
            }()
            objekt.name = dto.name
            objekt.erstelltAm = dto.erstelltAm
        }
        for dto in daten.stufen {
            let objekt = stufen[dto.id] ?? {
                let neu = Bewertungsstufe(id: dto.id); kontext.insert(neu); stufen[dto.id] = neu; return neu
            }()
            objekt.name = dto.name
            objekt.wert = dto.wert
            objekt.farbeHex = dto.farbeHex
            objekt.symbol = dto.symbol
        }
        for dto in daten.raster {
            let objekt = raster[dto.id] ?? {
                let neu = Kompetenzraster(id: dto.id); kontext.insert(neu); raster[dto.id] = neu; return neu
            }()
            objekt.name = dto.name
            objekt.fach = dto.fach
            objekt.quelle = dto.quelle
            objekt.istVorlage = dto.istVorlage
            objekt.erstelltAm = dto.erstelltAm
            objekt.sortIndex = dto.sortIndex
        }
        for dto in daten.kompetenzen {
            let objekt = kompetenzen[dto.id] ?? {
                let neu = Kompetenz(id: dto.id); kontext.insert(neu); kompetenzen[dto.id] = neu; return neu
            }()
            objekt.titel = dto.titel
            objekt.beschreibung = dto.beschreibung
            objekt.code = dto.code
            objekt.jahrgangsHinweis = dto.jahrgangsHinweis
            objekt.sortIndex = dto.sortIndex
        }
        for dto in daten.klassen {
            let objekt = klassen[dto.id] ?? {
                let neu = Klasse(id: dto.id); kontext.insert(neu); klassen[dto.id] = neu; return neu
            }()
            objekt.name = dto.name
            objekt.jahrgangsstufe = dto.jahrgangsstufe
            objekt.schuljahr = dto.schuljahr
            objekt.notiz = dto.notiz
            objekt.erstelltAm = dto.erstelltAm
            objekt.sortIndex = dto.sortIndex
        }
        for dto in daten.schueler {
            let objekt = personen[dto.id] ?? {
                let neu = SchuelerIn(id: dto.id); kontext.insert(neu); personen[dto.id] = neu; return neu
            }()
            objekt.vorname = dto.vorname
            objekt.nachname = dto.nachname
            objekt.kuerzel = dto.kuerzel
            objekt.geburtsdatum = dto.geburtsdatum
            objekt.notiz = dto.notiz
            objekt.sortIndex = dto.sortIndex
            objekt.erstelltAm = dto.erstelltAm
        }
        for dto in daten.eintraege {
            let objekt = eintraege[dto.id] ?? {
                let neu = Eintrag(id: dto.id); kontext.insert(neu); eintraege[dto.id] = neu; return neu
            }()
            objekt.datum = dto.datum
            objekt.notiz = dto.notiz
            objekt.geaendertAm = dto.geaendertAm
        }

        for dto in daten.mitarbeitsstunden ?? [] {
            let objekt = stunden[dto.id] ?? {
                let neu = Mitarbeitsstunde(id: dto.id); kontext.insert(neu); stunden[dto.id] = neu; return neu
            }()
            objekt.datum = dto.datum
            objekt.fach = dto.fach
            objekt.thema = dto.thema
            objekt.erstelltAm = dto.erstelltAm
        }
        for dto in daten.mitarbeitseintraege ?? [] {
            let objekt = mitarbeit[dto.id] ?? {
                let neu = Mitarbeitseintrag(id: dto.id); kontext.insert(neu); mitarbeit[dto.id] = neu; return neu
            }()
            objekt.arbeitsverhalten = dto.arbeitsverhalten.flatMap(Mitarbeitsstufe.init(rawValue:))
            objekt.haeufigkeit = dto.haeufigkeit.flatMap(Mitarbeitsstufe.init(rawValue:))
            objekt.qualitaet = dto.qualitaet.flatMap(Mitarbeitsstufe.init(rawValue:))
            objekt.anwesend = dto.anwesend
            objekt.notiz = dto.notiz
            objekt.geaendertAm = dto.geaendertAm
        }

        // Beziehungen erst jetzt, wenn alle Objekte existieren.
        for dto in daten.stufen { stufen[dto.id]?.skala = dto.skalaID.flatMap { skalen[$0] } }
        for dto in daten.raster { raster[dto.id]?.skala = dto.skalaID.flatMap { skalen[$0] } }
        for dto in daten.kompetenzen {
            kompetenzen[dto.id]?.raster = dto.rasterID.flatMap { raster[$0] }
            kompetenzen[dto.id]?.eltern = dto.elternID.flatMap { kompetenzen[$0] }
        }
        for dto in daten.schueler { personen[dto.id]?.klasse = dto.klasseID.flatMap { klassen[$0] } }
        for dto in daten.klassen {
            klassen[dto.id]?.raster = dto.rasterIDs.compactMap { raster[$0] }
        }
        for dto in daten.eintraege {
            guard let eintrag = eintraege[dto.id] else { continue }
            eintrag.schueler = dto.schuelerID.flatMap { personen[$0] }
            eintrag.kompetenz = dto.kompetenzID.flatMap { kompetenzen[$0] }
            eintrag.stufe = dto.stufeID.flatMap { stufen[$0] }
        }

        for dto in daten.mitarbeitsstunden ?? [] {
            stunden[dto.id]?.klasse = dto.klasseID.flatMap { klassen[$0] }
        }
        for dto in daten.mitarbeitseintraege ?? [] {
            guard let eintrag = mitarbeit[dto.id] else { continue }
            eintrag.stunde = dto.stundeID.flatMap { stunden[$0] }
            eintrag.schueler = dto.schuelerID.flatMap { personen[$0] }
        }

        if let quelle = daten.einstellungen {
            let einstellungen = try kontext.einstellungen()
            einstellungen.schulname = quelle.schulname
            einstellungen.aktivesSchuljahr = quelle.aktivesSchuljahr
        }
    }

    private static func vorhandene<T: PersistentModel & Identifizierbar>(
        in kontext: ModelContext
    ) throws -> [UUID: T] {
        Dictionary(try kontext.fetch(FetchDescriptor<T>()).map { ($0.id, $0) }) { erster, _ in erster }
    }

    // MARK: - Verschlüsselung

    private static func verschluessele(_ daten: BackupDaten, passwort: String) throws -> BackupTresor {
        var tresor = BackupTresor()
        let salz = zufall(anzahl: 32)
        let schluessel = try schluessel(ausPasswort: passwort, salz: salz, iterationen: tresor.iterationen)
        let versiegelt = try AES.GCM.seal(kodierer().encode(daten), using: schluessel)

        tresor.salt = salz.base64EncodedString()
        tresor.nonce = Data(versiegelt.nonce).base64EncodedString()
        tresor.ciphertext = versiegelt.ciphertext.base64EncodedString()
        tresor.tag = versiegelt.tag.base64EncodedString()
        return tresor
    }

    private static func entschluessele(_ tresor: BackupTresor, passwort: String) throws -> BackupDaten {
        guard let salz = Data(base64Encoded: tresor.salt),
              let nonce = Data(base64Encoded: tresor.nonce),
              let geheimtext = Data(base64Encoded: tresor.ciphertext),
              let pruefsumme = Data(base64Encoded: tresor.tag)
        else { throw Fehler.beschaedigt }

        let schluessel = try schluessel(ausPasswort: passwort, salz: salz, iterationen: tresor.iterationen)
        do {
            let versiegelt = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: nonce),
                ciphertext: geheimtext,
                tag: pruefsumme
            )
            let klartext = try AES.GCM.open(versiegelt, using: schluessel)
            return try dekodierer().decode(BackupDaten.self, from: klartext)
        } catch {
            // AES-GCM erkennt ein falsches Passwort an der Prüfsumme.
            throw Fehler.passwortFalsch
        }
    }

    private static func zufall(anzahl: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: anzahl)
        _ = SecRandomCopyBytes(kSecRandomDefault, anzahl, &bytes)
        return Data(bytes)
    }

    /// PBKDF2-SHA256 – CryptoKit bringt keine passwortbasierte Ableitung mit,
    /// und HKDF hätte keinen Arbeitsfaktor gegen Rateangriffe.
    private static func schluessel(
        ausPasswort passwort: String,
        salz: Data,
        iterationen: Int
    ) throws -> SymmetricKey {
        let passwortBytes = Array(passwort.utf8)
        var abgeleitet = [UInt8](repeating: 0, count: 32)
        let status = salz.withUnsafeBytes { salzZeiger in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwortBytes.map { Int8(bitPattern: $0) }, passwortBytes.count,
                salzZeiger.bindMemory(to: UInt8.self).baseAddress, salz.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                UInt32(iterationen),
                &abgeleitet, abgeleitet.count
            )
        }
        guard status == kCCSuccess else { throw Fehler.beschaedigt }
        return SymmetricKey(data: Data(abgeleitet))
    }
}

/// Gemeinsamer Nenner der Modelle für den ID-basierten Abgleich beim Import.
protocol Identifizierbar {
    var id: UUID { get }
}

extension Klasse: Identifizierbar {}
extension SchuelerIn: Identifizierbar {}
extension Kompetenzraster: Identifizierbar {}
extension Kompetenz: Identifizierbar {}
extension Bewertungsskala: Identifizierbar {}
extension Bewertungsstufe: Identifizierbar {}
extension Eintrag: Identifizierbar {}
extension Mitarbeitsstunde: Identifizierbar {}
extension Mitarbeitseintrag: Identifizierbar {}
