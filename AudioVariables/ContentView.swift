//
//  ContentView.swift
//  AudioVariables
//

import SwiftUI
import AVKit
import AVFoundation

struct ContentView: View {
    @State private var filename = "<audiofile>"
    @State private var pitchValue: Float = 1.0
    @State private var speedValue: Float = 1.0
    @State private var startTime: Double = 0.0
    @State private var endTime: Double = 60.0
    @State private var audioFile: AVAudioFile?
    @State private var isLooping = false
    @State private var loopTimer: Timer?
    @State private var pauseBetweenLoops: Double = 0.0
    @State private var fileDurationInSeconds: Double = 300.0
    @State private var frequencyData: [Float] = Array(repeating: 0.0, count: 64)
    @State private var displayTimer: Timer?
    @State private var currentPlayTime: Double = 0.0
    @State private var playbackTimer: Timer?
    
    @StateObject private var audioEngine = AudioEngine()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // File Selector
                FileSelectorView(filename: $filename) {
                    loadFileDuration()
                }
                
                // Audio Controls
                AudioControlsView(
                    onPlay: playAudio,
                    onPause: pauseAudio,
                    onStop: stopAudio,
                    isPlaying: audioEngine.isPlaying,
                    isLooping: $isLooping,
                    pauseBetweenLoops: $pauseBetweenLoops
                )
                
                // Spectrum Display
                AudioSpectrumView(frequencyData: frequencyData)
                
                // Range Slider
                AudioRangeSlider(
                    startTime: $startTime,
                    endTime: $endTime,
                    currentPlayTime: currentPlayTime,
                    fileDurationInSeconds: fileDurationInSeconds,
                    isPlaying: audioEngine.isPlaying
                )
                
                // Audio Effects
                AudioEffectsView(
                    speedValue: $speedValue,
                    pitchValue: $pitchValue,
                    onSpeedChanged: { speed in
                        audioEngine.setSpeed(speed)
                    },
                    onPitchChanged: { pitch in
                        audioEngine.setPitch(pitch)
                    }
                )
            }
            .padding(20)
        }
        .onAppear {
            loadFileDuration()
            startDisplayTimer()
            setupNotificationObservers()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    // MARK: - Audio Control Methods
    private func playAudio() {
        if audioEngine.isPlaying {
            return // Already playing
        }
        
        let fileURL = URL(fileURLWithPath: filename)
        
        // If we have paused, continue playing from the current position
        if currentPlayTime > 0 {
            let resumeStartTime = startTime + currentPlayTime
            audioFile = audioEngine.prepareEngine(fileURL, startTime: resumeStartTime, endTime: endTime)
        } else {
            // Start new segment from the beginning
            audioFile = audioEngine.prepareEngine(fileURL, startTime: startTime, endTime: endTime)
        }
        
        if let _ = audioFile {
            audioEngine.play()
            startPlaybackTracking()
            
            if isLooping {
                startLooping()
            }
        }
    }
    
    private func pauseAudio() {
        audioEngine.pause()
        // Only stop the loop timer, but keep the current position
        stopLooping()
    }
    
    private func stopAudio() {
        audioEngine.stop()
        stopPlaybackTracking()
        stopLooping()
    }
    
    // MARK: - Setup and Cleanup
    private func setupNotificationObservers() {
        // NotificationCenter Observer for spectrum updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UpdateSpectrum"),
            object: nil,
            queue: .main
        ) { notification in
            if let newData = notification.object as? [Float] {
                frequencyData = newData
            }
        }
        
        // NotificationCenter Observer for playback position updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UpdatePlaybackPosition"),
            object: nil,
            queue: .main
        ) { notification in
            if let newRelativeTime = notification.object as? Double {
                currentPlayTime = newRelativeTime
                
                // If audio is playing, jump to the new position
                if audioEngine.isPlaying {
                    let fileURL = URL(fileURLWithPath: filename)
                    let newStartTime = startTime + newRelativeTime
                    audioFile = audioEngine.prepareEngine(fileURL, startTime: newStartTime, endTime: endTime)
                    audioEngine.play()
                    startPlaybackTracking()
                }
            }
        }
    }
    
    private func cleanup() {
        stopDisplayTimer()
        stopPlaybackTracking()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UpdateSpectrum"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UpdatePlaybackPosition"), object: nil)
    }
    
    // MARK: - Loop Management
    private func startLooping() {
        stopLooping() // Stop previous timer
        
        let segmentDuration = endTime - startTime
        let totalLoopDuration = segmentDuration + pauseBetweenLoops
        
        loopTimer = Timer.scheduledTimer(withTimeInterval: totalLoopDuration, repeats: true) { _ in
            if isLooping { // Check if loop is still active
                // Reset current time for new loop
                currentPlayTime = 0.0
                // Schedule and play new segment
                let fileURL = URL(fileURLWithPath: filename)
                audioFile = audioEngine.prepareEngine(fileURL, startTime: startTime, endTime: endTime)
                audioEngine.play()
                startPlaybackTracking() // Restart position tracking
                
                print("Loop restarted - Segment: \(String(format: "%.1f", segmentDuration))s, Pause: \(String(format: "%.1f", pauseBetweenLoops))s")
            } else {
                stopLooping()
            }
        }
    }
    
    private func stopLooping() {
        loopTimer?.invalidate()
        loopTimer = nil
    }
    
    // MARK: - Playback Tracking
    private func startPlaybackTracking() {
        // Only stop the timer, but keep currentPlayTime on resume
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if audioEngine.isPlaying {
                // Consider speed changes
                let increment = 0.05 * Double(speedValue)
                currentPlayTime += increment
                
                // Check if we have reached the end of the segment
                if currentPlayTime >= (endTime - startTime) {
                    if isLooping {
                        currentPlayTime = 0.0 // Reset for loop
                        // Start new loop
                        let fileURL = URL(fileURLWithPath: filename)
                        audioFile = audioEngine.prepareEngine(fileURL, startTime: startTime, endTime: endTime)
                        audioEngine.play()
                    } else {
                        stopPlaybackTracking()
                    }
                }
            } else {
                // Player is paused, but keep the time
                playbackTimer?.invalidate()
                playbackTimer = nil
            }
        }
    }
    
    private func stopPlaybackTracking() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        currentPlayTime = 0.0
    }
    
    // MARK: - File Management
    private func loadFileDuration() {
        let fileURL = URL(fileURLWithPath: filename)
        do {
            let file = try AVAudioFile(forReading: fileURL)
            let sampleRate = file.fileFormat.sampleRate
            let totalFrames = file.length
            fileDurationInSeconds = Double(totalFrames) / sampleRate
            
            // Adjust endTime if it's larger than the file length
            if endTime > fileDurationInSeconds {
                endTime = fileDurationInSeconds
            }
            
            print("File duration: \(String(format: "%.1f", fileDurationInSeconds))s")
        } catch {
            print("Could not load file duration: \(error)")
            fileDurationInSeconds = 300.0 // Fallback
        }
    }
    
    // MARK: - Display Timer
    private func startDisplayTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            // Simulate spectrum data when audio is playing
            if audioEngine.isPlaying {
                updateFrequencyData()
            } else {
                // Dampen the display when nothing is playing
                for i in 0..<frequencyData.count {
                    frequencyData[i] *= 0.95
                }
            }
        }
    }
    
    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }
    
    private func updateFrequencyData() {
        // Simulated spectrum data only when no real data comes
        // The real data now comes via NotificationCenter
        for i in 0..<frequencyData.count {
            let randomValue = Float.random(in: 0...20) // Reduced for less noise
            frequencyData[i] = max(0, frequencyData[i] * 0.9 + randomValue * 0.1) // Mehr Smoothing, mindestens 0
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
