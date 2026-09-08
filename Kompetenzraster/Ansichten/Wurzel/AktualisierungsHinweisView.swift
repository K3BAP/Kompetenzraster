import SwiftUI

/// Schmaler Streifen über dem Hauptfenster: meldet eine neue Fassung, führt die
/// Aktualisierung durch – und meldet ebenso, dass eine von Hand angestoßene Suche
/// gelaufen ist. Ohne das Letzte sähe ein Klick aus, als sei nichts passiert.
struct AktualisierungsHinweisView: View {
    let pruefer: Aktualisierungspruefer
    let installation: Selbstaktualisierung

    @Environment(\.openURL) private var oeffne

    /// Solange installiert wird oder das schiefging, hat die Installation Vorrang.
    private var zeigtInstallation: Bool {
        switch installation.phase {
        case .fehler, .neustartNoetig: true
        case .ruhend: false
        case .laedt, .prueft, .installiert, .startetNeu: true
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if zeigtInstallation {
                installationsinhalt
            } else {
                suchinhalt
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(untergrund)
        .overlay(alignment: .bottom) { Divider() }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Während der Aktualisierung

    @ViewBuilder
    private var installationsinhalt: some View {
        if case .neustartNoetig = installation.phase {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 1) {
                Text("Aktualisierung installiert")
                    .font(.callout.weight(.medium))
                Text("Beim nächsten Start läuft die neue Fassung.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Jetzt beenden") { NSApp.terminate(nil) }
                .buttonStyle(.borderedProminent)
        } else if case .fehler(let text) = installation.phase {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("Aktualisierung fehlgeschlagen")
                    .font(.callout.weight(.medium))
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button("Im Browser öffnen") { oeffne(Veroeffentlichung.releaseSeite) }
            Button {
                installation.zuruecksetzen()
            } label: {
                Image(systemName: "xmark").font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        } else {
            ProgressView().controlSize(.small)
            Text(installation.beschreibung ?? "Aktualisierung läuft …")
                .font(.callout.weight(.medium))
            if case .laedt(let anteil) = installation.phase {
                ProgressView(value: anteil)
                    .progressViewStyle(.linear)
                    .frame(width: 160)
            }
            Spacer(minLength: 8)
        }
    }

    // MARK: - Ergebnis der Suche

    @ViewBuilder
    private var suchinhalt: some View {
        zeichen
        VStack(alignment: .leading, spacing: 1) {
            Text(titel)
                .font(.callout.weight(.medium))
            if let unterzeile {
                Text(unterzeile)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        Spacer(minLength: 8)
        aktionen
    }

    @ViewBuilder
    private var zeichen: some View {
        switch pruefer.stand {
        case .laeuft:
            ProgressView().controlSize(.small)
        case .aktuell:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .fehler:
            Image(systemName: "wifi.exclamationmark").foregroundStyle(.orange)
        case .neueVersion:
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(.tint)
        case .ruhend:
            EmptyView()
        }
    }

    private var titel: String {
        switch pruefer.stand {
        case .laeuft: "Suche nach Aktualisierungen …"
        case .aktuell: "Kompetenzraster ist auf dem neuesten Stand"
        case .fehler: "Nach Aktualisierungen konnte nicht gesucht werden"
        case .neueVersion(let manifest): "Version \(manifest.version) ist verfügbar"
        case .ruhend: ""
        }
    }

    private var unterzeile: String? {
        switch pruefer.stand {
        case .laeuft, .ruhend:
            return nil
        case .aktuell:
            return "Installiert: \(pruefer.eigeneBeschriftung)"
        case .fehler(let text):
            return text
        case .neueVersion(let manifest):
            let hinweise = manifest.hinweise.flatMap { $0.isEmpty ? nil : $0 }
            return hinweise ?? "Installiert: \(pruefer.eigeneBeschriftung)"
        }
    }

    /// Nur was eine Handlung nahelegt, bekommt Farbe. Die Bestätigung bleibt neutral –
    /// sonst sähe sie auf grünem Grund genauso aus wie ein verfügbares Update.
    private var untergrund: Color {
        if case .fehler = installation.phase { return .orange.opacity(0.12) }
        if case .neustartNoetig = installation.phase { return .secondary.opacity(0.10) }
        if installation.laeuft { return .accentColor.opacity(0.14) }
        switch pruefer.stand {
        case .neueVersion: return .accentColor.opacity(0.14)
        case .fehler: return .orange.opacity(0.12)
        case .aktuell, .laeuft, .ruhend: return .secondary.opacity(0.10)
        }
    }

    @ViewBuilder
    private var aktionen: some View {
        switch pruefer.stand {
        case .neueVersion(let manifest):
            Button("Aktualisieren") {
                Task { await installation.aktualisiere(auf: manifest) }
            }
            .buttonStyle(.borderedProminent)
            Button("Später") { pruefer.spaeter() }
                .buttonStyle(.borderless)

        case .fehler:
            Button("Erneut versuchen") {
                Task { await pruefer.pruefe(erzwungen: true) }
            }
            schliessen

        case .aktuell:
            schliessen

        case .laeuft, .ruhend:
            EmptyView()
        }
    }

    private var schliessen: some View {
        Button {
            pruefer.rueckmeldungSchliessen()
        } label: {
            Image(systemName: "xmark")
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help("Ausblenden")
    }
}
