//
//  SettingsStore.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/15.
//

import SwiftUI
import Observation

struct AppSettings: Codable {
    var Nationality: String = "JP"

    // Shadowing
    var showShadowingSubtitlesRuby: Bool = true
    var videoSubtitleLineWithAnimation: VideoSubtitleLineWithAnimation = .natural
    var videoSubtitleFontSizeScale: Double = 1.0
    var videoSubtitleFontStyle: VideoSubtitleRubyFontStyle = .system
    var videoSubtitleDimInactiveLines: Bool = true
    var videoAutoJumpToNextLine: Bool = false
    var videoAllowsPictureInPicturePlayback: Bool = false
    var useNativeVideoPlayer: Bool = false
    var videoSubtitleFontColor: Color.Resolved?
    var AIExplanationLanguage: String = "JP"
    var AIProvider: String = "Anthropic"
}

@Observable
@dynamicMemberLookup
final class SettingsStore {
    @ObservationIgnored
    @AppStorage("appSettings") private var settingsData: Data = Data()

    private var _settings: AppSettings = AppSettings()

    var videoSubtitleFontUIColor: UIColor {
        guard let subtitleFontColor = _settings.videoSubtitleFontColor else {
            return .white
        }

        return UIColor(Color(subtitleFontColor))
    }

    var videoSubtitleFontColorBinding: Binding<Color> {
        Binding(
            get: {
                self._settings.videoSubtitleFontColor.map(Color.init) ?? .white
            },
            set: { newColor in
                var newSettings = self._settings
                newSettings.videoSubtitleFontColor = newColor.resolve(
                    in: EnvironmentValues()
                )
                self._settings = newSettings
                self.save()
            }
        )
    }

    subscript<T>(dynamicMember keyPath: WritableKeyPath<AppSettings, T>) -> T {
        get { _settings[keyPath: keyPath] }
        set {
            _settings[keyPath: keyPath] = newValue
            save()
        }
    }

    init() {
        // Older saved settings do not contain the new AI language preference.
        var data = settingsData
        if var values = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            values["aiExplanationLanguage"] == nil {
            values["aiExplanationLanguage"] = "JP"
            data = (try? JSONSerialization.data(withJSONObject: values)) ?? data
        }

        if let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self._settings = decoded
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(_settings) {
            settingsData = encoded
        }
    }
}
