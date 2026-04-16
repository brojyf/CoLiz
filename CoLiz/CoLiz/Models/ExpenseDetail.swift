import Foundation

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case dining
    case gas
    case groceries
    case transaction
    case transport
    case entertainment
    case shopping
    case housing
    case utilities
    case travel
    case health
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dining:
            return "Dining"
        case .gas:
            return "Gas"
        case .groceries:
            return "Groceries"
        case .transaction:
            return "Transaction"
        case .transport:
            return "Transport"
        case .entertainment:
            return "Entertainment"
        case .shopping:
            return "Shopping"
        case .housing:
            return "Housing"
        case .utilities:
            return "Utilities"
        case .travel:
            return "Travel"
        case .health:
            return "Health"
        case .other:
            return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .dining:
            return "fork.knife"
        case .gas:
            return "fuelpump.fill"
        case .groceries:
            return "cart.fill"
        case .transaction:
            return "arrow.left.arrow.right.circle.fill"
        case .transport:
            return "car.fill"
        case .entertainment:
            return "gamecontroller.fill"
        case .shopping:
            return "bag.fill"
        case .housing:
            return "house.fill"
        case .utilities:
            return "bolt.fill"
        case .travel:
            return "airplane"
        case .health:
            return "cross.case.fill"
        case .other:
            return "square.grid.2x2.fill"
        }
    }

    static func resolve(_ rawValue: String) -> ExpenseCategory {
        ExpenseCategory(rawValue: rawValue) ?? .other
    }
}

struct ExpenseParticipantInput: Encodable, Equatable {
    let userID: String
    let percentage: String?
    let fixedAmount: String?

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case percentage
        case fixedAmount = "fixedAmount"
    }
}

struct CreateExpenseRequest: Encodable, Equatable {
    let name: String
    let category: String
    let amount: String
    let paidBy: String
    let splitMethod: String
    let note: String?
    let occurredAt: String?
    let participants: [ExpenseParticipantInput]

    enum CodingKeys: String, CodingKey {
        case name
        case category
        case amount
        case paidBy = "paidBy"
        case splitMethod = "splitMethod"
        case note
        case occurredAt = "occurredAt"
        case participants
    }
}

struct ExpenseParticipant: Codable, Equatable {
    let userID: String
    let amount: String
    let percentage: String?
    let fixedAmount: String?

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case amount
        case percentage
        case fixedAmount = "fixedAmount"
    }
}

struct ExpenseDetail: Identifiable, Codable, Equatable {
    let id: String
    let groupID: String
    let name: String
    let category: String
    let categorySymbol: String
    let amount: String
    let paidBy: String
    let splitMethod: String
    let note: String?
    let occurredAt: Date?
    let createdBy: String
    let createdAt: Date
    let updatedAt: Date
    let participants: [ExpenseParticipant]

    var expenseCategory: ExpenseCategory {
        ExpenseCategory.resolve(category)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case groupID = "groupId"
        case name
        case category
        case categorySymbol = "categorySymbol"
        case amount
        case paidBy = "paidBy"
        case splitMethod = "splitMethod"
        case note
        case occurredAt = "occurredAt"
        case createdBy = "createdBy"
        case createdAt = "createdAt"
        case updatedAt = "updatedAt"
        case participants
    }
}

struct ExpenseHistoryItem: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let category: String
    let categorySymbol: String
    let amount: String
    let lentAmount: String
    let borrowAmount: String
    let paidBy: String
    let paidByName: String
    let paidByAvatarVersion: UInt32
    let createdBy: String
    let occurredAt: Date
    let createdAt: Date

    var expenseCategory: ExpenseCategory {
        ExpenseCategory.resolve(category)
    }

    private static let amountLocale = Locale(identifier: "en_US_POSIX")

    var lentDecimal: Decimal {
        Decimal(string: lentAmount, locale: Self.amountLocale) ?? .zero
    }

    var borrowDecimal: Decimal {
        Decimal(string: borrowAmount, locale: Self.amountLocale) ?? .zero
    }

    var paidByAvatarURL: URL {
        API.Users.avatar(userID: paidBy, version: paidByAvatarVersion)
    }
}
