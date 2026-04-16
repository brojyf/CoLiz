//
//  CoListApp.swift
//  CoList
//
//  Created by 江逸帆 on 2/10/26.
//

import SwiftUI

@main
struct CoListApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var authState: AuthStateStore
    @StateObject private var errorPresenter: ErrorPresenter
    @StateObject private var languageStore: LanguageStore
    @StateObject private var loginVM: LoginVM
    @StateObject private var profileVM: ProfileVM
    @StateObject private var todoVM: TodoVM
    @StateObject private var expenseVM: ExpenseViewModel
    @StateObject private var notificationService = NotificationService()

    init() {
        let store = DefaultAuthStore()
        let base = BaseClient()
        let refresher = DefaultAuthRefresher(c: base)
        let tokenProvider = DefaultTokenProvider(
            store: store,
            refresher: refresher
        )
        let authedClient = AuthedClient(base: base, tp: tokenProvider)
        let todoService = TodoService(c: authedClient, tp: tokenProvider)
        let profileService = ProfileService(c: authedClient, tp: tokenProvider)
        let authService = AuthService(c: base, store: store)
        let presenter = ErrorPresenter()
        let auth = AuthStateStore(
            tp: tokenProvider,
            initialState: UITestConfig.initialAuthState
        )

        _errorPresenter = StateObject(wrappedValue: presenter)
        _languageStore = StateObject(wrappedValue: LanguageStore())
        _loginVM = StateObject(
            wrappedValue: LoginVM(
                s: authService,
                tp: tokenProvider,
                auth: auth,
                ep: presenter
            )
        )
        let todoVM = TodoVM(ep: presenter, s: todoService)

        _profileVM = StateObject(wrappedValue: ProfileVM(s: profileService, ep: presenter))
        _todoVM = StateObject(wrappedValue: todoVM)
        _expenseVM = StateObject(wrappedValue: ExpenseViewModel(todoVM: todoVM))
        _authState = StateObject(wrappedValue: auth)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(AppTheme.primary)
                .environmentObject(authState)
                .environmentObject(languageStore)
                .environmentObject(loginVM)
                .environmentObject(profileVM)
                .environmentObject(todoVM)
                .environmentObject(expenseVM)
                .environmentObject(errorPresenter)
                .environmentObject(notificationService)
                .task {
                    appDelegate.notificationService = notificationService
                }
        }
    }
}
