import SwiftUI

struct PodcastCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void
    @State private var language: VideoContentLanguage = .ja
    @State private var browseIndex = 0
    @State private var shows: [ApplePodcastCatalog.Show] = []
    @State private var query = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var retry = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("ストア", selection: $language) {
                        ForEach(VideoContentLanguage.allCases, id: \.self) {
                            Text($0 == .ja ? "日本ストア" : "米国ストア").tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                ForEach(shows) { show in
                    NavigationLink {
                        PodcastChapterList(title: show.collectionName, onComplete: onComplete) {
                            try await ApplePodcastCatalog.episodes(for: show, language: language)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(show.collectionName)
                            if let author = show.artistName {
                                Text(author).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.secondary)
                    Button("再試行") { retry += 1 }
                } else {
                    if shows.isEmpty {
                        Text("RSS付きの番組が見つかりません").foregroundStyle(.secondary)
                    } else {
                        Text("RSS付きの番組：\(shows.count)件取得").foregroundStyle(.secondary)
                    }

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       browseIndex + 1 < browseTerms.count {
                        Button("さらに探す：\(browseTerms[browseIndex + 1])") { browseIndex += 1 }
                    }
                }
            }
            .searchable(text: $query, prompt: "番組名・キーワードで検索")
            .onChange(of: query) { _, _ in resetSearch() }
            .onChange(of: language) { _, _ in resetSearch() }
            .navigationTitle("Podcast を探す")
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
            .task(id: SearchRequest(query: query, language: language, browseIndex: browseIndex, retry: retry)) {
                await search()
            }
        }
    }

    private struct SearchRequest: Hashable {
        let query: String
        let language: VideoContentLanguage
        let browseIndex: Int
        let retry: Int
    }

    private var browseTerms: [String] {
        language == .ja
            ? ["ニュース", "雑談", "科学", "歴史", "文化", "テクノロジー"]
            : ["podcast", "science", "history", "culture", "technology", "news"]
    }

    private func resetSearch() {
        shows = []
        browseIndex = 0
        errorMessage = nil
        isLoading = true
    }

    private func search() async {
        let requestedLanguage = language
        let requestedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        isLoading = true
        do {
            if !requestedQuery.isEmpty {
                try await Task.sleep(for: .milliseconds(350))
            }
            let term = requestedQuery.isEmpty ? browseTerms[browseIndex] : requestedQuery
            let append = requestedQuery.isEmpty && browseIndex > 0
            let result = try await ApplePodcastCatalog.search(term, language: requestedLanguage)
            try Task.checkCancellation()
            if !append { shows = [] }
            var ids = Set(shows.map(\.id))
            shows.append(contentsOf: result.filter { ids.insert($0.id).inserted })
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct PodcastChapterList: View {
    let title: String
    let onComplete: () -> Void
    let loadEpisodes: () async throws -> [PodcastEpisode]
    @State private var episodes: [PodcastEpisode] = []
    @State private var selectedEpisodeIDs = Set<String>()
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var addError: String?
    @State private var retry = 0

    var body: some View {
        List {
            if loading {
                ProgressView()
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.secondary)
                Button("再試行") { retry += 1 }
            } else if episodes.isEmpty {
                Text("再生できるエピソードが見つかりません").foregroundStyle(.secondary)
            }
            ForEach(episodes) { episode in
                let added = PodcastLibrary.shared.episode(id: episode.id) != nil
                let selected = selectedEpisodeIDs.contains(episode.id)
                Button {
                    guard !added else { return }
                    if selected { selectedEpisodeIDs.remove(episode.id) }
                    else { selectedEpisodeIDs.insert(episode.id) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: added ? "checkmark.circle.fill" : (selected ? "checkmark.circle.fill" : "circle"))
                            .foregroundStyle(added ? Color.secondary : (selected ? Color.accentColor : Color.secondary))
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(episode.title).foregroundStyle(.primary)
                            if let reader = episode.reader {
                                Text(reader).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let duration = episode.durationSeconds {
                            Text(Duration.seconds(duration).formatted(.time(pattern: .hourMinuteSecond)))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    addSelectedEpisodes()
                } label: {
                    Image(systemName: "checkmark")
                }
                .disabled(selectedEpisodeIDs.isEmpty || loading)
            }
        }
        .task(id: retry) {
            loading = true
            errorMessage = nil
            do {
                let result = try await loadEpisodes()
                try Task.checkCancellation()
                episodes = result
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            loading = false
        }
        .alert("追加できませんでした", isPresented: Binding(
            get: { addError != nil }, set: { if !$0 { addError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(addError ?? "")
        }
    }

    private func addSelectedEpisodes() {
        let selectedEpisodes = episodes.filter { selectedEpisodeIDs.contains($0.id) }
        do {
            for episode in selectedEpisodes {
                try PodcastLibrary.shared.add(episode)
            }
            onComplete()
        } catch {
            addError = error.localizedDescription
        }
    }
}
