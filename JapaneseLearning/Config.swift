//
//  Config.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on R 7/12/22.
//

import Foundation

enum Config {
    private static let shared: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        return plist
    }()

    static var YouTubeDataAPIKey: String = shared?["YouTubeDataAPIKey"] as? String ?? ""
    static var CloudflareWorkersURL: String = shared?["CloudflareWorkersURL"] as? String ?? ""
}
