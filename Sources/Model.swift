struct Kaomoji: Identifiable, Hashable {
    let chars: String
    let name: String
    let keywords: [String]
    let category: String

    var id: String { chars }
}
