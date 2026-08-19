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

    /// Compact form for lists and stats. Sub-minute sessions report seconds
    /// rather than collapsing to a meaningless "0 min".
    static func abbreviated(_ duration: TimeInterval) -> String {
        let seconds = Int(max(0, duration).rounded())
        if seconds < 60 {
            return String(localized: "duration.seconds", defaultValue: "\(seconds) s")
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return String(localized: "duration.minutes", defaultValue: "\(minutes) min")
        }
        return String(
            localized: "duration.hoursMinutes",
            defaultValue: "\(minutes / 60)h \(minutes % 60)m"
        )
    }
}
