//
//  ContentView.swift
//  CoList
//
//  Created by 江逸帆 on 2/10/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthStateStore
    @EnvironmentObject private var languageStore: LanguageStore
    @EnvironmentObject private var profileVM: ProfileVM
    @EnvironmentObject private var todoVM: TodoVM
    @EnvironmentObject private var errorPresenter: ErrorPresenter
    @EnvironmentObject private var notificationService: NotificationService

    var body: some View {
        ZStack {
            switch auth.state {
            case .idle:
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text(languageStore.text(.checkingSession))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.secondary)
                }
                    .transition(.opacity)
            case .signedIn:
                MainTabView()
            case .signedOut:
                LoginFlowView()
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                        )
                    )
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: auth.state)
        .colistScreenBackground()
        .task(id: auth.state) {
            guard case .signedIn = auth.state else { return }
            preloadSignedInData()
            notificationService.requestAuthorization()
        }
        .onReceive(notificationService.deviceTokenPublisher) { token in
            profileVM.uploadDeviceToken(token)
        }
        .onChange(of: auth.state) { _, newState in
            if case .signedOut = newState {
                profileVM.resetOnSignOut()
                todoVM.resetOnSignOut()
            }
        }
        .alert(languageStore.text(.errorTitle), isPresented: errorBinding) {
            Button(languageStore.text(.ok)) { errorPresenter.clear() }
        } message: {
            Text(errorPresenter.message ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorPresenter.message != nil },
            set: { presented in
                if !presented { errorPresenter.clear() }
            }
        )
    }

    private func preloadSignedInData() {
        profileVM.loadProfileIfNeeded()
        todoVM.preloadSignedInDataIfNeeded()
    }
}

#Preview {
    let store = DefaultAuthStore()
    let base = BaseClient()
    let refresher = DefaultAuthRefresher(c: base)
    let tokenProvider = DefaultTokenProvider(store: store, refresher: refresher)
    let authedClient = AuthedClient(base: base, tp: tokenProvider)
    let service = TodoService(c: authedClient, tp: tokenProvider)
    let profileService = ProfileService(c: authedClient, tp: tokenProvider)
    let authService = AuthService(c: base, store: store)
    let authState = AuthStateStore(tp: tokenProvider)
    let presenter = ErrorPresenter()
    let todoVM = TodoVM(ep: presenter, s: service)

    ContentView()
        .environmentObject(authState)
        .environmentObject(LanguageStore())
        .environmentObject(LoginVM(s: authService, tp: tokenProvider, auth: authState, ep: presenter))
        .environmentObject(ProfileVM(s: profileService, ep: presenter))
        .environmentObject(todoVM)
        .environmentObject(ExpenseViewModel(todoVM: todoVM))
        .environmentObject(presenter)
}
