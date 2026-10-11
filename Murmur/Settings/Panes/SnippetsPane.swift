import SwiftUI
import SwiftData
import MurmurKit

struct SnippetsPane: View {
    @Query(sort: \Snippet.createdAt, order: .reverse) private var snippets: [Snippet]
    @Environment(\.modelContext) private var context

    @State private var trigger = ""
    @State private var expansion = ""

    var body: some View {
        Form {
            Section("Add snippet") {
                TextField("When I say…", text: $trigger)
                TextField("Insert this…", text: $expansion, axis: .vertical)
                    .lineLimit(2...5)
                Button("Add") { add() }
                    .disabled(trigger.trimmingCharacters(in: .whitespaces).isEmpty || expansion.isEmpty)
            }

            Section("Your snippets") {
                if snippets.isEmpty {
                    Text("Say a trigger phrase and Dictum expands it — emails, links, canned replies.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snippets) { snippet in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snippet.trigger).font(.headline)
                                Text(snippet.expansion).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                            // macOS has no swipe-to-delete, so expose an explicit
                            // remove control on each row.
                            Button(role: .destructive) { remove(snippet) } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help("Remove snippet")
                            .accessibilityLabel("Remove \(snippet.trigger)")
                        }
                        .contextMenu {
                            Button(role: .destructive) { remove(snippet) } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Snippets")
    }

    private func add() {
        let t = trigger.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !expansion.isEmpty else { return }
        context.insert(Snippet(trigger: t, expansion: expansion))
        try? context.save()
        trigger = ""
        expansion = ""
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets { context.delete(snippets[index]) }
        try? context.save()
    }

    private func remove(_ snippet: Snippet) {
        context.delete(snippet)
        try? context.save()
    }
}
