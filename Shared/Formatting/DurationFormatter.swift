//
//  DurationFormatter.swift
//  Sauna Tracker
//

import Foundation

enum DurationFormatter {
    private static let componentsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    /// "12:34" while under an hour, "1:02:34" once it crosses an hour.
    static func clock(_ duration: TimeInterval) -> String {
        let clamped = max(0, duration)
        componentsFormatter.allowedUnits = clamped >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        return componentsFormatter.string(from: clamped) ?? "0:00"
    }

    /// "42 min" / "1h 12m" for summary contexts (history list, stats).
    static func abbreviated(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return String(localized: "duration.minutes", defaultValue: "\(minutes) min")
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        return String(localized: "duration.hoursMinutes", defaultValue: "\(hours)h \(remainder)m")
    }
}
