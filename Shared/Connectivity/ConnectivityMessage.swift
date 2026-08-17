//
//  ConnectivityMessage.swift
//  Sauna Tracker
//

import Foundation

enum ConnectivityMessage: Codable {
    /// iPhone -> Watch, delivered as WCSession application context (state,
    /// coalesces to the latest value — right model for settings).
    case settingsChanged(AppSettings)

    /// Watch -> iPhone, delivered via transferUserInfo (queued, delivered
    /// even if the phone is unreachable right now — right model for a
    /// one-off "a session finished, go refresh" ping).
    case sessionSaved(workoutUUID: UUID)
}
