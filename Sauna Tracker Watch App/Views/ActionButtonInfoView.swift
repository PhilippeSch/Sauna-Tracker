//
//  ActionButtonInfoView.swift
//  Sauna Tracker Watch App
//
//  Shown once, on first launch, and only on an Ultra: the Action button does
//  nothing for this app until it is pointed at it in Settings, and there is
//  no API to do that from here or to ask whether it was done.
//

import SwiftUI
import WatchKit

enum WatchHardware {
    /// True on Apple Watch Ultra, the only models with an Action button.
    ///
    /// There is no API that reports the button, so this goes by the 49 mm
    /// case, which is Ultra-only. Screen heights in points: Ultra 1 and 2 are
    /// 251, Ultra 3 is 257, and the largest of the rest — the 46 mm Series 10
    /// and 11 — is 248.
    static var hasActionButton: Bool {
        WKInterfaceDevice.current().screenBounds.height >= 250
    }
}

struct ActionButtonInfoView: View {
    var onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "button.programmable")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)

                Text("Action Button")
                    .font(.headline)

                Text("Your Ultra's Action button can switch between sauna and rest.")
                    .font(.system(size: 13))

                Text("Point it here once:")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                Text("Settings → Action Button → Action: Workout → App: Sauna Tracker")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.18), in: .rect(cornerRadius: 8))

                Text("Every press during a session then switches phase — Water Lock and all.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Button("Got it", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .padding(.top, 4)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    ActionButtonInfoView(onDismiss: {})
}
