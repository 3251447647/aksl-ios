import SwiftUI
import Photos
import UIKit

/// 聊天相册：应用内展示图片/视频，图片最多多选 9 张，视频单选。
struct ChatMediaPicker: View {
    private enum Filter: String, CaseIterable, Identifiable, Hashable {
        case images = "图片"
        case videos = "视频"

        var id: String { rawValue }
        var mediaType: PHAssetMediaType {
            self == .images ? .image : .video
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var filter: Filter = .images
    @State private var assets: [PHAsset] = []
    @State private var selectedIDs: [String] = []
    @State private var loading = true
    @State private var loadingSelection = false
    @State private var denied = false

    let onImages: ([UIImage]) -> Void
    let onVideo: (PHAsset) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if denied {
                    emptyState(
                        title: "无法访问相册",
                        icon: "photo.on.rectangle.angled",
                        detail: "请在系统设置中允许 AK商聊访问照片"
                    )
                } else if loading {
                    ProgressView("正在加载相册…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if assets.isEmpty {
                    emptyState(
                        title: filter == .images ? "暂无图片" : "暂无视频",
                        icon: filter == .images ? "photo" : "video",
                        detail: nil
                    )
                } else {
                    assetGrid
                }
            }
            .background(AKColor.bg.ignoresSafeArea())
            .navigationTitle("相册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Picker("媒体类型", selection: $filter) {
                        ForEach(Filter.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(selectedIDs.isEmpty ? "完成" : "完成（\(selectedIDs.count)）") {
                        finishSelection()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedIDs.isEmpty || loadingSelection)
                }
            }
        }
        .task {
            await loadAssets()
        }
        .onChange(of: filter) { _ in
            selectedIDs.removeAll()
            Task { await loadAssets() }
        }
        .overlay {
            if loadingSelection {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView("正在准备媒体…")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(AKColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func emptyState(title: String, icon: String, detail: String?) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(AKColor.sub)
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AKColor.text)
            if let detail {
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(AKColor.sub)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var assetGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 4),
                spacing: 2
            ) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    ChatMediaThumbnail(
                        asset: asset,
                        selectionIndex: selectedIDs.firstIndex(of: asset.localIdentifier),
                        onTap: { toggle(asset) }
                    )
                    .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(2)
        }
    }

    @MainActor
    private func loadAssets() async {
        loading = true
        denied = false
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let granted: Bool
        if status == .notDetermined {
            let requested = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            granted = requested == .authorized || requested == .limited
        } else {
            granted = status == .authorized || status == .limited
        }
        guard granted else {
            denied = true
            loading = false
            return
        }

        var result: [PHAsset] = []
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeHiddenAssets = false
        let fetched = PHAsset.fetchAssets(with: filter.mediaType, options: options)
        fetched.enumerateObjects { asset, _, _ in
            result.append(asset)
        }
        assets = result
        loading = false
    }

    private func toggle(_ asset: PHAsset) {
        let id = asset.localIdentifier
        if asset.mediaType == .video {
            selectedIDs = selectedIDs == [id] ? [] : [id]
            return
        }

        if let index = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: index)
            return
        }
        guard selectedIDs.count < 9 else { return }
        selectedIDs.removeAll { selectedID in
            assets.first(where: { $0.localIdentifier == selectedID })?.mediaType == .video
        }
        selectedIDs.append(id)
    }

    private func finishSelection() {
        let picked = selectedIDs.compactMap { id in
            assets.first(where: { $0.localIdentifier == id })
        }
        guard !picked.isEmpty else { return }

        if let video = picked.first(where: { $0.mediaType == .video }) {
            onVideo(video)
            dismiss()
            return
        }

        loadingSelection = true
        Task {
            var images: [UIImage] = []
            for asset in picked where asset.mediaType == .image {
                if let image = await loadImage(asset) {
                    images.append(image)
                }
            }
            await MainActor.run {
                loadingSelection = false
                if !images.isEmpty { onImages(images) }
                dismiss()
            }
        }
    }

    private func loadImage(_ asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            let longest = CGFloat(max(max(asset.pixelWidth, asset.pixelHeight), 1))
            let scale = min(1, 2048 / longest)
            let target = CGSize(
                width: CGFloat(max(asset.pixelWidth, 1)) * scale,
                height: CGFloat(max(asset.pixelHeight, 1)) * scale
            )
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: target,
                contentMode: .default,
                options: options
            ) { image, info in
                if (info?[PHImageCancelledKey] as? Bool) == true
                    || (info?[PHImageErrorKey] as? Error) != nil {
                    continuation.resume(returning: nil)
                } else if (info?[PHImageResultIsDegradedKey] as? Bool) != true {
                    continuation.resume(returning: image)
                }
            }
        }
    }
}

private struct ChatMediaThumbnail: View {
    let asset: PHAsset
    let selectionIndex: Int?
    let onTap: () -> Void
    @State private var image: UIImage?

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        AKColor.fill
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                if asset.mediaType == .video {
                    HStack(spacing: 3) {
                        Image(systemName: "video.fill")
                        Text(Self.duration(asset.duration))
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Capsule())
                    .padding(5)
                }

                if let selectionIndex {
                    ZStack {
                        Circle()
                            .fill(AKColor.brand)
                        Text("\(selectionIndex + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .task(id: asset.localIdentifier) {
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            let target = CGSize(width: 240, height: 240)
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: target,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image {
                    Task { @MainActor in self.image = image }
                }
            }
        }
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
