//
//  SettingsRepository.swift
//  AudioVariables
//

import Foundation

class SettingsRepository {
    static let shared = SettingsRepository()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let filename = "filename"
        static let startTime = "start_time"
        static let endTime = "end_time"
        static let isLooping = "is_looping"
        static let pauseBetweenLoops = "pause_between_loops"
        static let speed = "speed"
        static let pitch = "pitch"
    }
    
    private init() {}
        
    func load() -> (filename: String?, startTime: Double, endTime: Double, isLooping: Bool, pauseBetweenLoops: Double, speed: Float, pitch: Float) {
        let settings = (
            filename: loadFilename(),
            startTime: loadStartTime(),
            endTime: loadEndTime(),
            isLooping: loadIsLooping(),
            pauseBetweenLoops: loadPauseBetweenLoops(),
            speed: loadSpeed(),
            pitch: loadPitch()
        )
        
        print("Settings loaded: \(settings.filename ?? "<none>"), \(settings.startTime)s-\(settings.endTime)s, looping: \(settings.isLooping), pause: \(settings.pauseBetweenLoops)s, speed: \(settings.speed), pitch: \(settings.pitch)")
        
        return settings
    }
    
    private func loadFilename() -> String? {
        return defaults.string(forKey: Keys.filename)
    }
    
    private func loadStartTime() -> Double {
        return defaults.double(forKey: Keys.startTime)
    }
    
    private func loadEndTime() -> Double {
        let endTime = defaults.double(forKey: Keys.endTime)
        return endTime > 0 ? endTime : 60.0 // Default to 60.0 if not set
    }
    
    private func loadIsLooping() -> Bool {
        return defaults.bool(forKey: Keys.isLooping)
    }
    
    private func loadPauseBetweenLoops() -> Double {
        return defaults.double(forKey: Keys.pauseBetweenLoops)
    }
    
    private func loadSpeed() -> Float {
        let speed = defaults.float(forKey: Keys.speed)
        return speed > 0 ? speed : 1.0 // Default to 1.0 if not set
    }
    
    private func loadPitch() -> Float {
        let pitch = defaults.float(forKey: Keys.pitch)
        return pitch > 0 ? pitch : 1.0 // Default to 1.0 if not set
    }
        
    func save(filename: String, startTime: Double, endTime: Double, isLooping: Bool, pauseBetweenLoops: Double, speed: Float, pitch: Float) {
        defaults.set(filename, forKey: Keys.filename)
        defaults.set(startTime, forKey: Keys.startTime)
        defaults.set(endTime, forKey: Keys.endTime)
        defaults.set(isLooping, forKey: Keys.isLooping)
        defaults.set(pauseBetweenLoops, forKey: Keys.pauseBetweenLoops)
        defaults.set(speed, forKey: Keys.speed)
        defaults.set(pitch, forKey: Keys.pitch)
        
        print("Settings saved: \(filename), \(startTime)s-\(endTime)s, looping: \(isLooping), pause: \(pauseBetweenLoops)s, speed: \(speed), pitch: \(pitch)")
    }
}
