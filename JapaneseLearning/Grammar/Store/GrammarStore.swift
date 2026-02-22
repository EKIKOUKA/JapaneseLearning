//
//  GrammarStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/11/28.
//

import Foundation
import Supabase
import Combine

class GrammarStore: ObservableObject {

    @Published var grammars: [GrammarItem] = []
    @Published var isLoading = true

    init() {
        Task { @MainActor in
            await fetchAll()
        }
    }

    let client = SupabaseClient(
        supabaseURL: URL(string: Config.supabaseJapaneseLearningURL)!,
        supabaseKey: Config.supabaseJapaneseLearningKey,
        options: SupabaseClientOptions(
            auth: .init(
                emitLocalSessionAsInitialSession: true
            )
        )
    )
    @MainActor
    func fetchAll() async {

        do {
            let response: [GrammarItem] = try await client
                .from("japanese_grammars")
                .select()
                .execute()
                .value

            self.grammars = response
            self.isLoading = false
        } catch {
            print("❌ Supabase Fetch Error：\(error)")
        }
    }


    private var channel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    @Published private(set) var isRealtimeConnected = false

    @MainActor
    func startRealtime() {
        guard !isRealtimeConnected else { return }
        print("🔵 Realtime...")
        channel = client.channel("grammar-changes")

        realtimeTask = Task {
            guard let channel else { return }

            let changeStream = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "japanese_grammars"
            )

            do {

                try await channel.subscribeWithError()
                print("🟢 Realtime Channel connection done!")
                isRealtimeConnected = true

                for try await change in changeStream {
                    print("🟣 changed！")
                    await MainActor.run {
                        switch change {
                            case .insert(let action):
                                if let newItem: GrammarItem = try? action.record.decode() {
                                    self.grammars.insert(newItem, at: 0)
                                }
                            case .update(let action):
                                if let updatedItem: GrammarItem = try? action.record.decode() {
                                    if let index = self.grammars.firstIndex(where: { $0.id == updatedItem.id }) {
                                        self.grammars[index] = updatedItem
                                    }
                                }
                            default:
                                break
                        }
                    }
                }
            } catch {
                print("🔴 Realtime stream ended or failed: \(error)")
                await stopRealtime()
            }
        }
    }
    @MainActor
    func stopRealtime() async {
        guard isRealtimeConnected else { return }
        print("⚪️ Stop Realtime")

        realtimeTask?.cancel()
        realtimeTask = nil
        if let channel {
            await channel.unsubscribe()
        }

        channel = nil
        isRealtimeConnected = false
    }

    @MainActor
    func toggleImportant(_ id: UUID) async {
        guard let index = grammars.firstIndex(where: { $0.id == id }) else { return }
        let originValue = grammars[index].isImportant

        grammars[index].isImportant.toggle()

        do {
            try await client
                .from("japanese_grammars")
                .update(["is_important": !originValue])
                .eq("id", value: id.uuidString)
                .execute()
        } catch {
            print("❌ Update failed:", error)
            grammars[index].isImportant = originValue
        }
    }

    @MainActor
    func toggleMarked(_ id: UUID) async {
        guard let index = grammars.firstIndex(where: { $0.id == id }) else { return }
        let originValue = grammars[index].isMarked
        grammars[index].isMarked.toggle()

        do {
            let _ = try await client
                .from("japanese_grammars")
                .update(["is_marked": !originValue])
                .eq("id", value: id.uuidString)
                .execute()
        } catch {
            print("❌ Update failed:", error)
            grammars[index].isMarked = originValue
        }
    }

    @MainActor
    func grammarAdd(_ addItem: GrammarItem) async {
        grammars.append(addItem)

        do {
            try await client
                .from("japanese_grammars")
                .insert([
                    "title": addItem.title,
                    "level": addItem.level,
                    "meaning": addItem.meaning,
                    "connection": addItem.connection,
                    "notes": addItem.notes,
                    "examples": addItem.examples
                ])
                .execute()
        } catch {
            print("❌ Add failed:", error)
            grammars.removeAll { $0.id == addItem.id }
        }
    }

    @MainActor
    func grammarUpdate(_ id: UUID, updatedItem: GrammarItem) async {
        guard let index = grammars.firstIndex(where: { $0.id == id }) else { return }

        let original = grammars[index]
        grammars[index] = updatedItem

        do {
            try await client
                .from("japanese_grammars")
                .update([
                    "title": updatedItem.title,
                    "meaning": updatedItem.meaning,
                    "connection": updatedItem.connection,
                    "notes": updatedItem.notes,
                    "examples": updatedItem.examples
                ])
                .eq("id", value: id.uuidString)
                .execute()
        } catch {
            print("❌ Update failed:", error)
            grammars[index] = original
        }
    }
}
