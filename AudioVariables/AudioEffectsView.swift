//
//  AudioEffectsView.swift
//  AudioVariables
//

import SwiftUI

struct AudioEffectsView: View {
    @Binding var speedValue: Float
    @Binding var pitchValue: Float
    @State private var speedEditing = false
    @State private var pitchEditing = false
    
    let onSpeedChanged: (Float) -> Void
    let onPitchChanged: (Float) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Speed Control
            VStack {
                Slider(
                    value: $speedValue,
                    in: 0.1...2.0
                ) {
                    Text("Speed")
                } minimumValueLabel: {
                    Text("10%")
                } maximumValueLabel: {
                    Text("200%")
                } onEditingChanged: { editing in
                    speedEditing = editing
                    onSpeedChanged(speedValue)
                }
                Text("\(String(format: "%.0f", speedValue * 100))%")
                    .foregroundColor(speedEditing ? .red : .blue)
            }
            
            // Pitch Control
            VStack {
                Slider(
                    value: $pitchValue,
                    in: -1200...1200,
                    step: 100
                ) {
                    Text("Pitch")
                } minimumValueLabel: {
                    Text("-12")
                } maximumValueLabel: {
                    Text("12")
                } onEditingChanged: { editing in
                    pitchEditing = editing
                    onPitchChanged(pitchValue)
                }
                Text("\(String(format: "%.0f Semitone", pitchValue / 100))")
                    .foregroundColor(pitchEditing ? .red : .blue)
            }
        }
    }
}
