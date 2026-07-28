//
//  VideoStatusLiveActivity.swift
//  VideoStatus
//
//  Created by 宇都宮　誠 on 6/19/R8.
//

import ActivityKit
import WidgetKit
import SwiftUI
import UIKit

nonisolated struct VideoStatusAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        var progress: Double
        var status: String
        var errorMessage: String
    }

    var videoId: String
    var videoTitle: String
}

private struct LiveActivityThumbnail: View {
    let videoID: String
    let size: CGSize
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let url = AppGroupThumbnailStorage.existingFileURL(for: videoID),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                Image(uiImage: presentationImage(from: image))
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipShape(.rect(cornerRadius: cornerRadius))
            } else {
                Image(systemName: "play.rectangle.fill")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipShape(.rect(cornerRadius: cornerRadius))
            }
        }
    }

    private func presentationImage(from image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let scale = max(size.width / image.size.width, size.height / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}

struct VideoStatusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VideoStatusAttributes.self) { context in
            Group {
                HStack(alignment: .center, spacing: 10) {
                    LiveActivityThumbnail(
                        videoID: context.attributes.videoId,
                        size: CGSize(width: 64, height: 36),
                        cornerRadius: 8
                    )
                    .foregroundStyle(.primary)

                    Text(context.attributes .videoTitle)
                        .font(.headline)
                        .lineLimit(1...)
                        .layoutPriority(1)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 12) {
                    if !context.state.errorMessage.isEmpty {
                        Text(context.state.errorMessage)
                            .lineLimit(1...2)
                    } else {
                        Text(context.state.status)
                            .font(.body)
                    }

                    ProgressView(value: context.state.progress)
                        .tint(.primary)

                    HStack {
                        Spacer()

                        Text("\(Int(context.state.progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 5)
            }
            .padding(15)
            .activityBackgroundTint(Color(.systemBackground))
            .widgetURL(URL(string: "japaneselearning://video/\(context.attributes.videoId)"))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(alignment: .center, spacing: 10) {
                        LiveActivityThumbnail(
                            videoID: context.attributes.videoId,
                            size: CGSize(width: 52, height: 30),
                            cornerRadius: 6
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(context.attributes.videoTitle)
                                .font(.headline)
                                .lineLimit(2)

                            Text(context.state.status)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ProgressView(value: context.state.progress, total: 1.0)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                LiveActivityThumbnail(
                    videoID: context.attributes.videoId,
                    size: CGSize(width: 22, height: 22),
                    cornerRadius: 4
                )
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%")
            } minimal: {
                LiveActivityThumbnail(
                    videoID: context.attributes.videoId,
                    size: CGSize(width: 22, height: 22),
                    cornerRadius: 4
                )
            }
        }
    }
}


#Preview("準備中", as: .content, using: VideoStatusAttributes(
    videoId: "j10LhF7F7F8",
    videoTitle: "日本語シャドーイング"
)) {
    VideoStatusLiveActivity()
} contentStates: {
    VideoStatusAttributes.ContentState(
        progress: 0.0,
        status: "レッスンを準備しています",
        errorMessage: ""
    )
}

#Preview("downloaded", as: .content, using: VideoStatusAttributes(
    videoId: "j10LhF7F7F8",
    videoTitle: "日本語シャドーイング"
)) {
    VideoStatusLiveActivity()
} contentStates: {
    VideoStatusAttributes.ContentState(
        progress: 0.2,
        status: "動画のダウンロードが完了しました",
        errorMessage: ""
    )
}

#Preview("whisper-transcribed", as: .content, using: VideoStatusAttributes(
    videoId: "j10LhF7F7F8",
    videoTitle: "日本語シャドーイング"
)) {
    VideoStatusLiveActivity()
} contentStates: {
    VideoStatusAttributes.ContentState(
        progress: 0.5,
        status: "AI音声認識、字幕が生成しました",
        errorMessage: ""
    )
}

#Preview("FFmpeg-sliced", as: .content, using: VideoStatusAttributes(
    videoId: "j10LhF7F7F8",
    videoTitle: "日本語シャドーイング"
)) {
    VideoStatusLiveActivity()
} contentStates: {
    VideoStatusAttributes.ContentState(
        progress: 0.75,
        status: "動画の切片化処理が完了しました",
        errorMessage: ""
    )
}

#Preview("uploaded-R2", as: .content, using: VideoStatusAttributes(
    videoId: "j10LhF7F7F8",
    videoTitle: "日本語シャドーイング"
)) {
    VideoStatusLiveActivity()
} contentStates: {
    VideoStatusAttributes.ContentState(
        progress: 0.9,
        status: "ストレージにアップロードが完了しました",
        errorMessage: ""
    )
}

#Preview("ready", as: .content, using: VideoStatusAttributes(
    videoId: "j10LhF7F7F8",
    videoTitle: "蚊に刺された、どこが一番痒い？蚊に刺された、どこが一番痒い？"
)) {
    VideoStatusLiveActivity()
} contentStates: {
    VideoStatusAttributes.ContentState(
        progress: 1.0,
        status: "動画の処理が完了しました！",
        errorMessage: ""
    )
}

#Preview("failed", as: .content, using: VideoStatusAttributes(
    videoId: "j10LhF7F7F8",
    videoTitle: "蚊に刺された、どこが一番痒い？蚊に刺された、どこが一番痒い？"
)) {
    VideoStatusLiveActivity()
} contentStates: {
    VideoStatusAttributes.ContentState(
        progress: 0.0,
        status: "エラーが発生しました",
        errorMessage: "通信エラー"
    )
}
