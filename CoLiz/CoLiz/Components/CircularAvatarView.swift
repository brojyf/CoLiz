import Combine
import SwiftUI
import UIKit

struct CircularAvatarView: View {
    let image: UIImage?
    let remoteAvatarURL: URL?
    var size: CGFloat
    var placeholderSystemImage: String
    var placeholderImageScale: CGFloat = 0.28

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let remoteAvatarURL {
                CachedRemoteAvatarView(url: remoteAvatarURL, placeholder: placeholderAvatar)
            } else {
                placeholderAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholderAvatar: some View {
        ZStack {
            Circle()
                .fill(AppTheme.creamStrong.opacity(0.9))

            Image(systemName: placeholderSystemImage)
                .font(.system(size: size * placeholderImageScale, weight: .medium))
                .foregroundStyle(AppTheme.primary)
        }
    }
}

private struct CachedRemoteAvatarView<Placeholder: View>: View {
    let url: URL
    let placeholder: Placeholder

    @StateObject private var loader = AvatarImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: url) {
            await loader.load(from: url)
        }
    }
}

private final class AvatarImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private static let memoryCache = NSCache<NSURL, UIImage>()
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 24 * 1024 * 1024,
            diskCapacity: 128 * 1024 * 1024,
            diskPath: "colist-avatar-cache"
        )
        return URLSession(configuration: configuration)
    }()

    @MainActor
    func load(from url: URL) async {
        let cacheKey = url as NSURL
        if let cachedImage = Self.memoryCache.object(forKey: cacheKey) {
            image = cachedImage
            return
        }

        let request = URLRequest(
            url: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 30
        )

        if
            let cachedResponse = Self.session.configuration.urlCache?.cachedResponse(for: request),
            let cachedImage = UIImage(data: cachedResponse.data)
        {
            Self.memoryCache.setObject(cachedImage, forKey: cacheKey)
            image = cachedImage
            return
        }

        do {
            let (data, response) = try await Self.session.data(for: request)
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode),
                let fetchedImage = UIImage(data: data)
            else {
                return
            }

            let cachedResponse = CachedURLResponse(response: httpResponse, data: data)
            Self.session.configuration.urlCache?.storeCachedResponse(cachedResponse, for: request)
            Self.memoryCache.setObject(fetchedImage, forKey: cacheKey)
            image = fetchedImage
        } catch {
            return
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CircularAvatarView(
            image: nil,
            remoteAvatarURL: nil,
            size: 68,
            placeholderSystemImage: "person.fill"
        )
        CircularAvatarView(
            image: nil,
            remoteAvatarURL: nil,
            size: 68,
            placeholderSystemImage: "person.3.fill"
        )
    }
    .padding()
}
