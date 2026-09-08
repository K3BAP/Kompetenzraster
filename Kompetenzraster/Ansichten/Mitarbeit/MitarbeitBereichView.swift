import SwiftData
import SwiftUI

/// Der Rahmen um die Mitarbeit: Fachwahl und der Wechsel zwischen Erfassen und Auswerten.
///
/// Mitarbeit hängt am Fach, nicht am Kompetenzraster – in Sport oder Musik gibt es sie auch dann,
/// wenn dafür kein Raster angelegt ist.
struct MitarbeitBereichView: View {
    @Bindable var klasse: Klasse
    @Environment(\.modelContext) private var kontext

    private enum Unteransicht: String, CaseIterable, Identifiable {
        case erfassen = "Stunde erfassen"
        case verlauf = "Verlauf"
        var id: String { rawValue }
    }

    @State private var fach = ""
    @State private var unteransicht: Unteransicht = .erfassen
    @State private var fachAnlegen = false
    @State private var neuesFach = ""
    /// In dieser Sitzung ergänzte Fächer; dauerhaft werden sie mit der ersten Stunde.
    @State private var zusaetzlicheFaecher: [String] = []

    private var faecher: [String] {
        Set(klasse.faecher + zusaetzlicheFaecher).filter { !$0.isEmpty }.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            kopf
            Divider()
            if fach.isEmpty {
                LeerhinweisView(
                    titel: "Noch kein Fach für die Mitarbeit",
                    symbol: "text.badge.plus",
                    beschreibung: "Ordne der Klasse ein Kompetenzraster zu oder lege oben ein Fach an – danach kannst du nach jeder Stunde eintragen."
                )
            } else {
                switch unteransicht {
                case .erfassen: StundenErfassungView(klasse: klasse, fach: fach)
                case .verlauf: MitarbeitVerlaufView(klasse: klasse, fach: fach)
                }
            }
        }
        .onAppear { if fach.isEmpty { fach = faecher.first ?? "" } }
        .sheet(isPresented: $fachAnlegen) { fachSheet }
    }

    private var kopf: some View {
        HStack(spacing: 12) {
            if !faecher.isEmpty {
                Picker("Fach", selection: $fach) {
                    ForEach(faecher, id: \.self) { Text($0).tag($0) }
                }
                .fixedSize()
            }
            Button {
                neuesFach = ""
                fachAnlegen = true
            } label: {
                Label("Fach hinzufügen", systemImage: "plus")
            }
            .help("Ein Fach ohne Kompetenzraster ergänzen, z. B. Sport")

            Spacer()

            Picker("", selection: $unteransicht) {
                ForEach(Unteransicht.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var fachSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fach hinzufügen")
                .font(.headline)
            TextField("Fach", text: $neuesFach, prompt: Text("z. B. Sport"))
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
            HStack {
                Button("Abbrechen", role: .cancel) { fachAnlegen = false }
                Spacer()
                Button("Hinzufügen") {
                    let sauber = neuesFach.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !sauber.isEmpty else { return }
                    if !zusaetzlicheFaecher.contains(sauber) { zusaetzlicheFaecher.append(sauber) }
                    fach = sauber
                    fachAnlegen = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(neuesFach.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
