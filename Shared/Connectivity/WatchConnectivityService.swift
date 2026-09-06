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

    // Called straight from the delegate methods, so it runs on WCSession's
    // queue: decoding happens there and only the state change hops to the
    // main actor.
    private nonisolated func handle(rawData: Data) {
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

// WCSession calls its delegate on a private serial queue of its own, never
// on the main actor. Every method here is therefore explicitly `nonisolated`
// rather than relying on the target's SWIFT_DEFAULT_ACTOR_ISOLATION, so the
// isolation is a property of the code and not of a build setting — and work
// that does belong on the main actor is hopped there deliberately below.
extension WatchConnectivityService: WCSessionDelegate {
    // Required for WCSessionDelegate conformance. Nothing to do: both
    // transports check the activation state at send time, so activation
    // needs no bookkeeping here.
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    // Reachability is not acted on: settings go out as application context
    // and a saved session as a queued transfer, both of which the system
    // delivers once the counterpart comes back.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext["message"] as? Data {
            handle(rawData: data)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if let data = userInfo["message"] as? Data {
            handle(rawData: data)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
