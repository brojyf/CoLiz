import SwiftUI
import UIKit

enum AvatarUploadImageProcessor {
    static let maxDimension: CGFloat = 1600
    static let jpegQuality: CGFloat = 0.82

    static func prepareJPEGData(from image: UIImage) -> Data? {
        guard let resized = resizedForUpload(image) else { return nil }
        return resized.jpegData(compressionQuality: jpegQuality)
    }

    static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    static func aspectFitRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard
            imageSize.width > 0,
            imageSize.height > 0,
            bounds.width > 0,
            bounds.height > 0
        else {
            return .zero
        }

        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let fittedSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        return CGRect(
            x: bounds.midX - fittedSize.width / 2,
            y: bounds.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    static func cropImage(
        _ image: UIImage,
        from cropRect: CGRect,
        displayedIn imageFrame: CGRect
    ) -> UIImage? {
        let normalized = normalizedImage(image)
        guard let cgImage = normalized.cgImage else { return nil }
        guard
            cropRect.width > 0,
            cropRect.height > 0,
            imageFrame.width > 0,
            imageFrame.height > 0
        else {
            return nil
        }

        let boundedCropRect = cropRect.intersection(imageFrame)
        guard !boundedCropRect.isNull, !boundedCropRect.isEmpty else { return nil }

        let pixelsPerPointX = CGFloat(cgImage.width) / imageFrame.width
        let pixelsPerPointY = CGFloat(cgImage.height) / imageFrame.height

        let originX = (boundedCropRect.minX - imageFrame.minX) * pixelsPerPointX
        let originY = (boundedCropRect.minY - imageFrame.minY) * pixelsPerPointY
        let width = boundedCropRect.width * pixelsPerPointX
        let height = boundedCropRect.height * pixelsPerPointY

        let maxX = max(0, CGFloat(cgImage.width) - width)
        let maxY = max(0, CGFloat(cgImage.height) - height)
        let cropRect = CGRect(
            x: min(max(originX, 0), maxX),
            y: min(max(originY, 0), maxY),
            width: min(width, CGFloat(cgImage.width)),
            height: min(height, CGFloat(cgImage.height))
        ).integral

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: normalized.scale, orientation: .up)
    }

    static func resizedForUpload(_ image: UIImage) -> UIImage? {
        let normalized = normalizedImage(image)
        let size = normalized.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return normalized }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(
            width: floor(size.width * scale),
            height: floor(size.height * scale)
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
