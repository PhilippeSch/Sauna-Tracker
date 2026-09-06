//
//  WatchConnectivityService.swift
//  Sauna Companion
//
//  Thin WCSession wrapper shared by both targets. Settings flow iPhone ->
//  Watch as application context (state). A finished session flows
//  Watch -> iPhone via transferUserInfo so it's queued and delivered even
//  if the phone isn't reachable right now.
//

import Foundation
import WatchConnectivity
import os

@Observable
final class WatchConnectivityService: NSObject {
    static let shared = WatchConnectivityService()

    private static let log = Logger(subsystem: "Scheuber.Sauna-Tracker", category: "Connectivity")

    private(set) var isReachable = false
    private(set) var lastSavedWorkoutUUID: UUID?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendSettings(_ settings: AppSettings) {
        send(.settingsChanged(settings), via: .applicationContext)
    }

    func notifySessionSaved(workoutUUID: UUID) {
        send(.sessionSaved(workoutUUID: workoutUUID), via: .userInfo)
    }

    private enum Transport { case applicationContext, userInfo }

    private func send(_ message: ConnectivityMessage, via transport: Transport) {
        guard WCSession.isSupported() else { return }
        guard WCSession.default.activationState == .activated else {
            Self.log.error("Session not activated, dropping message")
            return
        }
        guard let data = try? JSONEncoder().encode(message) else { return }

        switch transport {
        case .applicationContext:
            do {
                try WCSession.default.updateApplicationContext(["message": data])
            } catch {
                // Application context is the right shape for settings — latest
                // value wins — but it fails outright if the counterpart app
                // looks uninstalled. Fall back to a queued transfer so the
                // change still lands rather than disappearing silently.
                Self.log.error("Application context failed (\(error.localizedDescription)), queueing transfer instead")
                WCSession.default.transferUserInfo(["message": data])
            }
        case .userInfo:
            WCSession.default.transferUserInfo(["message": data])
        }
    }

    private func handle(rawData: Data) {
        guard let message = try? JSONDecoder().decode(ConnectivityMessage.self, from: rawData) else { return }
        Task { @MainActor in
            switch message {
            case .settingsChanged(let settings):
                SettingsStore.shared.applyRemote(settings)
            case .sessionSaved(let workoutUUID):
                self.lastSavedWorkoutUUID = workoutUUID
            }
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext["message"] as? Data {
            handle(rawData: data)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let data = userInfo["message"] as? Data {
            handle(rawData: data)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
