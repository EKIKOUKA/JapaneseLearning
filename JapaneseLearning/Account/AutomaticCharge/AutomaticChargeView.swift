//
//  AutomaticChargeView.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 2026/11/02.
//
import SwiftUI

enum AutomaticChargeKind: String, CaseIterable, Identifiable {
    case monthly
    case lowBalance = "low_balance"

    var id: String { rawValue }
    var title: String {
        switch self {
            case .monthly: "毎月のチャージ"
            case .lowBalance: "残高不足時の追加チャージ"
        }
    }
    
    var subtitle: String {
        switch self {
            case .monthly: "指定した日に固定金額をチャージ"
            case .lowBalance: "残高が少なくなったら自動で補充"
        }
    }
    
    var symbol: String {
        switch self {
            case .monthly: "calendar"
            case .lowBalance: "arrow.clockwise.circle"
        }
    }
}

struct AutomaticChargeView: View {
    @Environment(AppleAccountStore.self) private var accountStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings: [AutomaticChargeSetting] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("現在の残高", value: "\(accountStore.accountCredits.formatted()) クレジット")
                Label("サンドボックス・実際の請求は発生しません", systemImage: "testtube.2")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(AutomaticChargeKind.allCases) { kind in
                    NavigationLink {
                        AutomaticChargeDetailView(kind: kind) {
                            settings = $0
                            errorMessage = nil
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: kind.symbol)
                                .font(.title3)
                                .foregroundStyle(.tint)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(kind.title)
                                Text(kind.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            if isLoading {
                                ProgressView()
                            } else {
                                Text(settings.first { $0.type == kind.rawValue }?.statusText ?? "未設定")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            } footer: {
                Text("両方を組み合わせて利用できます。設定・変更には、それぞれ Apple Pay での承認が必要です。")
            }

            Section {
                Text("チャージで受け取れるクレジット数は変更される場合があります。お支払い金額は承認した設定を使用します。")
                Text("停止すると新しい自動決済を作成しません。すでに処理中のお支払いは完了する場合があります。")
                Text("変更の承認中は、その種類の以前の設定を一時停止します。キャンセルした場合は再承認してください。")
            }
            .font(.footnote).foregroundStyle(.secondary)

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                    Button("再読み込み") { Task { await load() } }
                }
            }
        }
        .navigationTitle("自動チャージ")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await load() } }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            settings = try await accountStore.automaticChargeSettings().settings
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
