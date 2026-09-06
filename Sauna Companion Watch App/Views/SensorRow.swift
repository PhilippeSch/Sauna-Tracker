//
//  SensorRow.swift
//  Sauna Companion Watch App
//
//  Reusable row for an optional sensor reading. Only ever shown by the
//  caller when a real, fresh value exists.
//

import SwiftUI

struct SensorRow: View {
    let symbol: String
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Image(systemName: symbol)
                .frame(width: 16)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}
