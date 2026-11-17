//
//  LoginSessionsView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/11/16.
//

import SwiftUI

struct LoginSessionsView: View {
    @State private var sessions: [LoginSession] = []
    @State private var selected: LoginSession?
    @State private var isLoading = true
    @State private var isRevoking = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(session.deviceName?.isEmpty == false ? session.deviceName! : "不明な端末")
                                .font(.headline)
                            
                            if session.isCurrent == 1 {
                                Text("この端末")
                                    .font(.caption).foregroundStyle(.green)
                            }
                        }

                        Text(session.lastSeenAt.map { "最終利用：\(serverDateTimeInJST($0))" } ?? "最終利用：未記録")
                        .font(.caption).foregroundStyle(.secondary)
                        
                        if session.isCurrent != 1 {
                            Button("このログインを解除", role: .destructive) {
                                selected = session
                            }
                            .disabled(isRevoking)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                if isLoading {
                    ProgressView()
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("ログイン中：\(sessions.count) 件")
            } footer: {
                Text("同じ App・端末での再ログインは既存のログインを置き換えます。最終利用時刻は最大 15 分間隔で更新されます。")
            }
        }
        .navigationTitle("ログイン中の端末")
        .task { await load() }
        .refreshable { await load() }
        .confirmationDialog("このログインを解除しますか？", isPresented: Binding(
            get: { selected != nil }, set: { if !$0 { selected = nil } }
        ), titleVisibility: .visible) {
            if let session = selected {
                Button("ログインを解除", role: .destructive) {
                    Task {
                        await revoke(session)
                    }
                }
            }
        } message: {
            Text("対象のログインでは API を利用できなくなります。再度 Apple でログインすると利用を再開できます。")
        }
    }

    private func load() async {
        defer { isLoading = false }
        
        do {
            sessions = try await WorkersAPI.get("user/sessions", requiresAuthentication: true)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func revoke(_ session: LoginSession) async {
        guard !isRevoking else { return }
        isRevoking = true
        defer { isRevoking = false }
        
        do {
            try await WorkersAPI.post(
                "user/sessions/revoke",
                body: ["id": session.id],
                requiresAuthentication: true
            )
            sessions.removeAll { $0.id == session.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
