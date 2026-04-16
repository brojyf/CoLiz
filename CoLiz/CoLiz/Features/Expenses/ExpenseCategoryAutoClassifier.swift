import Foundation

enum ExpenseCategoryAutoClassifier {
    static func suggestCategory(for expenseName: String) -> ExpenseCategory {
        let normalizedName = normalized(expenseName)
        guard !normalizedName.isEmpty else { return .other }

        for rule in ExpenseCategoryMappingStore.mergedRules() {
            if rule.keywords.contains(where: { normalizedName.contains($0) }) {
                return rule.category
            }
        }

        return .other
    }

    private static func normalized(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}
