//
//  StartSessionView.swift
//  Sauna Tracker Watch App
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
