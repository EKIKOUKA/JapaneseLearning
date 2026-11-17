//
//  VideoAISheet.swift
//  JapaneseLearning
//
//  Created by Makoto on 2026/11/07.
//

import SwiftUI

struct VideoAISheet: View {
    let video: VideoItem
    let onCaptionsChanged: () async -> Void
    @State private var mode: VideoAIMode = .segmentation
    @State private var quote: VideoAIQuote?
    @State private var job: VideoAIJob?
    @State private var versions: CaptionVersionsResponse?
    @State private var error: String?
    @State private var busy = false
    @State private var showConfirm = false
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let job {
                    Section {
                        Text(job.stageTitle)
                        if job.status == "pending" && job.stage != "queued" {
                            ProgressView(value: job.progress, total: 100)
                            Text("\(Int(job.progress))%")
                        }
                        if let message = job.error {
                            Text(message).foregroundStyle(.red)
                        }
                    }
                }

                Section {
                    Picker("処理方法", selection: $mode) {
                        Text(VideoAIMode.segmentation.title).tag(VideoAIMode.segmentation)
                        Text(VideoAIMode.transcription.title).tag(VideoAIMode.transcription)
                    }
                    
                    Button("料金を確認") {
                        Task {
                            await fetchQuote()
                        }
                    }
                    .disabled(busy || job?.status == "pending")
                } footer: {
                    Text("成功した場合のみクレジットを消費します。処理中は必要な額を確保します。元の字幕は残ります。")
                }

                if let versions {
                    Section("字幕のバージョン") {
                        ForEach(versions.versions) { version in
                            Button {
                                Task {
                                    await select(version)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(version.title)
                                        Text(serverDateTimeInJST(version.created_at))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if versions.active_version == version.id { Image(systemName: "checkmark") }
                                }
                            }
                            .disabled(busy || job?.status == "pending")
                        }
                    }
                }

                if let error {
                    Text(error).foregroundStyle(.red)
                }
            }
            .navigationTitle("字幕の生成・切り替え")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .confirmationDialog("\(quote?.credits ?? 0) クレジットで生成しますか？", isPresented: $showConfirm, titleVisibility: .visible) {
                Button("生成を開始") {
                    Task {
                        await start()
                    }
                }
            }
            .task {
                await refresh()

                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: .seconds(3))
                    } catch {
                        break
                    }
                    
                    await WorkersAPI.$reportsErrors.withValue(false) { await refresh() }
                }
            }
        }
    }

    private func fetchQuote() async {
        busy = true;
        error = nil
        defer { busy = false }

        do {
            var body = ["youtube_id": video.youtubeID, "mode": mode.rawValue]
            if mode == .segmentation {
                body["provider"] = settingsStore.AIProvider
            }
            quote = try await WorkersAPI.postForResponse(
                "video_ai/quote",
                body: body,
                requiresAuthentication: true
            )
            showConfirm = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func start() async {
        guard let quote else { return }
        busy = true;
        error = nil
        defer { busy = false }

        do {
            let result: VideoAIJob = try await WorkersAPI.postForResponse(
                "video_ai/start",
                body: ["video_id": video.id, "quote_id": quote.id],
                requiresAuthentication: true
            )
            job = result
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func refresh() async {
        do {
            let status: VideoAIStatus = try await WorkersAPI.get(
                "video_ai/status",
                queryItems: [
                    URLQueryItem(
                        name: "video_id",
                        value: video.id
                    )
                ],
                requiresAuthentication: true
            )
            
            let becameComplete = job?.status == "pending" && status.job?.status == "completed"
            job = status.job
            versions = try await WorkersAPI.get(
                "video_ai/versions",
                queryItems: [
                    URLQueryItem(
                        name: "video_id",
                        value: video.id
                    )
                ],
                requiresAuthentication: true
            )
            
            if becameComplete {
                await onCaptionsChanged()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func select(_ version: CaptionVersion) async {
        busy = true;
        error = nil
        defer { busy = false }

        do {
            try await WorkersAPI.post(
                "video_ai/select_version",
                body: [
                    "video_id": video.id,
                    "version_id": version.id
                ],
                requiresAuthentication: true
            )
            await onCaptionsChanged()
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
