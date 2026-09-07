import SwiftData
import SwiftUI

/// Blatt zum Anlegen und Bearbeiten einer Klasse.
struct KlasseBearbeitenView: View {
    @Bindable var klasse: Klasse
    var beimSichern: () -> Void = {}

    @Environment(\.dismiss) private var schliessen
    @Environment(\.modelContext) private var kontext

    private var nameFehlt: Bool {
        klasse.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Klasse")
                .font(.title2.weight(.semibold))
                .padding(.bottom, 12)

            Form {
                TextField("Bezeichnung", text: $klasse.name, prompt: Text("z. B. 3a"))
                Picker("Jahrgangsstufe", selection: $klasse.jahrgangsstufe) {
                    ForEach(1 ... 4, id: \.self) { stufe in
                        Text("\(stufe). Klasse").tag(stufe)
                    }
                }
                TextField("Schuljahr", text: $klasse.schuljahr)
                TextField("Notiz", text: $klasse.notiz, axis: .vertical)
                    .lineLimit(2 ... 4)
            }
            .formStyle(.grouped)

            HStack {
                Button("Abbrechen", role: .cancel) {
                    // Eine gerade erst angelegte, noch namenlose Klasse soll nicht zurückbleiben.
                    if nameFehlt { kontext.delete(klasse) }
                    schliessen()
                }
                Spacer()
                Button("Sichern") {
                    try? kontext.save()
                    beimSichern()
                    schliessen()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(nameFehlt)
            }
            .padding(.top, 12)
        }
        .padding(20)
        .frame(width: 420)
    }
}
