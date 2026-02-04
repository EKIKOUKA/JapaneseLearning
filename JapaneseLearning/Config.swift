//
//  Config.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/22.
//

import Foundation

struct Config {

    static var shared: [String: Any]? {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plist
    }

    static var supabaseJapaneseLearningURL: String {
        return shared?["supabaseJapaneseLearningURL"] as? String ?? ""
    }
    static var supabaseJapaneseLearningKey: String {
        return shared?["supabaseJapaneseLearningKey"] as? String ?? ""
    }

    static var YouTubeDataAPIKey: String {
        return shared?["YouTubeDataAPIKey"] as? String ?? ""
    }
}
