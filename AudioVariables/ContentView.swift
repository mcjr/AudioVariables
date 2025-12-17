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
    @State private var isLooping = false
    @State private var pauseBetweenLoops: Double = 0.0
    @State private var fileDurationInSeconds: Double = 300.0
    @State private var frequencyData: [Float] = Array(repeating: 0.0, count: 64)
    @State private var displayTimer: Timer?
    
    @StateObject private var audioEngine = AudioEngine()
    private let settingsRepository = SettingsRepository.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // File Selector
                FileSelectorView(filename: $filename) {
                    loadFileDuration()
                    saveSettings()
                }
                
                // Audio Controls
                AudioControlsView(
                    onPlay: playAudio,
                    onPause: pauseAudio,
                    onStop: stopAudio,
                    isPlaying: audioEngine.isPlaying,
                    isLooping: $isLooping,
                    pauseBetweenLoops: $pauseBetweenLoops,
                )
                .onChange(of: isLooping) { newValue in
                    audioEngine.setLoopingEnabled(enabled: newValue, pauseBetween: pauseBetweenLoops)
                    saveSettings()
                }
                .onChange(of: pauseBetweenLoops) { newValue in
                    audioEngine.setLoopingEnabled(enabled: isLooping, pauseBetween: newValue)
                    saveSettings()
                }
                .onChange(of: startTime) { _ in
                    audioEngine.setSegmentRange(start: startTime, end: endTime)
                    saveSettings()
                }
                .onChange(of: endTime) { _ in
                    audioEngine.setSegmentRange(start: startTime, end: endTime)
                    saveSettings()
                }

                // Spectrum Display
                AudioSpectrumView(frequencyData: frequencyData)
                
                // Range Slider
                AudioRangeSlider(
                    startTime: $startTime,
                    endTime: $endTime,
                    currentPlayTime: audioEngine.currentPlayTime,
                    fileDurationInSeconds: fileDurationInSeconds,
                    isPlaying: audioEngine.isPlaying
                )
                
                // Audio Effects
                AudioEffectsView(
                    speedValue: $speedValue,
                    pitchValue: $pitchValue,
                    onSpeedChanged: { speed in
                        audioEngine.setSpeed(speed)
                        saveSettings()
                    },
                    onPitchChanged: { pitch in
                        audioEngine.setPitch(pitch)
                        saveSettings()
                    }
                )
            }
            .padding(20)
        }
        .onAppear {
            loadSettings()
            loadFileDuration()
            startDisplayTimer()
            setupNotificationObservers()
        }
        .onDisappear {
            saveSettings()
            cleanup()
        }
    }
    
    // MARK: - Audio Control Methods
    private func playAudio() {
        if audioEngine.isPlaying {
            return // Already playing
        }
        
        // Use the new encapsulated method
        if audioEngine.currentPlayTime > 0 {
            // Resume from current position
            audioEngine.play()
        } else {
            // Start new segment
            let fileURL = URL(fileURLWithPath: filename)
            audioEngine.playSegment(
                fileURL,
                startTime: startTime,
                endTime: endTime,
                shouldLoop: isLooping,
                pauseBetweenLoops: pauseBetweenLoops
            )
        }
    }
    
    private func pauseAudio() {
        audioEngine.pause()
    }
    
    private func stopAudio() {
        audioEngine.stop()
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
                // Position update is now handled internally by AudioEngine
                audioEngine.seekToPosition(newRelativeTime)
            }
        }
    }
    
    private func cleanup() {
        stopDisplayTimer()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UpdateSpectrum"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("UpdatePlaybackPosition"), object: nil)
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        let settings = settingsRepository.load()
        
        // Load filename if available
        if let savedFilename = settings.filename, !savedFilename.isEmpty {
            filename = savedFilename
        }
        
        // Load time settings
        startTime = settings.startTime
        endTime = settings.endTime
        
        // Load looping settings
        isLooping = settings.isLooping
        pauseBetweenLoops = settings.pauseBetweenLoops
        
        // Load audio effect settings
        speedValue = settings.speed
        pitchValue = settings.pitch
        
        // Apply loaded settings to audio engine
        audioEngine.setSpeed(speedValue)
        audioEngine.setPitch(pitchValue)
    }
    
    private func saveSettings() {
        settingsRepository.save(
            filename: filename,
            startTime: startTime,
            endTime: endTime,
            isLooping: isLooping,
            pauseBetweenLoops: pauseBetweenLoops,
            speed: speedValue,
            pitch: pitchValue
        )
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
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if audioEngine.isPlaying {
                // Light simulation fallback - real data comes from AudioEngine
                updateFrequencyData()
            } else {
                // Smooth fade-out when not playing
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
        // Fallback simulation when no real audio data is available
        // Real spectrum data comes via NotificationCenter from AudioEngine
        for i in 0..<frequencyData.count {
            let randomValue = Float.random(in: 0...10) // Reduced simulation intensity
            frequencyData[i] = max(0, frequencyData[i] * 0.95 + randomValue * 0.05) // Less aggressive simulation
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
