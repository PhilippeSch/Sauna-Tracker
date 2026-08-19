//
//  SaunaPhase.swift
//  Sauna Tracker
//
//  Shared between the watchOS and iOS targets.
//

import SwiftUI

enum SaunaPhase: String, Codable, Sendable, CaseIterable {
    case sauna
    case rest

    /// Upper bound for the on-screen phase timer. `Text(timerInterval:)`
    /// stops counting at the end of its range, so this has to outlast any
    /// real phase — an hour did not, and the timer froze at 1:00:00.
    static let maxDisplayedPhaseDuration: TimeInterval = 12 * 3600

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
