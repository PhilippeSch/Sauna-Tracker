//
//  SaunaPhase.swift
//  Sauna Companion
//
//  Shared between the watchOS and iOS targets.
//

import SwiftUI

enum SaunaPhase: String, Codable, Sendable, CaseIterable {
    case sauna
    case rest

    var displayName: String {
        switch self {
        case .sauna: String(localized: "phase.sauna", defaultValue: "Sauna")
        case .rest: String(localized: "phase.rest", defaultValue: "Rest")
        }
    }

    var tintColor: Color {
        switch self {
        case .sauna: .orange
        case .rest: .teal
        }
    }
}
