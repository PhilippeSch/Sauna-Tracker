//
//  AppVersion.swift
//  Sauna Companion
//
//  The build number is a YYYYMMDDHHMM timestamp written by the "Set Build
//  Number" build phase, so version + build identifies a build exactly.
//

import Foundation

enum AppVersion {
    /// e.g. "1.0 (202609031950)".
    static var displayString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
