import Foundation
import SwiftUI

struct MonthlyExpenseBreakdownCard: View {
    let items: [ExpenseHistoryItem]
    var referenceDate: Date = Date()
    var showsCard = true

    fileprivate static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    private var monthLabel: String {
        Self.monthFormatter.string(from: referenceDate)
    }

    private var monthlyItems: [ExpenseHistoryItem] {
        let calendar = Calendar.current
        return items.filter {
            calendar.isDate($0.occurredAt, equalTo: referenceDate, toGranularity: .month)
                && $0.expenseCategory != .transaction
        }
    }

    private var entries: [MonthlyExpenseBreakdownEntry] {
        let amountLocale = Locale(identifier: "en_US_POSIX")
        let grouped = Dictionary(grouping: monthlyItems, by: \.expenseCategory)
        var totalsByCategory: [MonthlyExpenseBreakdownEntry] = []

        for (category, categoryItems) in grouped {
            var total = Decimal.zero
            for item in categoryItems {
                total += Decimal(string: item.amount, locale: amountLocale) ?? .zero
            }

            guard total > .zero else { continue }
            totalsByCategory.append(
                MonthlyExpenseBreakdownEntry(category: category, amount: total)
            )
        }

        totalsByCategory.sort { lhs, rhs in
            if lhs.amount == rhs.amount {
                return lhs.category.title < rhs.category.title
            }
            return lhs.amount > rhs.amount
        }

        let totalAmount = totalsByCategory.reduce(into: Decimal.zero) { $0 += $1.amount }
        guard totalAmount > .zero else { return [] }

        return totalsByCategory.map { entry in
            MonthlyExpenseBreakdownEntry(
                category: entry.category,
                amount: entry.amount,
                share: NSDecimalNumber(decimal: entry.amount).doubleValue /
                    NSDecimalNumber(decimal: totalAmount).doubleValue
            )
        }
    }

    private var totalAmount: Decimal {
        entries.reduce(into: Decimal.zero) { $0 += $1.amount }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly Spending")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)

                    Text(monthLabel)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondary)
                }

                Spacer(minLength: 12)

                Text(Self.formatCurrency(totalAmount))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
            }

            if entries.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "chart.pie")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondary)
                    Text("No expenses recorded this month yet.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondary)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 18) {
                    MonthlyExpenseDonutChart(entries: entries, totalAmount: totalAmount)
                        .frame(maxWidth: .infinity)

                    VStack(spacing: 10) {
                        ForEach(entries) { entry in
                            MonthlyExpenseLegendRow(entry: entry)
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        Group {
            if showsCard {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .colistCard(fill: AppTheme.surface, cornerRadius: ComponentMetrics.largeCardCornerRadius)
            } else {
                content
            }
        }
    }

    fileprivate static func formatCurrency(_ amount: Decimal) -> String {
        currencyFormatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

private struct MonthlyExpenseDonutChart: View {
    let entries: [MonthlyExpenseBreakdownEntry]
    let totalAmount: Decimal

    private let chartSize: CGFloat = 144
    private let lineWidth: CGFloat = 22

    private var segments: [MonthlyExpenseChartSegment] {
        var start = 0.0
        return entries.enumerated().map { index, entry in
            let end = index == entries.count - 1 ? 1.0 : start + entry.share
            defer { start = end }
            return MonthlyExpenseChartSegment(entry: entry, start: start, end: end)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.border.opacity(0.18), lineWidth: lineWidth)

            ForEach(segments) { segment in
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(
                        segment.entry.color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 4) {
                Text("This Month")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondary)

                Text(MonthlyExpenseBreakdownCard.formatCurrency(totalAmount))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                Text("\(entries.count) categories")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
        }
        .frame(width: chartSize, height: chartSize)
    }
}

private struct MonthlyExpenseLegendRow: View {
    let entry: MonthlyExpenseBreakdownEntry

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(entry.color)
                .frame(width: 8, height: 8)

            Text(entry.category.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.ink)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.formattedShare)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.secondary)

                Text(entry.formattedAmount)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.ink)
            }
        }
    }
}

private struct MonthlyExpenseBreakdownEntry: Identifiable {
    let category: ExpenseCategory
    let amount: Decimal
    var share: Double = 0

    var id: String { category.id }

    var color: Color {
        category.chartTint
    }

    var formattedAmount: String {
        MonthlyExpenseBreakdownCard.formatCurrency(amount)
    }

    var formattedShare: String {
        let percent = share * 100
        if percent >= 10 {
            return "\(Int(percent.rounded()))%"
        }
        return String(format: "%.1f%%", percent)
    }
}

private struct MonthlyExpenseChartSegment: Identifiable {
    let entry: MonthlyExpenseBreakdownEntry
    let start: Double
    let end: Double

    var id: String { entry.id }
}

private extension ExpenseCategory {
    var chartTint: Color {
        switch self {
        case .dining:
            return AppTheme.primary
        case .gas:
            return Color(red: 0.86, green: 0.45, blue: 0.28)
        case .groceries:
            return AppTheme.secondary
        case .transaction:
            return Color(red: 0.54, green: 0.58, blue: 0.64)
        case .transport:
            return AppTheme.butter
        case .entertainment:
            return AppTheme.blush
        case .shopping:
            return Color(red: 0.83, green: 0.62, blue: 0.43)
        case .housing:
            return Color(red: 0.47, green: 0.67, blue: 0.55)
        case .utilities:
            return Color(red: 0.41, green: 0.61, blue: 0.82)
        case .travel:
            return Color(red: 0.90, green: 0.55, blue: 0.42)
        case .health:
            return Color(red: 0.74, green: 0.56, blue: 0.75)
        case .other:
            return Color(red: 0.61, green: 0.59, blue: 0.56)
        }
    }
}
