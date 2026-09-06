//
//  StartSessionView.swift
//  Sauna Companion Watch App
//

import SwiftUI

struct StartSessionView: View {
    @Bindable var store: SessionStore

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange)

            Text("Sauna Companion")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                // The name has to survive a 40 mm case, where 17pt runs past
                // the edge and left "Sauna Compani…" on the first screen of
                // the app. Scaling down beats clipping the app's own name.
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Button {
                Task { await store.startSession() }
            } label: {
                Text("Start Sauna")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
