//
//  HapticScheduler.swift
//  Sauna Tracker Watch App
//
//  Fires a haptic every N minutes while a phase is running. The workout
//  session keeps the app in an elevated background execution state, so this
//  keeps firing even if the wrist drops or the screen locks.
//

import Foundation
import WatchKit

@MainActor
final class HapticScheduler: HapticScheduling {
    private var task: Task<Void, Never>?

    func start(intervalMinutes: Int) {
        stop()
        let interval = TimeInterval(max(1, intervalMinutes) * 60)
        task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
