import Combine
import SwiftUI
import UIKit

enum MainTabRequest: Equatable {
    case todo
    case expense
    case social
}

@MainActor
final class MainTabNavigationState: ObservableObject {
    @Published var requestedTab: MainTabRequest?
    @Published var expenseGroupIDToOpen: String?
    @Published var socialGroupIDToOpen: String?

    func openTodoHome() {
        expenseGroupIDToOpen = nil
        requestedTab = .todo
    }

    func openExpenseGroup(_ groupID: String) {
        expenseGroupIDToOpen = groupID
        requestedTab = .expense
    }

    func openSocialHome() {
        socialGroupIDToOpen = nil
        requestedTab = .social
    }

    func openSocialGroup(_ groupID: String) {
        socialGroupIDToOpen = groupID
        requestedTab = .social
    }

    func consumeRequestedTab() {
        requestedTab = nil
    }

    func consumeExpenseGroup() {
        expenseGroupIDToOpen = nil
    }

    func consumeSocialGroup() {
        socialGroupIDToOpen = nil
    }
}

struct MainTabView: View {
    private enum Tab: Hashable {
        case todo
        case expense
        case add
        case social
        case profile
    }

    @State private var selection: Tab = .todo
    @State private var previousContentSelection: Tab = .todo
    @State private var isShowingCreateHub = false
    @State private var createHubInitialDestination: CreateHubSheetView.Destination?
    @State private var colistRevealEnabled = false
    @StateObject private var navigationState = MainTabNavigationState()
    @EnvironmentObject private var languageStore: LanguageStore
    @EnvironmentObject private var notificationService: NotificationService

    private let addTabFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        TabView(selection: $selection) {
            TodoTabView()
                .tag(Tab.todo)
            ExpenseTabView()
                .tag(Tab.expense)
            Color.clear
                .tag(Tab.add)
                .tabItem {
                    Label {
                        Text(languageStore.text(.addTab))
                            .font(.caption.weight(.semibold))
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 23, weight: .bold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(AppTheme.blush, AppTheme.butter)
                    }
                }
            SocialTabView()
                .tag(Tab.social)
            ProfileTabView()
                .tag(Tab.profile)
        }
        .tint(AppTheme.primary)
        .environment(\.colistRevealEnabled, colistRevealEnabled)
        .environmentObject(navigationState)
        .task {
            guard !colistRevealEnabled else { return }
            colistRevealEnabled = true
            addTabFeedbackGenerator.prepare()
        }
        .onChange(of: selection) { _, newValue in
            if newValue == .add {
                presentCreateHub()
                return
            }

            previousContentSelection = newValue
        }
        .onChange(of: navigationState.requestedTab) { _, newValue in
            guard let newValue else { return }
            switch newValue {
            case .todo:
                selection = .todo
                previousContentSelection = .todo
            case .expense:
                selection = .expense
                previousContentSelection = .expense
            case .social:
                selection = .social
                previousContentSelection = .social
            }
            navigationState.consumeRequestedTab()
        }
        .sheet(isPresented: $isShowingCreateHub) {
            CreateHubSheetView(initialDestination: createHubInitialDestination)
                .environmentObject(navigationState)
        }
        .onReceive(notificationService.notificationTapPublisher) { userInfo in
            handleNotificationTap(userInfo)
        }
    }

    private func handleNotificationTap(_ userInfo: [AnyHashable: Any]) {
        let type = userInfo["type"] as? String
        let groupID = userInfo["group_id"] as? String
        switch type {
        case "todo.created", "todo.updated":
            navigationState.openTodoHome()
        case "expense.created", "expense.updated":
            if let groupID {
                navigationState.openExpenseGroup(groupID)
            }
        case "friend_request.sent", "group.invited":
            navigationState.openSocialHome()
        default:
            break
        }
    }

    private func presentCreateHub() {
        addTabFeedbackGenerator.impactOccurred(intensity: 0.85)
        addTabFeedbackGenerator.prepare()
        selection = previousContentSelection
        createHubInitialDestination = nil
        isShowingCreateHub = true
    }
}
