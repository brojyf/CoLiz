import SwiftUI
import UIKit

struct AvatarCropRequest: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct SquareAvatarCropperSheet: View {
    let onCancel: () -> Void
    let onConfirm: (UIImage) -> Void

    @State private var cropRect: CGRect = .zero
    @State private var imageOffset: CGSize = .zero
    @State private var dragStartOffset: CGSize = .zero
    @State private var resizeStartRect: CGRect = .zero
    @State private var isDraggingImage = false
    @State private var activeResizeHandle: CropHandlePosition?

    private let normalizedImage: UIImage
    private let minimumCropSide: CGFloat = 120

    init(
        image: UIImage,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (UIImage) -> Void
    ) {
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        self.normalizedImage = AvatarUploadImageProcessor.normalizedImage(image)
    }

    var body: some View {
        GeometryReader { geometry in
            let editorSize = editorCanvasSize(in: geometry.size)
            let imageBounds = CGRect(origin: .zero, size: editorSize).insetBy(dx: 10, dy: 10)
            let imageFrame = AvatarUploadImageProcessor.aspectFitRect(
                for: normalizedImage.size,
                in: imageBounds
            )
            let displayedImageFrame = imageFrame.offsetBy(dx: imageOffset.width, dy: imageOffset.height)

            VStack(spacing: 0) {
                header(imageFrame: imageFrame)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 20)

                Spacer(minLength: 0)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        }

                    Image(uiImage: normalizedImage)
                        .resizable()
                        .frame(width: displayedImageFrame.width, height: displayedImageFrame.height)
                        .position(x: displayedImageFrame.midX, y: displayedImageFrame.midY)

                    if cropRect != .zero {
                        CropSelectionMask(cropRect: cropRect)
                            .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
                            .allowsHitTesting(false)

                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: cropRect.width, height: cropRect.height)
                            .position(x: cropRect.midX, y: cropRect.midY)
                            .contentShape(Rectangle())
                            .gesture(moveImageGesture(within: imageFrame))
                            .overlay {
                                ZStack {
                                    Rectangle()
                                        .stroke(Color.white, lineWidth: 2)

                                    CropCornersOverlay()
                                        .stroke(
                                            Color.white,
                                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                                        )
                                }
                            }

                        ForEach(CropHandlePosition.allCases, id: \.self) { handle in
                            cropHandle
                                .position(handle.point(in: cropRect))
                                .gesture(resizeGesture(for: handle, within: imageFrame))
                        }
                    }
                }
                .frame(width: editorSize.width, height: editorSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.32), radius: 24, y: 14)
                .onAppear {
                    configureInitialCropRect(in: imageFrame)
                    imageOffset = clampedImageOffset(imageOffset, within: imageFrame)
                }
                .onChange(of: imageFrame) { _, newFrame in
                    configureInitialCropRect(in: newFrame)
                    imageOffset = clampedImageOffset(imageOffset, within: newFrame)
                }

                Text("Drag to move. Pull any corner to resize.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.top, 18)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [Color.black, Color(red: 0.11, green: 0.12, blue: 0.16)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }

    private var cropHandle: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)

            Circle()
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                .frame(width: 14, height: 14)
        }
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
    }

    private func header(imageFrame: CGRect) -> some View {
        HStack {
            Button("取消", action: onCancel)
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            Text("裁剪头像")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Spacer()

            Button("使用") {
                confirmCrop(imageFrame: imageFrame)
            }
            .foregroundStyle(.white)
            .fontWeight(.semibold)
        }
    }

    private func editorCanvasSize(in containerSize: CGSize) -> CGSize {
        let width = max(260, containerSize.width - 32)
        let height = max(320, containerSize.height - 220)
        return CGSize(width: width, height: height)
    }

    private func configureInitialCropRect(in imageFrame: CGRect) {
        guard imageFrame.width > 0, imageFrame.height > 0 else { return }

        if cropRect == .zero {
            let side = max(
                min(imageFrame.width, imageFrame.height),
                min(minimumCropSide, min(imageFrame.width, imageFrame.height))
            )
            cropRect = CGRect(
                x: imageFrame.midX - side / 2,
                y: imageFrame.midY - side / 2,
                width: side,
                height: side
            )
            return
        }

        let side = min(cropRect.width, min(imageFrame.width, imageFrame.height))
        let clampedX = min(max(cropRect.minX, imageFrame.minX), imageFrame.maxX - side)
        let clampedY = min(max(cropRect.minY, imageFrame.minY), imageFrame.maxY - side)
        cropRect = CGRect(x: clampedX, y: clampedY, width: side, height: side)
    }

    private func moveImageGesture(within imageFrame: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDraggingImage {
                    dragStartOffset = imageOffset
                    isDraggingImage = true
                }

                imageOffset = movedImageOffset(
                    from: dragStartOffset,
                    translation: value.translation,
                    imageFrame: imageFrame
                )
            }
            .onEnded { _ in
                isDraggingImage = false
            }
    }

    private func resizeGesture(
        for handle: CropHandlePosition,
        within imageFrame: CGRect
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if activeResizeHandle != handle {
                    resizeStartRect = cropRect
                    activeResizeHandle = handle
                }

                cropRect = resizedCropRect(
                    from: resizeStartRect,
                    translation: value.translation,
                    imageFrame: imageFrame,
                    handle: handle
                )
                imageOffset = clampedImageOffset(imageOffset, within: imageFrame)
            }
            .onEnded { _ in
                activeResizeHandle = nil
            }
    }

    private func movedImageOffset(
        from offset: CGSize,
        translation: CGSize,
        imageFrame: CGRect
    ) -> CGSize {
        clampedImageOffset(
            CGSize(
                width: offset.width + translation.width,
                height: offset.height + translation.height
            ),
            within: imageFrame
        )
    }

    private func clampedImageOffset(_ proposedOffset: CGSize, within imageFrame: CGRect) -> CGSize {
        let minX = cropRect.maxX - imageFrame.maxX
        let maxX = cropRect.minX - imageFrame.minX
        let minY = cropRect.maxY - imageFrame.maxY
        let maxY = cropRect.minY - imageFrame.minY

        return CGSize(
            width: min(max(proposedOffset.width, minX), maxX),
            height: min(max(proposedOffset.height, minY), maxY)
        )
    }

    private func resizedCropRect(
        from rect: CGRect,
        translation: CGSize,
        imageFrame: CGRect,
        handle: CropHandlePosition
    ) -> CGRect {
        let minSide = min(minimumCropSide, min(imageFrame.width, imageFrame.height))

        switch handle {
        case .topLeading:
            let fixed = CGPoint(x: rect.maxX, y: rect.maxY)
            let proposedMinX = min(max(rect.minX + translation.width, imageFrame.minX), fixed.x - minSide)
            let proposedMinY = min(max(rect.minY + translation.height, imageFrame.minY), fixed.y - minSide)
            let maxSide = min(fixed.x - imageFrame.minX, fixed.y - imageFrame.minY)
            let side = min(max(min(fixed.x - proposedMinX, fixed.y - proposedMinY), minSide), maxSide)
            return CGRect(x: fixed.x - side, y: fixed.y - side, width: side, height: side)
        case .topTrailing:
            let fixed = CGPoint(x: rect.minX, y: rect.maxY)
            let proposedMaxX = max(min(rect.maxX + translation.width, imageFrame.maxX), fixed.x + minSide)
            let proposedMinY = min(max(rect.minY + translation.height, imageFrame.minY), fixed.y - minSide)
            let maxSide = min(imageFrame.maxX - fixed.x, fixed.y - imageFrame.minY)
            let side = min(max(min(proposedMaxX - fixed.x, fixed.y - proposedMinY), minSide), maxSide)
            return CGRect(x: fixed.x, y: fixed.y - side, width: side, height: side)
        case .bottomLeading:
            let fixed = CGPoint(x: rect.maxX, y: rect.minY)
            let proposedMinX = min(max(rect.minX + translation.width, imageFrame.minX), fixed.x - minSide)
            let proposedMaxY = max(min(rect.maxY + translation.height, imageFrame.maxY), fixed.y + minSide)
            let maxSide = min(fixed.x - imageFrame.minX, imageFrame.maxY - fixed.y)
            let side = min(max(min(fixed.x - proposedMinX, proposedMaxY - fixed.y), minSide), maxSide)
            return CGRect(x: fixed.x - side, y: fixed.y, width: side, height: side)
        case .bottomTrailing:
            let fixed = CGPoint(x: rect.minX, y: rect.minY)
            let proposedMaxX = max(min(rect.maxX + translation.width, imageFrame.maxX), fixed.x + minSide)
            let proposedMaxY = max(min(rect.maxY + translation.height, imageFrame.maxY), fixed.y + minSide)
            let maxSide = min(imageFrame.maxX - fixed.x, imageFrame.maxY - fixed.y)
            let side = min(max(min(proposedMaxX - fixed.x, proposedMaxY - fixed.y), minSide), maxSide)
            return CGRect(x: fixed.x, y: fixed.y, width: side, height: side)
        }
    }

    private func confirmCrop(imageFrame: CGRect) {
        let displayedImageFrame = imageFrame.offsetBy(dx: imageOffset.width, dy: imageOffset.height)
        guard let croppedImage = AvatarUploadImageProcessor.cropImage(
            normalizedImage,
            from: cropRect,
            displayedIn: displayedImageFrame
        ) else {
            onCancel()
            return
        }

        onConfirm(croppedImage)
    }
}

private enum CropHandlePosition: CaseIterable, Hashable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .topLeading:
            return CGPoint(x: rect.minX, y: rect.minY)
        case .topTrailing:
            return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeading:
            return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomTrailing:
            return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
}

private struct CropCornersOverlay: Shape {
    private let armLength: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: armLength, y: 0))
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: armLength))

        path.move(to: CGPoint(x: rect.width - armLength, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.move(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: armLength))

        path.move(to: CGPoint(x: 0, y: rect.height - armLength))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: armLength, y: rect.height))

        path.move(to: CGPoint(x: rect.width - armLength, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.move(to: CGPoint(x: rect.width, y: rect.height - armLength))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        return path
    }
}

private struct CropSelectionMask: Shape {
    let cropRect: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRect(cropRect)
        return path
    }
}

#Preview {
    SquareAvatarCropperSheet(
        image: UIImage(systemName: "person.crop.circle.fill") ?? UIImage(),
        onCancel: {},
        onConfirm: { _ in }
    )
}
