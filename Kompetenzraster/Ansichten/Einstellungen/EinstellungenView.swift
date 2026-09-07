import SwiftData
import SwiftUI

struct EinstellungenView: View {
    var body: some View {
        TabView {
            AllgemeinEinstellungenView()
                .tabItem { Label("Allgemein", systemImage: "gearshape") }
            SkalenEinstellungenView()
                .tabItem { Label("Skalen", systemImage: "leaf") }
            SicherungEinstellungenView()
                .tabItem { Label("Sicherung", systemImage: "externaldrive") }
            SicherheitEinstellungenView()
                .tabItem { Label("Sicherheit", systemImage: "lock.shield") }
        }
        .frame(width: 720, height: 520)
    }
}

struct AllgemeinEinstellungenView: View {
    @Environment(\.modelContext) private var kontext
    @Query private var einstellungenListe: [AppEinstellungen]

    var body: some View {
        if let einstellungen = einstellungenListe.first {
            @Bindable var gebunden = einstellungen
            Form {
                Section("Schule") {
                    TextField("Name der Schule", text: $gebunden.schulname)
                    TextField("Aktuelles Schuljahr", text: $gebunden.aktivesSchuljahr)
                }
                Section("Über") {
                    LabeledContent("Notenskala", value: "Deutschland, 1–6")
                    LabeledContent("Daten", value: "ausschließlich auf diesem Mac")
                }
                Section("Herkunft der Vorlagen") {
                    ForEach(VorlagenLader.alleVorlagen(), id: \.fach) { vorlage in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vorlage.name).font(.callout.weight(.medium))
                            Text(vorlage.quelle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .formStyle(.grouped)
            .onChange(of: gebunden.schulname) { try? kontext.save() }
            .onChange(of: gebunden.aktivesSchuljahr) { try? kontext.save() }
        } else {
            ProgressView()
        }
    }
}

struct SicherheitEinstellungenView: View {
    @Environment(\.modelContext) private var kontext
    @Environment(\.openURL) private var oeffne
    @Query private var einstellungenListe: [AppEinstellungen]
    @State private var pruefer = Aktualisierungspruefer.shared

    @ViewBuilder
    private var aktualisierungsStand: some View {
        switch pruefer.stand {
        case .ruhend:
            EmptyView()
        case .laeuft:
            ProgressView().controlSize(.small)
        case .aktuell:
            Label("Auf dem neuesten Stand", systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.green)
        case .neueVersion(let manifest):
            Button("Version \(manifest.version) laden") { oeffne(Veroeffentlichung.releaseSeite) }
        case .fehler(let text):
            Label(text, systemImage: "wifi.exclamationmark")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    var body: some View {
        if let einstellungen = einstellungenListe.first {
            @Bindable var gebunden = einstellungen
            Form {
                Section {
                    Toggle("Kompetenzraster beim Start sperren", isOn: $gebunden.sperreAktiv)
                        .disabled(!AppSperre.verfuegbar)
                } header: {
                    Text("App-Sperre")
                } footer: {
                    Text(AppSperre.verfuegbar
                        ? "Beim Öffnen wird Touch ID oder dein Anmeldepasswort abgefragt."
                        : "Dieser Mac bietet keine Touch ID oder Passwortprüfung an.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Beim Start nach Aktualisierungen suchen", isOn: $gebunden.aktualisierungenPruefen)
                    LabeledContent("Installierte Fassung", value: pruefer.eigeneBeschriftung)
                    HStack {
                        Button("Jetzt suchen") {
                            Task { await pruefer.pruefe(erzwungen: true) }
                        }
                        .disabled(pruefer.stand == .laeuft)
                        Spacer()
                        aktualisierungsStand
                    }
                } header: {
                    Text("Aktualisierungen")
                } footer: {
                    Text("Höchstens einmal täglich wird eine kleine Versionsdatei von der Veröffentlichungsseite auf GitHub geladen. Dabei wird nichts gesendet – keine Klassen, keine Namen, keine Einträge.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Was das schützt – und was nicht") {
                    Text("""
                    Die Sperre verhindert den schnellen Blick auf einen offenen Laptop. Die Datenbank \
                    selbst liegt im geschützten Ordner der App und ist dann verschlüsselt, wenn \
                    FileVault für diesen Mac eingeschaltet ist.

                    Sicherungen, die du weitergibst oder auf einem Stick mitnimmst, solltest du mit \
                    einem Passwort verschlüsseln.
                    """)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .onChange(of: gebunden.sperreAktiv) { try? kontext.save() }
            .onChange(of: gebunden.aktualisierungenPruefen) { try? kontext.save() }
        } else {
            ProgressView()
        }
    }
}
