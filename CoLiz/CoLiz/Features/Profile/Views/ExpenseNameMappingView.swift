import SwiftUI

struct ExpenseNameMappingView: View {
    @State private var drafts: [String: String] = [:]
    @State private var refreshTrigger = 0

    var body: some View {
        Form {
            ForEach(ExpenseCategory.allCases) { category in
                Section {
                    let keywords = keywords(for: category)

                    if keywords.isEmpty {
                        Text("No keywords yet.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondary)
                    } else {
                        KeywordFlowLayout(spacing: 8) {
                            ForEach(keywords, id: \.self) { keyword in
                                keywordChip(keyword, category: category)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    TextField("Add a keyword", text: binding(for: category))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            addKeyword(for: category)
                        }
                } header: {
                    Label(category.title, systemImage: category.symbol)
                }
            }
        }
        .navigationTitle("Expense Name Mapping")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadDrafts()
        }
    }

    private func keywordChip(_ keyword: String, category: ExpenseCategory) -> some View {
        HStack(spacing: 8) {
            Text(keyword)
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)

            Button {
                removeKeyword(keyword, for: category)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private func binding(for category: ExpenseCategory) -> Binding<String> {
        Binding {
            drafts[category.rawValue, default: ""]
        } set: { newValue in
            drafts[category.rawValue] = newValue
        }
    }

    private func keywords(for category: ExpenseCategory) -> [String] {
        _ = refreshTrigger
        return ExpenseCategoryMappingStore.mergedKeywords(for: category)
    }

    private func addKeyword(for category: ExpenseCategory) {
        let rawKeyword = drafts[category.rawValue, default: ""]
        ExpenseCategoryMappingStore.addKeyword(rawKeyword, for: category)
        drafts[category.rawValue] = ""
        refreshTrigger += 1
    }

    private func removeKeyword(_ keyword: String, for category: ExpenseCategory) {
        ExpenseCategoryMappingStore.removeKeyword(keyword, for: category)
        refreshTrigger += 1
    }

    private func loadDrafts() {
        drafts = Dictionary(
            uniqueKeysWithValues: ExpenseCategory.allCases.map { category in
                (category.rawValue, "")
            }
        )
    }
}

private struct KeywordFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedRowWidth = currentRowWidth == 0
                ? size.width
                : currentRowWidth + spacing + size.width

            if currentRowWidth > 0, proposedRowWidth > maxWidth {
                totalHeight += currentRowHeight + spacing
                maxRowWidth = max(maxRowWidth, currentRowWidth)
                currentRowWidth = 0
                currentRowHeight = 0
            }

            currentRowWidth = currentRowWidth == 0
                ? size.width
                : currentRowWidth + spacing + size.width
            currentRowHeight = max(currentRowHeight, size.height)
        }

        if currentRowHeight > 0 {
            totalHeight += currentRowHeight
            maxRowWidth = max(maxRowWidth, currentRowWidth)
        }

        return CGSize(width: proposal.width ?? maxRowWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var point = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if point.x > bounds.minX, point.x + size.width > bounds.maxX {
                point.x = bounds.minX
                point.y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: point,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            point.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
