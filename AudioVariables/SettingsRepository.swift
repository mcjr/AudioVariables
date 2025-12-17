//
//  SettingsRepository.swift
//  AudioVariables
//

import Foundation

class SettingsRepository {
    static let shared = SettingsRepository()
    
    private let defaults = UserDefaults.standard
    private let settingsKey = "settings"
    
    private init() {}
    
    func load() -> Settings {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
            print("Settings loaded: Using defaults")
            return Settings() // Return default settings
        }
        
        print("Settings loaded: \(settings.filename), \(settings.startTime)s-\(settings.endTime)s, looping: \(settings.isLooping), pause: \(settings.pauseBetweenLoops)s, speed: \(settings.speed), pitch: \(settings.pitch)")
        return settings
    }
    
    func save(_ settings: Settings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            print("Failed to encode settings")
            return
        }
        
        defaults.set(data, forKey: settingsKey)
        print("Settings saved: \(settings.filename), \(settings.startTime)s-\(settings.endTime)s, looping: \(settings.isLooping), pause: \(settings.pauseBetweenLoops)s, speed: \(settings.speed), pitch: \(settings.pitch)")
    }
}
