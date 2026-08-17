//
//  ActiveSessionView.swift
//  Sauna Tracker Watch App
//
//  The main session screen. Background stays near-black at all times for
//  contrast and AOD power draw — the phase is communicated with a colored
//  pill, not a screen tint. Elapsed time uses Text(timerInterval:), which
//  keeps ticking correctly under Always-On Display without a manual Timer.
//

import SwiftUI
import WatchKit

struct ActiveSessionView: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Bindable var store: SessionStore

    private var phaseEndBound: Date {
        store.phaseStartDate.addingTimeInterval(6 * 3600)
    }

    var body: some View {
        VStack(spacing: isLuminanceReduced ? 6 : 10) {
            phasePill

            Text(timerInterval: store.phaseStartDate...phaseEndBound, countsDown: false)
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white)
                .padding(.top, 10)

            if !isLuminanceReduced {
                roundIndicator
                heartRateBlock
                sensorRows
                Spacer(minLength: 4)
                PhaseControlBar(store: store)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    WKInterfaceDevice.current().enableWaterLock()
                } label: {
                    Image(systemName: "drop.fill")
                }
                .accessibilityLabel(Text("Water Lock"))
            }
        }
    }

    private var phasePill: some View {
        Text(store.currentPhase.displayName.uppercased())
            .font(.system(size: 14, weight: .bold))
            .tracking(1.2)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(store.currentPhase.tintColor.opacity(0.9), in: Capsule())
            .foregroundStyle(.black)
    }

    private var roundIndicator: some View {
        HStack(spacing: 5) {
            ForEach(0..<store.maxConfiguredRounds, id: \.self) { index in
                Circle()
                    .fill(index < store.roundCount ? store.currentPhase.tintColor : Color.white.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
            Text("Round \(store.roundCount) of \(store.maxConfiguredRounds)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
    }

    private var heartRateBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                Label {
                    Text(store.currentHeartRate.map { "\(Int($0))" } ?? "–")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                } icon: {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 16))
                }
                Text("BPM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("\(Int(store.maxHeartRateThisRound))")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.85))
                Text("MAX THIS ROUND")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

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
        }
    }
}
