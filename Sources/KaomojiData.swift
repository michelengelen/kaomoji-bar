import Foundation

/// Chips shown per category while browsing. Search spans everything.
let browseLimit = 120

/// Chips shown for one search.
let resultsLimit = 300

private struct Dataset: Decodable {
    struct Category: Decodable {
        let id: String
        let label: String
        let items: [Item]
    }

    struct Item: Decodable {
        let chars: String
        let name: String
        let keywords: [String]
    }

    let categories: [Category]
}

private let dataset: Dataset = {
    guard let url = Bundle.module.url(forResource: "kaomoji", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let decoded = try? JSONDecoder().decode(Dataset.self, from: data)
    else {
        return Dataset(categories: [])
    }
    return decoded
}()

let categoryOrder: [String] = dataset.categories.map(\.label)

let categorizedKaomoji: [(label: String, items: [Kaomoji])] = dataset.categories.map { category in
    (
        label: category.label,
        items: category.items.map { item in
            Kaomoji(
                chars: item.chars,
                name: item.name,
                keywords: item.keywords,
                category: category.label
            )
        }
    )
}

let allKaomoji: [Kaomoji] = categorizedKaomoji.flatMap(\.items)

/// Precomputed lowercase search text per kaomoji.
let searchIndex: [(item: Kaomoji, haystack: String)] = allKaomoji.map { item in
    (item, ([item.name, item.category] + item.keywords).joined(separator: " ").lowercased())
}
