import SwiftData
import SwiftUI

/// Der Bogen, den man nach der Stunde ausfüllt: Zeile je Kind, drei Achsen mit je vier Stufen.
///
/// Ein Klick setzt, ein Klick auf die gesetzte Stufe nimmt sie zurück – dieselbe Bedienung wie im
/// Kompetenzbogen. Nichts ist Pflicht: In einer Stunde fällt selten zu jedem Kind alles auf.
struct StundenErfassungView: View {
    @Bindable var klasse: Klasse
    let fach: String

    @Environment(\.modelContext) private var kontext
    @State private var stundeID: UUID?

    private var stunden: [Mitarbeitsstunde] { klasse.stunden(fach: fach) }
    private var stunde: Mitarbeitsstunde? {
        stunden.first { $0.id == stundeID } ?? stunden.first
    }

    var body: some View {
        Group {
            if klasse.schueler.isEmpty {
                LeerhinweisView(
                    titel: "Diese Klasse hat noch keine Kinder",
                    symbol: "person.badge.plus",
                    beschreibung: "Lege sie unter „Schüler:innen“ an, dann kannst du hier die Mitarbeit festhalten."
                )
            } else {
                HSplitView {
                    stundenliste
                        .frame(minWidth: 170, idealWidth: 200, maxWidth: 280)
                    if let stunde {
                        Stundenbogen(stunde: stunde, kinder: klasse.schuelerSortiert)
                            .frame(minWidth: 600)
                    } else {
                        LeerhinweisView(
                            titel: "Noch keine Stunde in \(fach)",
                            symbol: "calendar.badge.plus",
                            beschreibung: "Lege links eine Stunde an, dann erscheint hier die Klassenliste."
                        )
                        .frame(minWidth: 600)
                    }
                }
            }
        }
        .onAppear { if stundeID == nil { stundeID = stunden.first?.id } }
    }

    // MARK: - Stundenliste

    private var stundenliste: some View {
        VStack(spacing: 0) {
            List(selection: $stundeID) {
                ForEach(stunden) { eintragung in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(eintragung.datum, format: .dateTime.weekday(.abbreviated).day().month())
                            .font(.callout.weight(.medium))
                        if !eintragung.thema.isEmpty {
                            Text(eintragung.thema)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Text("\(eintragung.anzahlErfasst) von \(klasse.schueler.count) erfasst")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                    .tag(eintragung.id)
                }
            }
            .listStyle(.sidebar)

            Divider()
            HStack(spacing: 8) {
                Button {
                    legeStundeAn()
                } label: {
                    Label("Neue Stunde", systemImage: "plus")
                }
                Spacer()
                Button(role: .destructive) {
                    loescheStunde()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(stunde == nil)
                .help("Diese Stunde samt Beobachtungen löschen")
            }
            .padding(10)
        }
    }

    private func legeStundeAn() {
        let neue = Mitarbeitserfassung.neueStunde(fuer: klasse, fach: fach, in: kontext)
        stundeID = neue.id
    }

    private func loescheStunde() {
        guard let stunde else { return }
        stundeID = nil
        Mitarbeitserfassung.loesche(stunde, in: kontext)
    }
}

// MARK: - Der Bogen einer Stunde

private struct Stundenbogen: View {
    @Bindable var stunde: Mitarbeitsstunde
    let kinder: [SchuelerIn]

    @Environment(\.modelContext) private var kontext
    @State private var notizZiel: MitarbeitsnotizZiel?

    private let randAussen: CGFloat = 20
    private let anwesendBreite: CGFloat = 30
    private let feldBreite: CGFloat = 34
    private let gruppenAbstand: CGFloat = 14
    private let notizBreite: CGFloat = 28

    var body: some View {
        VStack(spacing: 0) {
            kopf
            Divider()
            spaltenkopf
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(kinder) { kind in
                        KindZeile(
                            stunde: stunde,
                            schueler: kind,
                            anwesendBreite: anwesendBreite,
                            feldBreite: feldBreite,
                            gruppenAbstand: gruppenAbstand,
                            notizBreite: notizBreite,
                            rand: randAussen,
                            notizOeffnen: {
                                notizZiel = MitarbeitsnotizZiel(stunde: stunde, schueler: kind)
                            }
                        )
                        Divider().padding(.leading, randAussen)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .sheet(item: $notizZiel) { ziel in
            MitarbeitsnotizView(stunde: ziel.stunde, schueler: ziel.schueler)
        }
    }

    private var kopf: some View {
        HStack(spacing: 12) {
            DatePicker("", selection: $stunde.datum, displayedComponents: .date)
                .labelsHidden()
                .fixedSize()
            TextField("Thema der Stunde", text: $stunde.thema)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
            Spacer()
            Text("\(stunde.anzahlErfasst) von \(kinder.count) erfasst")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, randAussen)
        .padding(.vertical, 10)
        .onChange(of: stunde.datum) { try? kontext.save() }
        .onChange(of: stunde.thema) { try? kontext.save() }
    }

    /// Über jeder Vierergruppe steht die Achse, darunter die vier Stufen als Legende.
    private var spaltenkopf: some View {
        HStack(spacing: 0) {
            Text("Kind")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            // Feste Höhe, sonst dehnt Color.clear die ganze Zeile.
            Color.clear.frame(width: anwesendBreite, height: 1)

            ForEach(Mitarbeitsachse.allCases) { achse in
                VStack(spacing: 3) {
                    Text(achse.titel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 2) {
                        ForEach(Mitarbeitsstufe.allCases) { stufe in
                            MitarbeitsSymbol(stufe: stufe, punktgroesse: 4)
                                .frame(width: feldBreite)
                                .help(achse.name(fuer: stufe))
                        }
                    }
                }
                .padding(.leading, gruppenAbstand)
                .help("\(achse.erklaerung): \(achse.stufennamen.joined(separator: " · "))")
            }
            Color.clear.frame(width: notizBreite + 10, height: 1)
        }
        .padding(.horizontal, randAussen)
        .padding(.vertical, 8)
        .background(.background)
    }
}

/// Eine Kindzeile mit Anwesenheit, den drei Achsen und der Notiz.
private struct KindZeile: View {
    let stunde: Mitarbeitsstunde
    let schueler: SchuelerIn
    let anwesendBreite: CGFloat
    let feldBreite: CGFloat
    let gruppenAbstand: CGFloat
    let notizBreite: CGFloat
    let rand: CGFloat
    let notizOeffnen: () -> Void

    @Environment(\.modelContext) private var kontext
    @State private var ueberfahren = false

    private var eintrag: Mitarbeitseintrag? { stunde.eintrag(fuer: schueler) }
    private var anwesend: Bool { eintrag?.anwesend ?? true }
    private var hatNotiz: Bool { !(eintrag?.notiz.isEmpty ?? true) }

    var body: some View {
        HStack(spacing: 0) {
            Text(schueler.vollerName.isEmpty ? schueler.kuerzel : schueler.vollerName)
                .font(.callout)
                .strikethrough(!anwesend, color: .secondary)
                .foregroundStyle(anwesend ? .primary : .secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 8)

            Button {
                Mitarbeitserfassung.setzeAnwesenheit(
                    !anwesend, fuer: schueler, in: stunde, kontext: kontext
                )
            } label: {
                Image(systemName: anwesend ? "person.fill" : "person.fill.xmark")
                    .foregroundStyle(anwesend ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.orange))
            }
            .buttonStyle(.plain)
            .frame(width: anwesendBreite)
            .help(anwesend ? "Als abwesend eintragen" : "War abwesend – zurücknehmen")

            ForEach(Mitarbeitsachse.allCases) { achse in
                HStack(spacing: 2) {
                    ForEach(Mitarbeitsstufe.allCases) { stufe in
                        let gewaehlt = eintrag?[achse] == stufe
                        Ankreuzfeld(
                            farbe: stufe.farbe,
                            gewaehlt: gewaehlt,
                            breite: feldBreite,
                            hoehe: 28,
                            beschriftung: "\(achse.titel) – \(achse.name(fuer: stufe))",
                            tippen: { setze(gewaehlt ? nil : stufe, achse: achse) }
                        ) { gewaehlt in
                            MitarbeitsSymbol(
                                stufe: stufe,
                                punktgroesse: gewaehlt ? 5 : 4,
                                gedaempft: !gewaehlt
                            )
                        }
                    }
                }
                .padding(.leading, gruppenAbstand)
                .opacity(anwesend ? 1 : 0.35)
                .disabled(!anwesend)
            }

            Button(action: notizOeffnen) {
                Image(systemName: hatNotiz ? "text.bubble.fill" : "text.bubble")
                    .foregroundStyle(hatNotiz ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .buttonStyle(.plain)
            .frame(width: notizBreite)
            .padding(.leading, 10)
            .opacity(hatNotiz || ueberfahren ? 1 : 0)
            .help(eintrag?.notiz.isEmpty == false ? eintrag!.notiz : "Notiz zu dieser Stunde")
        }
        .padding(.horizontal, rand)
        .padding(.vertical, 5)
        .background(ueberfahren ? Color.primary.opacity(0.04) : .clear)
        .onHover { ueberfahren = $0 }
    }

    private func setze(_ stufe: Mitarbeitsstufe?, achse: Mitarbeitsachse) {
        withAnimation(.snappy(duration: 0.15)) {
            Mitarbeitserfassung.setze(
                stufe, achse: achse, fuer: schueler, in: stunde, kontext: kontext
            )
        }
    }
}

struct MitarbeitsnotizZiel: Identifiable {
    let stunde: Mitarbeitsstunde
    let schueler: SchuelerIn
    var id: String { "\(stunde.id)-\(schueler.id)" }
}

/// Kurze Notiz zu einem Kind in einer Stunde – der Beleg fürs Elterngespräch.
struct MitarbeitsnotizView: View {
    let stunde: Mitarbeitsstunde
    let schueler: SchuelerIn

    @Environment(\.dismiss) private var schliessen
    @Environment(\.modelContext) private var kontext
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(schueler.vollerName)
                .font(.headline)
            Text(stunde.datum.formatted(date: .long, time: .omitted)
                + (stunde.thema.isEmpty ? "" : " · \(stunde.thema)"))
                .font(.callout)
                .foregroundStyle(.secondary)

            TextEditor(text: $text)
                .font(.body)
                .frame(height: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))

            HStack {
                Button("Abbrechen", role: .cancel) { schliessen() }
                Spacer()
                Button("Sichern") {
                    Mitarbeitserfassung.setzeNotiz(
                        text, fuer: schueler, in: stunde, kontext: kontext
                    )
                    schliessen()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear { text = stunde.eintrag(fuer: schueler)?.notiz ?? "" }
    }
}
