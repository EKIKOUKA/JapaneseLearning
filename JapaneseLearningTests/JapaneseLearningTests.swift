//
//  JapaneseLearningTests.swift
//  JapaneseLearningTests
//
//  Created by 宇都宮　誠 on R 8/02/08.
//

import Testing
@testable import JapaneseLearning

struct JapaneseLearningTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @MainActor
    @Test func testSubtitleTimelineUpdates() async throws {
        // 模擬 PlayerViewModel
        let playerVM = await PlayerViewModel()
        let line1 = CaptionLine(id: "1", start: 0.0, end: 2.0, text: "Hello", ruby: nil)
        let line2 = CaptionLine(id: "2", start: 2.0, end: 4.0, text: "World", ruby: nil)
        playerVM.captions = [line1, line2]

        // 當播放時間在第一行範圍內
        await playerVM.seek(to: 1.0)
        await Task.sleep(100)

        // 應該當前行是第一行
        #expect(playerVM.currentLineID == "1")

        // 當播放時間在第二行範圍內
        await playerVM.seek(to: 2.0)
        await Task.sleep(100)

        // 應該當前行是第二行
        #expect(playerVM.currentLineID == "2")
    }

    @MainActor
    @Test func testSeekUpdatesSubtitles() async throws {
        // 模擬 PlayerViewModel
        let playerVM = await PlayerViewModel()
        let line1 = CaptionLine(id: "1", start: 0.0, end: 2.0, text: "Hello", ruby: nil)
        playerVM.captions = [line1]

        // 當播放時間在第一行範圍內
        await playerVM.seek(to: 1.0)
        try await Task.sleep(nanoseconds: 100)

        // 應該當前行是第一行
        #expect(playerVM.currentLineID == "1")
    }

    @MainActor
    @Test func testLoopBehavior() async throws {
        // 模擬 PlayerViewModel
        let playerVM = await PlayerViewModel()
        let line1 = CaptionLine(id: "1", start: 0.0, end: 2.0, text: "Loop", ruby: nil)
        playerVM.captions = [line1]
        await playerVM.playLine(line1) // 設置當前行

        // 開啟單行循環
        await playerVM.toggleSingleLineLoop()
        // 尋找到超過第一行結束的時間
        await playerVM.seek(to: 2.1)

        // 應該回到循環目標的行
        #expect(playerVM.currentLineID == line1.id)
    }
}
