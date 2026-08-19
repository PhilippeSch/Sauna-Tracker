//
//  DurationFormatter.swift
//  Sauna Tracker
//

import Foundation

enum DurationFormatter {
    /// "12:34" while under an hour, "1:02:34" once it crosses an hour.
    ///
    /// Built by hand rather than with a shared DateComponentsFormatter: that
    /// class is not safe to reconfigure per call from more than one thread,
    /// and a clock readout should not vary with locale anyway.
    static func clock(_ duration: TimeInterval) -> String {
        let total = Int(max(0, duration).rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
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
