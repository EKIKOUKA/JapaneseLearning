//
//  AchieveSystemRecord.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 5/27/R8.
//

import SwiftUI

struct AchieveSystemRecord: View {
    let store: AchieveSystemStore

    var body: some View {
        VStack {
            List {
                ForEach(store.rawSessions.reversed(), id: \.id) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            Text(item.started_at)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            Spacer()

                            Image(systemName: "chevron.left.slash.chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }

                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                Text("\(Int(ceil(Double(item.duration_seconds) / 60.0))) 分")
                            }
                            HStack(spacing: 4) {
                                Image(
                                    systemName: item.content_language == "ja"
                                    ? "character.book.closed"
                                    : "globe"
                                )

                                Text(item.content_language == "ja" ? "日本語" : "英語")
                            }
                        }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            withAnimation(.spring(duration: 0.35)) {
                                store.rawSessions.removeAll { $0.id == item.id }
                            }

                            Task {
                                await store.deleteRawRecord(item.id)
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("記録")
        .toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)
    }
}
