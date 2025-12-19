//
//  ContentView.swift
//  AudioVariables
//

import SwiftUI
import AVKit
import AVFoundation

struct ContentView: View {
    @State private var settings = Settings()
    @State private var fileDurationInSeconds: Double = 300.0
    @State private var frequencyData: [Float] = Array(repeating: 0.0, count: 64)
    @State private var displayTimer: Timer?
    
    @StateObject private var audioEngine = AudioEngine()
    private let settingsRepository = SettingsRepository.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // File Selector
                AudioFileSelectorView(filename: $settings.filename) {
                    loadFileDuration()
                    saveSettings()
                }
                
                // Audio Controls
                AudioControlsView(
                    onPlay: playAudio,
                    onPause: pauseAudio,
                    onStop: stopAudio,
                    isPlaying: audioEngine.isPlaying,
                    isLooping: $settings.isLooping,
                    pauseBetweenLoops: $settings.pauseBetweenLoops,
                    countInPhase: $settings.countInPhase
                )
                .onChange(of: settings.isLooping) { newValue in
                    audioEngine.setLoopingEnabled(enabled: newValue, pauseBetween: settings.pauseBetweenLoops)
                    saveSettings()
                }
                .onChange(of: settings.pauseBetweenLoops) { newValue in
                    audioEngine.setLoopingEnabled(enabled: settings.isLooping, pauseBetween: newValue)
                    saveSettings()
                }
                .onChange(of: settings.countInPhase) { _ in
                    saveSettings()
                }
                .onChange(of: settings.startTime) { _ in
                    audioEngine.setSegmentRange(start: settings.startTime, end: settings.endTime)
                    saveSettings()
                }
                .onChange(of: settings.endTime) { _ in
                    audioEngine.setSegmentRange(start: settings.startTime, end: settings.endTime)
                    saveSettings()
                }

                // Spectrum Display
                AudioSpectrumView(frequencyData: frequencyData)
                
                // Range Slider
                AudioRangeSlider(
                    startTime: $settings.startTime,
                    endTime: $settings.endTime,
                    currentPlayTime: audioEngine.currentPlayTime,
                    fileDurationInSeconds: fileDurationInSeconds,
                    isPlaying: audioEngine.isPlaying
                )
                
                // Audio Effects
                AudioEffectsView(
                    speedValue: $settings.speed,
                    pitchValue: $settings.pitch,
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
            let fileURL = URL(fileURLWithPath: settings.filename)
            audioEngine.playSegment(
                fileURL,
                startTime: settings.startTime,
                endTime: settings.endTime,
                shouldLoop: settings.isLooping,
                pauseBetweenLoops: settings.pauseBetweenLoops,
                countInPhase: settings.countInPhase
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
        settings = settingsRepository.load()
        
        // Apply loaded settings to audio engine
        audioEngine.setSpeed(settings.speed)
        audioEngine.setPitch(settings.pitch)
    }
    
    private func saveSettings() {
        settingsRepository.save(settings)
    }
    
    // MARK: - File Management
    private func loadFileDuration() {
        let fileURL = URL(fileURLWithPath: settings.filename)
        do {
            let file = try AVAudioFile(forReading: fileURL)
            let sampleRate = file.fileFormat.sampleRate
            let totalFrames = file.length
            fileDurationInSeconds = Double(totalFrames) / sampleRate
            
            // Adjust endTime if it's larger than the file length
            if settings.endTime > fileDurationInSeconds {
                settings.endTime = fileDurationInSeconds
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
