//
//  SessionControlsView.swift
//  Sauna Tracker Watch App
//
//  Swipe-left page of a running session, mirroring the Workout app: big,
//  unmissable targets for the two things you need with wet hands — ending
//  the session and locking the screen against water.
//

import SwiftUI
import WatchKit

struct SessionControlsView: View {
    @Bindable var store: SessionStore
    var onEndRequested: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Button(action: onEndRequested) {
                    VStack(spacing: 2) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 22))
                        Text("End Session")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 62)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button {
                    WKInterfaceDevice.current().enableWaterLock()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 22))
                        Text("Water Lock")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 62)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                summary
                sensorRows
            }
            .padding(.horizontal, 4)
        }
    }

    private var summary: some View {
        VStack(spacing: 3) {
            row(label: "Rounds", value: "\(store.roundCount)")
            row(label: "Sauna Time", value: DurationFormatter.clock(store.totalSaunaDurationSoFar))
        }
        .padding(.top, 4)
    }

    /// Optional sensors, shown only when a real reading exists. HRV and
    /// respiratory rate may appear during a workout; SpO2 and wrist
    /// temperature realistically will not, since watchOS never measures
    /// those on demand for third-party apps.
    @ViewBuilder
    private var sensorRows: some View {
        let readings = store.latestSensorReadings
        if readings.hasAnyReading {
            VStack(spacing: 2) {
                if let hrv = readings.hrv {
                    SensorRow(symbol: "waveform.path.ecg", label: "HRV", value: "\(Int(hrv)) ms")
                }
                if let rr = readings.respiratoryRate {
                    SensorRow(symbol: "lungs.fill", label: "Resp. Rate", value: "\(Int(rr))/min")
                }
                if let spo2 = readings.spo2 {
                    SensorRow(symbol: "drop.degreesign", label: "SpO2", value: "\(Int(spo2 * 100))%")
                }
                if let temp = readings.wristTemperatureC {
                    SensorRow(symbol: "thermometer", label: "Wrist Temp", value: String(format: "%.1f°C", temp))
                }
            }
            .padding(.top, 2)
        }
    }

    private func row(label: LocalizedStringKey, value: String) -> some View {
        HStack {
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
