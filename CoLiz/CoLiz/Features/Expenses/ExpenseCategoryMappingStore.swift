import Foundation

enum ExpenseCategoryMappingStore {
    private static let storageKey = "colist.expenseCategoryMappings"
    private static let hiddenBuiltInStorageKey = "colist.expenseCategoryHiddenBuiltIns"
    private static let builtInMappings: [ExpenseCategory: [String]] = [
        .gas: [
            "gas", "fuel",
        ],
        .transport: [
            "uber", "lyft", "taxi",
        ],
        .dining: [
            "dinner", "lunch", "boba", "starbucks",
        ],
        .groceries: [
            "grocery", "groceries", "costco",
        ],
        .entertainment: [
            "movie"
        ],
        .shopping: [
             "uniqlo", "nike","ikea"
        ],
        .housing: [
            "rent",
        ],
        .utilities: [
            "electric", "electricity", "water", "internet", "wifi",
        ],
        .travel: [
            "flight", "hotel", "airbnb",
        ],
        .health: [
            "pharmacy", "hospital",
        ],
    ]

    static func keywordText(for category: ExpenseCategory) -> String {
        customKeywords(for: category).joined(separator: ", ")
    }

    static func builtInKeywords(for category: ExpenseCategory) -> [String] {
        builtInMappings[category] ?? []
    }

    static func activeBuiltInKeywords(for category: ExpenseCategory) -> [String] {
        let hiddenKeywords = Set(hiddenBuiltInKeywords(for: category))
        return builtInKeywords(for: category).filter { !hiddenKeywords.contains($0) }
    }

    static func customKeywords(for category: ExpenseCategory) -> [String] {
        loadMappings()[category.rawValue] ?? []
    }

    static func mergedKeywords(for category: ExpenseCategory) -> [String] {
        mergedKeywords(
            builtIn: activeBuiltInKeywords(for: category),
            custom: customKeywords(for: category)
        )
    }

    static func customRules() -> [(category: ExpenseCategory, keywords: [String])] {
        ExpenseCategory.allCases.compactMap { category in
            let keywords = customKeywords(for: category)
            guard !keywords.isEmpty else { return nil }
            return (category, keywords)
        }
    }

    static func mergedRules() -> [(category: ExpenseCategory, keywords: [String])] {
        ExpenseCategory.allCases.compactMap { category in
            let keywords = mergedKeywords(for: category)
            guard !keywords.isEmpty else { return nil }
            return (category, keywords)
        }
    }

    static func save(keywordText: String, for category: ExpenseCategory) {
        var mappings = loadMappings()
        let keywords = normalizedKeywords(from: keywordText)

        if keywords.isEmpty {
            mappings.removeValue(forKey: category.rawValue)
        } else {
            mappings[category.rawValue] = keywords
        }

        persist(mappings)
    }

    static func addKeyword(_ rawKeyword: String, for category: ExpenseCategory) {
        guard let keyword = normalizedKeyword(from: rawKeyword) else { return }

        if builtInKeywords(for: category).contains(keyword) {
            var hiddenMappings = loadHiddenBuiltInMappings()
            var hiddenKeywords = hiddenMappings[category.rawValue] ?? []
            hiddenKeywords.removeAll { $0 == keyword }

            if hiddenKeywords.isEmpty {
                hiddenMappings.removeValue(forKey: category.rawValue)
            } else {
                hiddenMappings[category.rawValue] = hiddenKeywords
            }

            persistHiddenBuiltIns(hiddenMappings)
            return
        }

        var mappings = loadMappings()
        var customKeywords = mappings[category.rawValue] ?? []
        guard !customKeywords.contains(keyword) else { return }
        customKeywords.append(keyword)
        mappings[category.rawValue] = customKeywords
        persist(mappings)
    }

    static func removeKeyword(_ rawKeyword: String, for category: ExpenseCategory) {
        guard let keyword = normalizedKeyword(from: rawKeyword) else { return }

        var mappings = loadMappings()
        var customKeywords = mappings[category.rawValue] ?? []
        let customCount = customKeywords.count
        customKeywords.removeAll { $0 == keyword }

        if customKeywords.isEmpty {
            mappings.removeValue(forKey: category.rawValue)
        } else if customKeywords.count != customCount {
            mappings[category.rawValue] = customKeywords
        }

        if customKeywords.count != customCount {
            persist(mappings)
            return
        }

        guard builtInKeywords(for: category).contains(keyword) else { return }

        var hiddenMappings = loadHiddenBuiltInMappings()
        var hiddenKeywords = hiddenMappings[category.rawValue] ?? []
        guard !hiddenKeywords.contains(keyword) else { return }
        hiddenKeywords.append(keyword)
        hiddenMappings[category.rawValue] = hiddenKeywords
        persistHiddenBuiltIns(hiddenMappings)
    }

    private static func loadMappings() -> [String: [String]] {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let mappings = try? JSONDecoder().decode([String: [String]].self, from: data)
        else {
            return [:]
        }

        return mappings
    }

    private static func hiddenBuiltInKeywords(for category: ExpenseCategory) -> [String] {
        loadHiddenBuiltInMappings()[category.rawValue] ?? []
    }

    private static func loadHiddenBuiltInMappings() -> [String: [String]] {
        guard
            let data = UserDefaults.standard.data(forKey: hiddenBuiltInStorageKey),
            let mappings = try? JSONDecoder().decode([String: [String]].self, from: data)
        else {
            return [:]
        }

        return mappings
    }

    private static func persist(_ mappings: [String: [String]]) {
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func persistHiddenBuiltIns(_ mappings: [String: [String]]) {
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        UserDefaults.standard.set(data, forKey: hiddenBuiltInStorageKey)
    }

    private static func normalizedKeywords(from rawValue: String) -> [String] {
        var seen = Set<String>()
        var keywords: [String] = []

        for part in rawValue.split(whereSeparator: { $0 == "," || $0.isNewline }) {
            let keyword = part
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()

            guard !keyword.isEmpty, seen.insert(keyword).inserted else { continue }
            keywords.append(keyword)
        }

        return keywords
    }

    private static func normalizedKeyword(from rawValue: String) -> String? {
        normalizedKeywords(from: rawValue).first
    }

    private static func mergedKeywords(
        builtIn: [String],
        custom: [String]
    ) -> [String] {
        var seen = Set<String>()
        var keywords: [String] = []

        for keyword in builtIn + custom {
            guard seen.insert(keyword).inserted else { continue }
            keywords.append(keyword)
        }

        return keywords
    }
}
