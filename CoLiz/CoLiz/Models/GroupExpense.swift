import Foundation
import SwiftUI

struct GroupExpense: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let groupName: String
    let avatarVersion: UInt32
    let lentAmount: String
    let borrowAmount: String

    private static let amountLocale = Locale(identifier: "en_US_POSIX")
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    var resolvedAvatarURL: URL {
        API.Groups.avatar(groupID: id, version: avatarVersion)
    }

    var lentDecimal: Decimal {
        Decimal(string: lentAmount, locale: Self.amountLocale) ?? .zero
    }

    var borrowDecimal: Decimal {
        Decimal(string: borrowAmount, locale: Self.amountLocale) ?? .zero
    }

    var formattedLentAmount: String {
        Self.formatCurrency(lentDecimal)
    }

    var formattedBorrowAmount: String {
        Self.formatCurrency(borrowDecimal)
    }

    var summaryText: String {
        if lentDecimal > .zero {
            return "You lent \(formattedLentAmount)"
        }
        if borrowDecimal > .zero {
            return "You borrowed \(formattedBorrowAmount)"
        }
        return "All settled up"
    }

    var balanceDescription: String {
        if lentDecimal > .zero {
            return "Others currently owe you \(formattedLentAmount) in this group."
        }
        if borrowDecimal > .zero {
            return "You currently owe others \(formattedBorrowAmount) in this group."
        }
        return "You are all settled up in this group."
    }

    var balanceTint: Color {
        if lentDecimal > .zero {
            return AppTheme.lent
        }
        if borrowDecimal > .zero {
            return AppTheme.borrowed
        }
        return .secondary
    }

    var balanceAmountText: String {
        if lentDecimal > .zero {
            return formattedLentAmount
        }
        if borrowDecimal > .zero {
            return formattedBorrowAmount
        }
        return "$0.00"
    }

    private static func formatCurrency(_ amount: Decimal) -> String {
        currencyFormatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

extension GroupExpense {
    static func mockList() -> [GroupExpense] {
        [
            GroupExpense(
                id: "group-home",
                groupName: "Roommates",
                avatarVersion: 0,
                lentAmount: "18.50",
                borrowAmount: "0.00"
            ),
            GroupExpense(
                id: "group-work",
                groupName: "Work Buddies",
                avatarVersion: 0,
                lentAmount: "0.00",
                borrowAmount: "24.75"
            ),
        ]
    }
}
