//
//  TransitionNamespace.swift
//  JapaneseLearning
//
//  Created by 宇都宮　誠 on 6/30/R8.
//

import SwiftUI

private struct TransitionNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var transitionNamespace: Namespace.ID? {
        get { self[TransitionNamespaceKey.self] }
        set { self[TransitionNamespaceKey.self] = newValue }
    }
}
