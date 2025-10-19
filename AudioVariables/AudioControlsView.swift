//
//  AudioControlsView.swift
//  AudioVariables
//

import SwiftUI

struct AudioControlsView: View {
    let onPlay: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void
    let isPlaying: Bool
    
    @Binding var isLooping: Bool
    @Binding var pauseBetweenLoops: Double
    
    var body: some View {
        HStack {
            Button("Play") {
                onPlay()
            }
            .disabled(isPlaying)
            
            Button("Pause") {
                onPause()
            }.disabled(!isPlaying)
            
            Button("Stop") {
                onStop()
            }.disabled(!isPlaying)
            
            Button(isLooping ? "Loop: ON" : "Loop: OFF") {
                isLooping.toggle()
            }
            .foregroundColor(isLooping ? .green : .gray)
            
            // Loop pause slider directly after the loop button
            VStack {
                Text("Loop-Pause")
                    .font(.caption2)
                    .foregroundColor(.gray)
                HStack {
                    Text("0s")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Slider(
                        value: $pauseBetweenLoops,
                        in: 0...10,
                        step: 1.0
                    )
                    .frame(width: 80)
                    Text("10s")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Text("\(String(format: "%.0f", pauseBetweenLoops))s")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            .frame(width: 120)
        }
    }
}
