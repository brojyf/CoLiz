import Combine
import Foundation
import SwiftUI

enum AppLanguage: String {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    static var systemPreferred: AppLanguage {
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferredLanguage.hasPrefix("zh") ? .simplifiedChinese : .english
    }
}

enum AppCopyKey {
    case checkingSession
    case errorTitle
    case ok
    case todoTab
    case expenseTab
    case addTab
    case socialTab
    case profileTab
    case profileTitle
    case expenseSectionTitle
    case expenseNameMapping
    case settingsSectionTitle
    case signOutSectionTitle
    case signOutButton
    case loadingProfile
    case tapToViewProfileDetails
    case personalInfoTitle
    case avatar
    case name
    case email
    case changePassword
    case editNameTitle
    case editNamePlaceholder
    case cancel
    case save
    case saving
    case updateProfileNameMessage
    case currentPasswordSectionTitle
    case currentPasswordPlaceholder
    case newPasswordSectionTitle
    case newPasswordPlaceholder
    case confirmNewPasswordPlaceholder
    case requirementsSectionTitle
    case requirementLength
    case requirementUpperLower
    case requirementDigit
    case requirementSymbol
    case requirementMatch
}

final class LanguageStore: ObservableObject {
    @Published private(set) var language: AppLanguage

    private var bag = Set<AnyCancellable>()

    init(notificationCenter: NotificationCenter = .default) {
        language = AppLanguage.systemPreferred

        notificationCenter.publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshFromSystem()
            }
            .store(in: &bag)
    }

    func refreshFromSystem() {
        let nextLanguage = AppLanguage.systemPreferred
        guard language != nextLanguage else { return }
        language = nextLanguage
    }

    func text(_ key: AppCopyKey) -> String {
        switch language {
        case .english:
            return englishText(for: key)
        case .simplifiedChinese:
            return chineseText(for: key)
        }
    }

    private func englishText(for key: AppCopyKey) -> String {
        switch key {
        case .checkingSession: return "Checking session..."
        case .errorTitle: return "Error"
        case .ok: return "OK"
        case .todoTab: return "Todo"
        case .expenseTab: return "Expense"
        case .addTab: return "Add"
        case .socialTab: return "Social"
        case .profileTab: return "Profile"
        case .profileTitle: return "Profile"
        case .expenseSectionTitle: return "Expense"
        case .expenseNameMapping: return "Expense Name Mapping"
        case .settingsSectionTitle: return "Settings"
        case .signOutSectionTitle: return "Sign Out"
        case .signOutButton: return "Sign Out"
        case .loadingProfile: return "Loading..."
        case .tapToViewProfileDetails: return "Tap to view profile details"
        case .personalInfoTitle: return "Personal Info"
        case .avatar: return "Avatar"
        case .name: return "Name"
        case .email: return "Email"
        case .changePassword: return "Change Password"
        case .editNameTitle: return "Edit Name"
        case .editNamePlaceholder: return "Name"
        case .cancel: return "Cancel"
        case .save: return "Save"
        case .saving: return "Saving..."
        case .updateProfileNameMessage: return "Update the name shown on your profile."
        case .currentPasswordSectionTitle: return "Current Password"
        case .currentPasswordPlaceholder: return "Current Password"
        case .newPasswordSectionTitle: return "New Password"
        case .newPasswordPlaceholder: return "New Password"
        case .confirmNewPasswordPlaceholder: return "Confirm New Password"
        case .requirementsSectionTitle: return "Requirements"
        case .requirementLength: return "8-20 characters"
        case .requirementUpperLower: return "At least one upper case and one lower case character"
        case .requirementDigit: return "At least one digit"
        case .requirementSymbol: return "At least one special symbol"
        case .requirementMatch: return "Same password."
        }
    }

    private func chineseText(for key: AppCopyKey) -> String {
        switch key {
        case .checkingSession: return "正在检查登录状态..."
        case .errorTitle: return "错误"
        case .ok: return "确定"
        case .todoTab: return "待办"
        case .expenseTab: return "账单"
        case .addTab: return "添加"
        case .socialTab: return "社交"
        case .profileTab: return "我的"
        case .profileTitle: return "我的"
        case .expenseSectionTitle: return "账单"
        case .expenseNameMapping: return "Expense 名称映射"
        case .settingsSectionTitle: return "设置"
        case .signOutSectionTitle: return "退出登录"
        case .signOutButton: return "退出登录"
        case .loadingProfile: return "加载中..."
        case .tapToViewProfileDetails: return "点击查看个人资料"
        case .personalInfoTitle: return "个人信息"
        case .avatar: return "头像"
        case .name: return "昵称"
        case .email: return "邮箱"
        case .changePassword: return "修改密码"
        case .editNameTitle: return "修改昵称"
        case .editNamePlaceholder: return "昵称"
        case .cancel: return "取消"
        case .save: return "保存"
        case .saving: return "保存中..."
        case .updateProfileNameMessage: return "更新你在个人资料中显示的昵称。"
        case .currentPasswordSectionTitle: return "当前密码"
        case .currentPasswordPlaceholder: return "当前密码"
        case .newPasswordSectionTitle: return "新密码"
        case .newPasswordPlaceholder: return "新密码"
        case .confirmNewPasswordPlaceholder: return "确认新密码"
        case .requirementsSectionTitle: return "密码要求"
        case .requirementLength: return "8-20 个字符"
        case .requirementUpperLower: return "至少包含一个大写字母和一个小写字母"
        case .requirementDigit: return "至少包含一个数字"
        case .requirementSymbol: return "至少包含一个特殊符号"
        case .requirementMatch: return "两次输入的密码一致。"
        }
    }
}
