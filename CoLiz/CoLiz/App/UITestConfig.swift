import Foundation

enum UITestConfig {
    private nonisolated static let args = ProcessInfo.processInfo.arguments

    nonisolated static var isEnabled: Bool {
        args.contains("UI-Testing")
    }

    nonisolated static var startsSignedIn: Bool {
        args.contains("UI-Testing-SignedIn")
    }

    nonisolated static var startsSignedOut: Bool {
        args.contains("UI-Testing-SignedOut")
    }

    nonisolated static var usesStubData: Bool {
        isEnabled && args.contains("UI-Testing-StubData")
    }

    nonisolated static var mocksAuthSuccess: Bool {
        isEnabled && args.contains("UI-Testing-MockAuth")
    }

    nonisolated static var initialAuthState: AuthState? {
        if startsSignedIn { return .signedIn }
        if startsSignedOut { return .signedOut }
        return nil
    }
}
