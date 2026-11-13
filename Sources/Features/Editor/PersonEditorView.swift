import SwiftUI
import SwiftData

struct PersonEditorView: View {
    let person: Person?
    var onSaved: ((Person) -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.sortIndex) private var people: [Person]

    @State private var name = ""
    @State private var colorHex = Person.palette[0]
    @FocusState private var nameFocused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ZStack {
                DotGridBackground(glow: Color(hex: colorHex), glowCenter: UnitPoint(x: 0.5, y: 0.25), glowStrength: 0.22)

                ScrollView {
                    VStack(spacing: 26) {
                        Folder3DView(
                            title: trimmed.isEmpty ? tr("Name") : (trimmed.split(separator: " ").first.map(String.init) ?? trimmed),
                            count: person?.documents.count ?? 0,
                            symbols: [],
                            isFocused: true,
                            tint: Color(hex: colorHex)
                        )
                        .environment(\.layoutDirection, .leftToRight)
                        .tiltRotation(10)
                        .padding(.top, 20)
                        .animation(Motion.bouncy, value: trimmed)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(tr("NAME"))
                                .font(.system(size: 12, weight: .semibold)).kerning(Localizer.shared.isArabic ? 0 : 1.2)
                                .foregroundStyle(Theme.textSecondary)
                            TextField(tr("Full name"), text: $name)
                                .font(.system(size: 20))
                                .textContentType(.name)
                                .submitLabel(.done)
                                .focused($nameFocused)
                                .padding(.horizontal, 18)
                                .frame(height: 56)
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(tr("COLOR"))
                                .font(.system(size: 12, weight: .semibold)).kerning(Localizer.shared.isArabic ? 0 : 1.2)
                                .foregroundStyle(Theme.textSecondary)
                            GlassEffectContainer(spacing: 10) {
                                HStack(spacing: 10) {
                                    ForEach(Person.palette, id: \.self) { hex in
                                        Button {
                                            withAnimation(Motion.snappy) { colorHex = hex }
                                        } label: {
                                            Circle()
                                                .fill(Color(hex: hex))
                                                .frame(width: 26, height: 26)
                                                .overlay {
                                                    if hex == colorHex {
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 12, weight: .bold))
                                                            .foregroundStyle(.black)
                                                    }
                                                }
                                                .frame(width: 42, height: 42)
                                        }
                                        .buttonStyle(PressScaleStyle(scale: 0.88))
                                        .glassEffect(.regular.interactive(), in: .circle)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .foregroundStyle(.white)
                }
            }
            .navigationTitle(person == nil ? tr("New person") : tr("Edit person"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Cancel"), systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Save"), systemImage: "checkmark") { save() }
                        .disabled(trimmed.isEmpty)
                }
            }
            .sensoryFeedback(.selection, trigger: colorHex)
        }
        .onAppear {
            if let person {
                name = person.name
                colorHex = person.colorHex
            } else {
                colorHex = Person.palette[people.count % Person.palette.count]
                nameFocused = true
            }
        }
    }

    private func save() {
        if let person {
            person.name = trimmed
            person.colorHex = colorHex
            try? context.save()
            onSaved?(person)
        } else {
            let new = Person(name: trimmed, colorHex: colorHex, sortIndex: (people.map(\.sortIndex).max() ?? -1) + 1)
            context.insert(new)
            try? context.save()
            onSaved?(new)
        }
        dismiss()
    }
}
