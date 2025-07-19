//
//  AudioRangeSlider.swift
//  AudioVariables
//

import SwiftUI
import Foundation

struct RangeSliderMarker: View {
    let text: String
    let color: Color
    let position: CGFloat
    let onDrag: (DragGesture.Value) -> Void
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
                .shadow(radius: 2)
            Circle()
                .fill(color)
                .frame(width: 18, height: 18)
            Text(text)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .offset(x: position)
        .gesture(
            DragGesture()
                .onChanged(onDrag)
        )
    }
}

struct PlaybackPositionMarker: View {
    let position: CGFloat
    let onDrag: (DragGesture.Value) -> Void
    
    var body: some View {
        Rectangle()
            .fill(Color.yellow)
            .frame(width: 3, height: 22)
            .offset(x: position - 1.5)
            .gesture(
                DragGesture()
                    .onChanged(onDrag)
            )
    }
}

struct RangeSliderLabels: View {
    let startTime: Double
    let endTime: Double
    let currentPlayTime: Double
    let fileDurationInSeconds: Double
    let isPlaying: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("0s")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("Start")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack {
                Text("Selection: \(String(format: "%.1f", endTime - startTime))s")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                HStack {
                    Text("Start: \(String(format: "%.1f", startTime))s")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("End: \(String(format: "%.1f", endTime))s")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                if isPlaying || currentPlayTime > 0 {
                    Text("Playing: \(String(format: "%.1f", startTime + currentPlayTime))s")
                        .font(.caption2)
                        .foregroundColor(isPlaying ? .yellow : .orange)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(String(format: "%.0f", fileDurationInSeconds))s")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("End")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct AudioRangeSlider: View {
    @Binding var startTime: Double
    @Binding var endTime: Double
    let currentPlayTime: Double
    let fileDurationInSeconds: Double
    let isPlaying: Bool
    
    var body: some View {
        VStack {
            Text("Audio Selection Range")
                .font(.headline)
            
            ZStack(alignment: .center) {
                // Hintergrund-Track
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 22)
                    .cornerRadius(11)
                
                // GeometryReader for interactive elements
                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let startPercent = startTime / max(fileDurationInSeconds, 1.0)
                    let endPercent = endTime / max(fileDurationInSeconds, 1.0)
                    let startX = totalWidth * startPercent
                    let endX = totalWidth * endPercent
                    let rangeWidth = endX - startX
                    
                    ZStack(alignment: .leading) {
                        // Blue selection area - correctly positioned
                        Rectangle()
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: max(0, rangeWidth), height: 22)
                            .cornerRadius(11)
                            .offset(x: startX)
                            .gesture(
                                DragGesture()
                                    .onChanged { gesture in
                                        let dragDistance = gesture.translation.width
                                        let timeDistance = (dragDistance / totalWidth) * fileDurationInSeconds
                                        let currentDuration = endTime - startTime
                                        
                                        let newStartTime = max(0, min(fileDurationInSeconds - currentDuration, startTime + timeDistance))
                                        let newEndTime = newStartTime + currentDuration
                                        
                                        if newEndTime <= fileDurationInSeconds {
                                            startTime = newStartTime
                                            endTime = newEndTime
                                        }
                                    }
                            )
                        
                        // Start marker - positioned at the beginning of the blue bar
                        RangeSliderMarker(
                            text: "S",
                            color: .green,
                            position: startX - 11
                        ) { value in
                            updateStartTime(value: value, totalWidth: totalWidth)
                        }
                        
                        // End marker - positioned at the end of the blue bar
                        RangeSliderMarker(
                            text: "E",
                            color: .red,
                            position: startX + rangeWidth - 11
                        ) { value in
                            updateEndTime(value: value, totalWidth: totalWidth)
                        }
                        
                        // Playback Position Marker
                        if isPlaying || currentPlayTime > 0 {
                            let currentPercent = (startTime + currentPlayTime) / max(fileDurationInSeconds, 1.0)
                            let currentX = totalWidth * currentPercent
                            PlaybackPositionMarker(position: currentX) { value in
                                updatePlaybackPosition(value: value, totalWidth: totalWidth)
                            }
                        }
                    }
                }
                .frame(height: 22)
            }
            .frame(height: 22)
            
            // Time labels
            RangeSliderLabels(
                startTime: startTime,
                endTime: endTime,
                currentPlayTime: currentPlayTime,
                fileDurationInSeconds: fileDurationInSeconds,
                isPlaying: isPlaying
            )
            .padding(.top, 5)
        }
    }
    
    private func updateStartTime(value: DragGesture.Value, totalWidth: CGFloat) {
        let newStartPercent = max(0, min(1, (value.location.x) / totalWidth))
        let newStartTime = newStartPercent * fileDurationInSeconds
        startTime = max(0, min(endTime - 0.1, newStartTime))
    }
    
    private func updateEndTime(value: DragGesture.Value, totalWidth: CGFloat) {
        let newEndPercent = max(0, min(1, (value.location.x) / totalWidth))
        let newEndTime = newEndPercent * fileDurationInSeconds
        endTime = max(startTime + 0.1, min(fileDurationInSeconds, newEndTime))
    }
    
    private func updatePlaybackPosition(value: DragGesture.Value, totalWidth: CGFloat) {
        let newPercent = max(0, min(1, (value.location.x) / totalWidth))
        let newAbsoluteTime = newPercent * fileDurationInSeconds
        
        // Ensure that the new position is within the selected range
        if newAbsoluteTime >= startTime && newAbsoluteTime <= endTime {
            // Calculate the new relative position within the segment
            let newRelativeTime = newAbsoluteTime - startTime
            
            // Update the current playback time via a binding-like function
            // Since we only have a local function here, we need to use NotificationCenter
            NotificationCenter.default.post(
                name: NSNotification.Name("UpdatePlaybackPosition"),
                object: newRelativeTime
            )
        }
    }
}
