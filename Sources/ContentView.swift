import SwiftUI

struct ContentView: View {
    @State private var searchText = ""
    @State private var copied: Kaomoji?
    @State private var hovered: Kaomoji?
    @State private var copyGeneration = 0
    @FocusState private var searchFocused: Bool
    @AppStorage("recentKaomoji") private var recentsJSON = "[]"

    private var recentChars: [String] {
        get { (try? JSONDecoder().decode([String].self, from: Data(recentsJSON.utf8))) ?? [] }
        nonmutating set {
            if let data = try? JSONEncoder().encode(newValue) {
                recentsJSON = String(decoding: data, as: UTF8.self)
            }
        }
    }

    private var recents: [Kaomoji] {
        recentChars.compactMap { chars in allKaomoji.first { $0.chars == chars } }
    }

    /// nil when the search field is empty.
    private var results: [Kaomoji]? {
        let words = searchText.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !words.isEmpty else { return nil }
        return allKaomoji.filter { item in
            let haystack = ([item.name, item.category] + item.keywords)
                .joined(separator: " ")
                .lowercased()
            return words.allSatisfy { haystack.contains($0) }
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            TextField("Search: shrug, cat, flip…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .onSubmit {
                    if let first = results?.first {
                        copy(first)
                    }
                }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let results {
                        if results.isEmpty {
                            Text("No matches")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            section(
                                results.count == 1 ? "1 match" : "\(results.count) matches",
                                items: results
                            )
                        }
                    } else {
                        if !recents.isEmpty {
                            section("Recently used", items: recents)
                        }
                        ForEach(categoryOrder, id: \.self) { category in
                            section(category, items: allKaomoji.filter { $0.category == category })
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 4)
            }
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 360, height: 460)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchFocused = true
            }
        }
    }

    private func section(_ title: String, items: [Kaomoji]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(items) { item in
                    ChipButton(item: item) {
                        copy(item)
                    } onHover: { hovering in
                        if hovering {
                            hovered = item
                        } else if hovered == item {
                            hovered = nil
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let copied {
                Text(copied.chars).font(.system(size: 14))
                Text("copied").font(.caption).foregroundStyle(.secondary)
            } else if let hovered {
                Text(hovered.chars).font(.system(size: 14))
                Text(hovered.name).font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Click a kaomoji to copy it")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .keyboardShortcut("q")
        }
        .frame(height: 20)
    }

    private func copy(_ item: Kaomoji) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.chars, forType: .string)

        var chars = recentChars.filter { $0 != item.chars }
        chars.insert(item.chars, at: 0)
        recentChars = Array(chars.prefix(8))

        copied = item
        copyGeneration += 1
        let generation = copyGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copyGeneration == generation {
                copied = nil
            }
        }
    }
}

private struct ChipButton: View {
    let item: Kaomoji
    let action: () -> Void
    let onHover: (Bool) -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(item.chars)
                .font(.system(size: 13))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isHovering ? Color.primary.opacity(0.1) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(Color.primary.opacity(isHovering ? 0.35 : 0.15))
                )
        }
        .buttonStyle(.plain)
        .help(item.name)
        .onHover { hovering in
            isHovering = hovering
            onHover(hovering)
        }
    }
}
