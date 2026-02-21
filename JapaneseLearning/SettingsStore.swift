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
    var showGrammarListCount: Bool = true
    var showGrammarListAllItemTag: Bool = false
    var showGrammarEditorButton: Bool = true
    var showGrammarListItemImportantImage: Bool = true
    var showGrammarListItemSwipeActions: Bool = true

    var Nationality: String = "JP"

    // Shadowing
    var showShadowingSubtitlesRuby: Bool = true
    var videoSubtitleLineWithAnimation: VideoSubtitleLineWithAnimation = .natural
    var videoSubtitleFontSizeScale: Double = 1.0
    var videoSubtitleFontStyle: VideoSubtitleRubyFontStyle = .system
    var videoSubtitleDimInactiveLines: Bool = false

    // Somethings
    var showKanjiWordsDiffToShinaLangListCount: Bool = true
    var showMemoryHardWordsListCount: Bool = true
    var showElegantSentenceListCount: Bool = true
    var showIdiomsListCount: Bool = true
    var showSampleRubyWordsListCount: Bool = true
    var showMediaProductsListCount: Bool = true
}

@Observable
@dynamicMemberLookup
final class SettingsStore {
    @ObservationIgnored
    @AppStorage("appSettings") private var settingsData: Data = Data()

    private var _settings: AppSettings = AppSettings()

    var settings: AppSettings {
        get {
            _settings
        }
        set {
            _settings = newValue
            save()
        }
    }

    subscript<T>(dynamicMember keyPath: WritableKeyPath<AppSettings, T>) -> T {
        get { _settings[keyPath: keyPath] }
        set {
            _settings[keyPath: keyPath] = newValue
            save()
        }
    }

    init() {
        if let decoded = try? JSONDecoder().decode(AppSettings.self, from: settingsData) {
            self._settings = decoded
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(_settings) {
            settingsData = encoded
        }
    }
}
