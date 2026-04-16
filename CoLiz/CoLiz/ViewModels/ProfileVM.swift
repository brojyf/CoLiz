import Foundation
import Combine

@MainActor
final class ProfileVM: ObservableObject {
    @Published private(set) var profile: UserProfile?
    @Published private(set) var isLoading = false
    @Published private(set) var isUpdatingUsername = false
    @Published private(set) var isUploadingAvatar = false
    @Published private(set) var isChangingPassword = false

    private let service: ProfileService
    private let presenter: ErrorPresenter
    private var bag = Set<AnyCancellable>()
    private var cacheBag = Set<AnyCancellable>()
    private var didLoadProfile = false
    private static let cacheKey = "profile"

    init(s: ProfileService, ep: ErrorPresenter) {
        self.service = s
        self.presenter = ep
        observeCachePersistence()
        hydrateCachedProfile()
    }

    func loadProfileIfNeeded() {
        guard !didLoadProfile else { return }
        loadProfile()
    }

    func loadProfile() {
        if UITestConfig.usesStubData {
            profile = .mock()
            didLoadProfile = true
            return
        }

        isLoading = true
        service.getProfile()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                guard case let .failure(error) = completion else { return }
                self.handle(error)
            } receiveValue: { [weak self] profile in
                guard let self else { return }
                self.profile = profile
                self.didLoadProfile = true
            }
            .store(in: &bag)
    }

    func uploadAvatar(data: Data) {
        Task {
            do {
                isUploadingAvatar = true
                let profile = try await service.uploadAvatar(data: data)
                self.profile = profile
                didLoadProfile = true
            } catch {
                handle(NetworkError.map(error))
            }
            isUploadingAvatar = false
        }
    }

    func updateUsername(_ username: String, onSuccess: (() -> Void)? = nil) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if UITestConfig.usesStubData {
            let current = profile ?? .mock()
            profile = UserProfile(
                id: current.id,
                username: trimmed,
                email: current.email,
                avatarVersion: current.avatarVersion
            )
            didLoadProfile = true
            onSuccess?()
            return
        }

        isUpdatingUsername = true
        service.updateUsername(trimmed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isUpdatingUsername = false
                guard case let .failure(error) = completion else { return }
                self.handle(error)
            } receiveValue: { [weak self] profile in
                guard let self else { return }
                self.profile = profile
                self.didLoadProfile = true
                onSuccess?()
            }
            .store(in: &bag)
    }

    func uploadDeviceToken(_ token: String) {
        service.uploadDeviceToken(token)
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { _ in }
            .store(in: &bag)
    }

    func resetOnSignOut() {
        bag.removeAll()
        profile = nil
        isLoading = false
        isUpdatingUsername = false
        isUploadingAvatar = false
        isChangingPassword = false
        didLoadProfile = false
        clearCache()
    }

    func changePassword(old: String, new: String, onSuccess: (() -> Void)? = nil) {
        let trimmedOld = old.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNew = new.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedOld.isEmpty else {
            presenter.show("Please enter your current password.")
            return
        }
        guard isPasswordValid(trimmedNew) else {
            presenter.show("New password must be 8-20 chars with upper, lower, number and symbol.")
            return
        }

        if UITestConfig.usesStubData {
            onSuccess?()
            return
        }

        isChangingPassword = true
        service.changePassword(old: trimmedOld, new: trimmedNew)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isChangingPassword = false
                guard case let .failure(error) = completion else { return }
                self.handle(error)
            } receiveValue: { [weak self] in
                guard let self else { return }
                self.isChangingPassword = false
                onSuccess?()
            }
            .store(in: &bag)
    }

    private func handle(_ error: NetworkError) {
        if let msg = NetworkError.userMessage(from: error) {
            presenter.show(msg)
        }
    }

    private func isPasswordValid(_ password: String) -> Bool {
        guard password.count >= 8, password.count <= 20 else { return false }

        let hasUpper = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLower = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasDigit = password.rangeOfCharacter(from: .decimalDigits) != nil
        let symbols = CharacterSet.punctuationCharacters.union(.symbols)
        let hasSymbol = password.rangeOfCharacter(from: symbols) != nil

        return hasUpper && hasLower && hasDigit && hasSymbol
    }

    private func observeCachePersistence() {
        objectWillChange
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.persistCache()
            }
            .store(in: &cacheBag)
    }

    private func hydrateCachedProfile() {
        guard !UITestConfig.usesStubData else { return }

        Task { [weak self] in
            guard
                let snapshot = await AppCacheStore.shared.load(
                    ProfileCacheSnapshot.self,
                    for: Self.cacheKey
                )
            else {
                return
            }

            await MainActor.run {
                self?.profile = snapshot.profile
            }
        }
    }

    private func persistCache() {
        guard !UITestConfig.usesStubData else { return }
        guard profile != nil else {
            clearCache()
            return
        }
        let snapshot = ProfileCacheSnapshot(profile: profile)
        Task {
            await AppCacheStore.shared.save(snapshot, for: Self.cacheKey)
        }
    }

    private func clearCache() {
        Task {
            await AppCacheStore.shared.removeValue(for: Self.cacheKey)
        }
    }
}
