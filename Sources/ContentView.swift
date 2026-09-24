import SwiftUI

private enum PickerTab: String {
    case all
    case favorites
}

struct ContentView: View {
    @State private var searchText = ""
    @State private var copied: Kaomoji?
    @State private var hovered: Kaomoji?
    @State private var copyGeneration = 0
    @State private var tab: PickerTab = .all
    /* Session-only reveal depth per expanded category. */
    @State private var revealCounts: [String: Int] = [:]
    @FocusState private var searchFocused: Bool
    @AppStorage("recentKaomoji") private var recentsJSON = "[]"
    @AppStorage("favoriteKaomoji") private var favoritesJSON = "[]"
    @AppStorage("expandedCategories") private var expandedJSON = "[\"Happy\"]"

    private let sectionInitial = 60
    private let sectionStep = 240

    /* --------------------------- stored lists --------------------------- */

    private func decodeList(_ json: String) -> [String] {
        (try? JSONDecoder().decode([String].self, from: Data(json.utf8))) ?? []
    }

    private func encodeList(_ list: [String]) -> String {
        (try? JSONEncoder().encode(list)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
    }

    private var recents: [Kaomoji] {
        decodeList(recentsJSON).compactMap { kaomojiByChars[$0] }
    }

    private var favorites: [Kaomoji] {
        decodeList(favoritesJSON).compactMap { kaomojiByChars[$0] }
    }

    private func toggleFavorite(_ item: Kaomoji) {
        var chars = decodeList(favoritesJSON)
        if let index = chars.firstIndex(of: item.chars) {
            chars.remove(at: index)
        } else {
            chars.append(item.chars)
        }
        favoritesJSON = encodeList(chars)
    }

    private func toggleExpanded(_ label: String) {
        var labels = Set(decodeList(expandedJSON))
        if labels.contains(label) {
            labels.remove(label)
        } else {
            labels.insert(label)
        }
        withAnimation(.snappy(duration: 0.2)) {
            expandedJSON = encodeList(labels.sorted())
        }
    }

    /* ------------------------------ search ------------------------------ */

    /// nil when the search field is empty.
    private var results: [Kaomoji]? {
        let words = searchText.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !words.isEmpty else { return nil }
        return searchIndex
            .filter { entry in words.allSatisfy { entry.haystack.contains($0) } }
            .map(\.item)
    }

    /* ------------------------------- body ------------------------------- */

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            header
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

    @ViewBuilder private var content: some View {
        let favoriteSet = Set(decodeList(favoritesJSON))
        if let results {
            if results.isEmpty {
                Text("No matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            } else {
                sectionHeader(
                    results.count == 1 ? "1 match" : "\(results.count) matches",
                    count: nil
                )
                chipGrid(Array(results.prefix(resultsLimit)), favorites: favoriteSet)
                if results.count > resultsLimit {
                    Text("Showing \(resultsLimit) of \(results.count). Refine the search to see the rest.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        } else if tab == .favorites {
            if favorites.isEmpty {
                emptyFavorites
            } else {
                sectionHeader("Favorites", count: favorites.count)
                chipGrid(favorites, favorites: favoriteSet)
            }
        } else {
            if !recents.isEmpty {
                sectionHeader("Recently used", count: nil)
                chipGrid(recents, favorites: favoriteSet)
            }
            ForEach(categorizedKaomoji, id: \.label) { category in
                collapsibleSection(category, favorites: favoriteSet)
            }
        }
    }

    private var emptyFavorites: some View {
        VStack(spacing: 8) {
            Image(systemName: "star")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text("No favorites yet")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("⌘-click a kaomoji, or right-click it and choose “Add to Favorites”.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    /* ------------------------------ header ------------------------------ */

    private var header: some View {
        VStack(spacing: 8) {
            searchBar
            if searchText.isEmpty {
                Picker("View", selection: $tab) {
                    Text("All").tag(PickerTab.all)
                    Text("Favorites").tag(PickerTab.favorites)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
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
                Text("Click to copy · ⌘-click to favorite")
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

    /* ----------------------------- sections ----------------------------- */

    private func sectionHeader(_ title: String, count: Int?) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(.tertiary)
            if let count {
                Text("\(count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
        }
    }

    private func collapsibleSection(
        _ category: (label: String, items: [Kaomoji]),
        favorites: Set<String>
    ) -> some View {
        let expanded = Set(decodeList(expandedJSON)).contains(category.label)
        let revealed = revealCounts[category.label] ?? sectionInitial
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                toggleExpanded(category.label)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                    sectionHeader(category.label, count: category.items.count)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                chipGrid(Array(category.items.prefix(revealed)), favorites: favorites)
                if category.items.count > revealed {
                    Button(
                        "Show \(min(sectionStep, category.items.count - revealed)) more"
                    ) {
                        revealCounts[category.label] = revealed + sectionStep
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.link)
                }
            }
        }
    }

    private func chipGrid(_ items: [Kaomoji], favorites: Set<String>) -> some View {
        FlowLayout(spacing: 4) {
            ForEach(items) { item in
                ChipButton(
                    item: item,
                    isFavorite: favorites.contains(item.chars),
                    action: { copy(item) },
                    onToggleFavorite: { toggleFavorite(item) },
                    onHover: { hovering in
                        if hovering {
                            hovered = item
                        } else if hovered == item {
                            hovered = nil
                        }
                    }
                )
            }
        }
    }

    /* ------------------------------- copy -------------------------------- */

    private func copy(_ item: Kaomoji) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.chars, forType: .string)

        var chars = decodeList(recentsJSON).filter { $0 != item.chars }
        chars.insert(item.chars, at: 0)
        recentsJSON = encodeList(Array(chars.prefix(8)))

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
    let isFavorite: Bool
    let action: () -> Void
    let onToggleFavorite: () -> Void
    let onHover: (Bool) -> Void
    @State private var isHovering = false

    var body: some View {
        Button {
            if NSEvent.modifierFlags.contains(.command) {
                onToggleFavorite()
            } else {
                action()
            }
        } label: {
            Text(item.chars)
                .font(.system(size: 13))
                .lineLimit(1)
        }
        .buttonStyle(ChipButtonStyle(isHovering: isHovering))
        .overlay(alignment: .topTrailing) {
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(.yellow)
                    .offset(x: 1, y: -1)
            }
        }
        .contextMenu {
            Button(isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                onToggleFavorite()
            }
            Button("Copy") {
                action()
            }
        }
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
