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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let results {
                    if results.isEmpty {
                        Text("No matches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            searchBar
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 6)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footerBar
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 12)
        }
        .frame(width: 360, height: 460)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                searchFocused = true
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField("Search: shrug, cat, flip…", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit {
                    if let first = results?.first {
                        copy(first)
                    }
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassBar()
    }

    private var footerBar: some View {
        HStack(spacing: 8) {
            if let copied {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
                Text(copied.chars).font(.system(size: 13))
                Text("copied").font(.caption).foregroundStyle(.secondary)
            } else if let hovered {
                Text(hovered.chars).font(.system(size: 13))
                Text(hovered.name).font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Click a kaomoji to copy it")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit Kaomoji Bar")
            .keyboardShortcut("q")
        }
        // Kaomoji glyphs have taller line boxes than the caption text.
        // A fixed height keeps the bar from resizing between states.
        .frame(height: 20)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassBar()
    }

    private func section(_ title: String, items: [Kaomoji]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(.tertiary)
            FlowLayout(spacing: 4) {
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
        }
        .buttonStyle(ChipButtonStyle(isHovering: isHovering))
        .help(item.name)
        .onHover { hovering in
            isHovering = hovering
            onHover(hovering)
        }
    }
}

/// Borderless capsule chip: invisible at rest, subtle fill on hover,
/// small scale-down while pressed.
private struct ChipButtonStyle: ButtonStyle {
    let isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                isHovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                in: Capsule()
            )
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    /// Liquid Glass on macOS 26, translucent material on older systems.
    @ViewBuilder fileprivate func glassBar() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: Capsule())
        } else {
            self.background(.regularMaterial, in: Capsule())
        }
    }
}
