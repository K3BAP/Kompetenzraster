import AppKit
import Foundation
import Security

/// Lädt ein Paket und meldet dabei den Fortschritt zwischen 0 und 1.
typealias Paketlader = @Sendable (URL, @escaping @Sendable (Double) -> Void) async throws -> Data

/// Tauscht die laufende App gegen die veröffentlichte Fassung aus.
///
/// Der Ablauf ist bewusst kleinschrittig und bricht bei jedem Zweifel ab: geladen wird nur
/// über HTTPS, installiert nur, wenn die Prüfsumme aus der Veröffentlichung stimmt, das Paket
/// dieselbe Programmkennung trägt, tatsächlich neuer ist und seine Signatur unversehrt ist.
@MainActor
@Observable
final class Selbstaktualisierung {
    enum Phase: Equatable {
        case ruhend
        case laedt(Double)
        case prueft
        case installiert
        case startetNeu
        /// Ersetzt, aber der Neustart muss von Hand kommen.
        case neustartNoetig
        case fehler(String)
    }

    static let shared = Selbstaktualisierung()

    private(set) var phase: Phase = .ruhend

    private let eigene: EigeneVersion
    private let kennung: String
    private let lader: Paketlader
    /// Getrennt gehalten, damit Tests nicht in einen Dateidialog laufen.
    private let ordnerzugriff: @MainActor () -> URL?

    init(
        eigene: EigeneVersion = .ausBundle(),
        kennung: String = Bundle.main.bundleIdentifier ?? "",
        lader: @escaping Paketlader = Selbstaktualisierung.standardLader,
        ordnerzugriff: @escaping @MainActor () -> URL? = {
            Programmordner.gemerkterZugriff() ?? Programmordner.erfrageZugriff()
        }
    ) {
        self.eigene = eigene
        self.kennung = kennung
        self.lader = lader
        self.ordnerzugriff = ordnerzugriff
    }

    var laeuft: Bool {
        switch phase {
        case .laedt, .prueft, .installiert, .startetNeu: true
        case .ruhend, .neustartNoetig, .fehler: false
        }
    }

    var beschreibung: String? {
        switch phase {
        case .ruhend: nil
        case .laedt(let anteil): "Lädt … \(Int(anteil * 100)) %"
        case .prueft: "Wird geprüft …"
        case .installiert: "Wird installiert …"
        case .startetNeu: "Neustart …"
        case .neustartNoetig: "Bitte Kompetenzraster neu starten, damit die neue Fassung läuft."
        case .fehler(let text): text
        }
    }

    func zuruecksetzen() { phase = .ruhend }

    // MARK: - Ablauf

    func aktualisiere(auf manifest: Versionsmanifest) async {
        do {
            guard let adresse = manifest.downloadURL else { throw Installationsfehler.keineDownloadadresse }
            guard let erwartet = manifest.sha256, !erwartet.isEmpty else {
                throw Installationsfehler.pruefsummeFehlt
            }

            // Erst das Schreibrecht klären – niemand soll 2 MB laden und dann vor einem
            // Dialog stehen, den er wegklickt.
            guard let ordner = ordnerzugriff() else {
                throw Installationsfehler.ordnerNichtFreigegeben
            }

            phase = .laedt(0)
            let paket = try await lader(adresse) { [weak self] anteil in
                Task { @MainActor in
                    guard let self, case .laedt = self.phase else { return }
                    self.phase = .laedt(anteil)
                }
            }

            phase = .prueft
            guard Pruefsumme.stimmt(paket, mit: erwartet) else {
                throw Installationsfehler.pruefsummeFalsch
            }

            let eigenerBuild = eigene.build
            let erwarteteKennung = kennung
            let neuesProgramm = try await Task.detached {
                try Paketwerkzeug.entpackeUndPruefe(
                    paket: paket,
                    erwarteteKennung: erwarteteKennung,
                    eigenerBuild: eigenerBuild
                )
            }.value

            phase = .installiert
            try await installiereUndStarteNeu(neues: neuesProgramm, ordner: ordner)
        } catch let fehler as Installationsfehler {
            // Wenn nur der Neustart hakt, ist die neue Fassung trotzdem schon da –
            // das darf nicht wie ein gescheitertes Update aussehen.
            if case .neustartFehlgeschlagen = fehler {
                phase = .neustartNoetig
            } else {
                phase = .fehler(fehler.errorDescription ?? "\(fehler)")
            }
        } catch {
            phase = .fehler(
                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }
    }

    /// Ersetzt das laufende Programm und startet es neu.
    ///
    /// Das Ersetzen ist auf macOS erlaubt: der laufende Prozess behält seine bereits
    /// geladenen Seiten. Wichtig ist, dass der Ordnerzugriff **auch beim Starten** noch
    /// offen ist – ohne ihn darf die Sandbox die Datei nicht einmal öffnen.
    private func installiereUndStarteNeu(neues: URL, ordner: URL) async throws {
        let zugriff = ordner.startAccessingSecurityScopedResource()
        defer { if zugriff { ordner.stopAccessingSecurityScopedResource() } }

        let ziel = Programmordner.eigenesProgramm
        do {
            _ = try FileManager.default.replaceItemAt(ziel, withItemAt: neues)
        } catch {
            throw Installationsfehler.austauschFehlgeschlagen(error.localizedDescription)
        }

        // Beim Schreiben außerhalb des eigenen Containers legt die Sandbox das Merkmal
        // erneut an – ohne diesen zweiten Durchgang startet die neue Fassung nicht.
        Paketwerkzeug.entferneQuarantaene(unter: ziel)

        phase = .startetNeu
        try? await Task.sleep(for: .milliseconds(400))

        let konfiguration = NSWorkspace.OpenConfiguration()
        konfiguration.createsNewApplicationInstance = true
        konfiguration.activates = true
        do {
            _ = try await NSWorkspace.shared.openApplication(at: ziel, configuration: konfiguration)
        } catch {
            throw Installationsfehler.neustartFehlgeschlagen(error.localizedDescription)
        }

        try? await Task.sleep(for: .milliseconds(600))
        NSApp.terminate(nil)
    }

    // MARK: - Laden

    static let standardLader: Paketlader = { adresse, fortschritt in
        let anfrage = URLRequest(
            url: adresse, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 300
        )
        let beobachter = Fortschrittsbeobachter(fortschritt)
        let (datei, antwort) = try await URLSession.shared.download(for: anfrage, delegate: beobachter)
        defer { try? FileManager.default.removeItem(at: datei) }

        guard let http = antwort as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        fortschritt(1)
        return try Data(contentsOf: datei)
    }
}

/// Meldet den Ladefortschritt. Die Download-API schreibt gleich auf die Platte –
/// Byte für Byte über eine asynchrone Folge zu lesen war um Größenordnungen langsamer.
private final class Fortschrittsbeobachter: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let melde: @Sendable (Double) -> Void

    init(_ melde: @escaping @Sendable (Double) -> Void) { self.melde = melde }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        melde(min(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 1))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {}
}

/// Die Schritte, die außerhalb des Hauptstrangs laufen dürfen.
enum Paketwerkzeug {
    /// Entpackt das ZIP in einen eigenen Ordner und gibt das geprüfte Programm zurück.
    static func entpackeUndPruefe(
        paket: Data,
        erwarteteKennung: String,
        eigenerBuild: Int
    ) throws -> URL {
        let arbeitsordner = FileManager.default.temporaryDirectory
            .appending(path: "aktualisierung-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: arbeitsordner, withIntermediateDirectories: true)

        let zip = arbeitsordner.appending(path: "paket.zip")
        try paket.write(to: zip)

        let ziel = arbeitsordner.appending(path: "entpackt")
        try fuehreAus("/usr/bin/ditto", ["-x", "-k", zip.path, ziel.path])

        guard let programm = try FileManager.default
            .contentsOfDirectory(at: ziel, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" })
        else { throw Installationsfehler.keinProgrammImPaket }

        try Paketpruefung.pruefe(
            angaben: Paketpruefung.angaben(zu: programm),
            erwarteteKennung: erwarteteKennung,
            eigenerBuild: eigenerBuild
        )

        entferneQuarantaene(unter: programm)
        try pruefeSignatur(programm)
        return programm
    }

    /// Entfernt das Quarantäne-Merkmal, das macOS auf alles legt, was die App lädt.
    /// Bleibt es stehen, verweigert Gatekeeper der nur ad-hoc signierten Kopie den Start.
    ///
    /// Bewusst im eigenen Prozess und nicht über `/usr/bin/xattr`: ein Kindprozess erbt
    /// zwar die Sandbox, aber nicht den sicherheitsbeschränkten Zugriff auf den Zielordner.
    static func entferneQuarantaene(unter wurzel: URL) {
        entferneMerkmal(von: wurzel)
        guard let inhalt = FileManager.default.enumerator(
            at: wurzel, includingPropertiesForKeys: nil, options: []
        ) else { return }
        for fall in inhalt {
            if let url = fall as? URL { entferneMerkmal(von: url) }
        }
    }

    private static func entferneMerkmal(von url: URL) {
        url.withUnsafeFileSystemRepresentation { pfad in
            guard let pfad else { return }
            _ = removexattr(pfad, "com.apple.quarantine", XATTR_NOFOLLOW)
        }
    }

    /// Prüft, dass die Signatur des Pakets in sich stimmig ist – die Datei also
    /// nach dem Signieren nicht mehr angefasst wurde.
    private static func pruefeSignatur(_ programm: URL) throws {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(programm as CFURL, [], &code) == errSecSuccess,
              let code
        else { throw Installationsfehler.signaturUngueltig }

        guard SecStaticCodeCheckValidity(code, [], nil) == errSecSuccess else {
            throw Installationsfehler.signaturUngueltig
        }
    }

    @discardableResult
    private static func fuehreAus(_ werkzeug: String, _ argumente: [String]) throws -> String {
        let prozess = Process()
        prozess.executableURL = URL(fileURLWithPath: werkzeug)
        prozess.arguments = argumente
        let fehlerrohr = Pipe()
        prozess.standardError = fehlerrohr
        prozess.standardOutput = Pipe()

        do {
            try prozess.run()
        } catch {
            throw Installationsfehler.entpackenFehlgeschlagen(error.localizedDescription)
        }

        let fehlertext = String(
            decoding: fehlerrohr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self
        )
        prozess.waitUntilExit()

        guard prozess.terminationStatus == 0 else {
            throw Installationsfehler.entpackenFehlgeschlagen(
                fehlertext.isEmpty ? "Abbruch mit Code \(prozess.terminationStatus)" : fehlertext
            )
        }
        return fehlertext
    }
}
