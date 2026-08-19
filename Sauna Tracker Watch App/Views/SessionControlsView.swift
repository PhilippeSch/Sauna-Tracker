//
//  SessionControlsView.swift
//  Sauna Tracker Watch App
//
//  Swipe-left page of a running session: the two things you need with wet
//  hands, side by side, plus a live running total of the session so far.
//

import SwiftUI
import WatchKit

struct SessionControlsView: View {
    @Bindable var store: SessionStore
    var onEndRequested: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    controlButton(
                        titleKey: "control.end",
                        symbol: "stop.fill",
                        tint: .red,
                        prominent: true,
                        action: onEndRequested
                    )
                    controlButton(
                        titleKey: "control.lock",
                        symbol: "drop.fill",
                        tint: .blue,
                        prominent: false
                    ) {
                        WKInterfaceDevice.current().enableWaterLock()
                    }
                }

                summary
                sensorRows
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private func controlButton(
        titleKey: LocalizedStringKey,
        symbol: String,
        tint: Color,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let label = VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 18))
            Text(titleKey)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 52)

        if prominent {
            Button(action: action) { label }
                .buttonStyle(.borderedProminent)
                .tint(tint)
        } else {
            Button(action: action) { label }
                .buttonStyle(.bordered)
                .tint(tint)
        }
    }

    /// Ticks once a second so the running totals move while the round is
    /// still open, instead of only stepping at each phase change.
    private var summary: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(spacing: 3) {
                row(label: "Rounds", value: "\(store.roundCount)")
                row(label: "Sauna Time", value: DurationFormatter.clock(store.totalSaunaDurationSoFar))
                row(label: "Total", value: DurationFormatter.clock(store.totalSessionDurationSoFar))
            }
        }
        .padding(.top, 2)
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
}
