//
//  SettingsStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/15.
//

import SwiftUI
import Observation

struct AppSettings: Codable {
    // Grammar
    var showGrammarListAddButton: Bool = false
    var showGrammarListCount: Bool = false
    var showGrammarListAllItemTag: Bool = false
    var showGrammarEditorButton: Bool = false
    var showGrammarListItemImportantImage: Bool = false
    var showGrammarListItemSwipeActions: Bool = false

    // Shadowing
    var showShadowingSubtitlesRuby: Bool = false
    var videoSubtitleLineWithAnimation: VideoSubtitleLineWithAnimation = .spring
    var videoSubtitleFontSizeScale: Double = 1.0
    var videoSubtitleDimInactiveLines: Bool = false

    // Somethings
    var showKanjiWordsDiffToShinaLangListCount: Bool = false
    var showMemoryHardWordsListCount: Bool = false
    var showElegantSentenceListCount: Bool = false
    var showIdiomsListCount: Bool = false
    var showSampleRubyWordsListCount: Bool = false
    var showMediaProductsListCount: Bool = false
}

@Observable
final class SettingsStore {
    private let data = "appSettings"

    var settings: AppSettings {
        didSet {
            save()
        }
    }

    init() {
        if let _data = UserDefaults.standard.data(forKey: data),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: _data) {
            self.settings = decoded
        } else {
            self.settings = AppSettings()
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: data)
        }
    }
}
