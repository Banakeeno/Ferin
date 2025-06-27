//
//  CategorySelectionView.swift
//  Ferin
//
//  Created by Bankin ALO on 31.05.25.
//

import SwiftUI
import AVFoundation
import UIKit
import AudioToolbox

// MARK: - Audio Manager
@MainActor
class AudioManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = AudioManager()
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    @Published var isSpeaking = false
    
    // Custom audio files mapping
    private let customAudioFiles: [String: String] = [
        "bav": "bav.m4a",
        "dê/dayik": "dê-dayîk.m4a",
        "dê": "dê-dayîk.m4a",           // Alternative mapping for mother
        "dayik": "dê-dayîk.m4a",        // Alternative mapping for mother
        "dê-dayik": "dê-dayîk.m4a",     // Alternative with dash instead of slash
        "kurmet": "kurmet.m4a"
        // Add more custom recordings here:
        // "word_in_kurdish": "filename.m4a"
    ]
    
    private override init() {
        super.init()
        speechSynthesizer.delegate = self
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Audio session setup failed: \(error)")
        }
    }
    
    func speakKurdishWord(_ word: String) {
        // Stop any current speech or audio
        stopSpeaking()
        
        print("🔍 DEBUG: Attempting to play word: '\(word)'")
        print("🔍 DEBUG: Word lowercased: '\(word.lowercased())'")
        print("🔍 DEBUG: Word UTF8: \(Array(word.lowercased().utf8))")
        print("🔍 DEBUG: Available custom audio files: \(Array(customAudioFiles.keys))")
        
        // Clean the word for better matching
        let cleanWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔍 DEBUG: Clean word: '\(cleanWord)'")
        
        // Check each key individually for dê/dayik
        for (key, value) in customAudioFiles {
            if key.contains("dê") || key.contains("dayik") {
                print("🔍 DEBUG: Found mother-related key: '\(key)' -> '\(value)'")
                print("🔍 DEBUG: Key UTF8: \(Array(key.utf8))")
                print("🔍 DEBUG: Does '\(cleanWord)' == '\(key)'? \(cleanWord == key)")
            }
        }
        
        // List all files in Audio directory for debugging
        if word.contains("dê") || word.contains("dayik") {
            print("🔍 DEBUG: Listing all files in Audio directory:")
            if let audioPath = Bundle.main.path(forResource: nil, ofType: nil, inDirectory: "Audio") {
                do {
                    let files = try FileManager.default.contentsOfDirectory(atPath: audioPath)
                    for file in files {
                        print("🔍 DEBUG: Found file: '\(file)'")
                    }
                } catch {
                    print("🔍 DEBUG: Could not list Audio directory: \(error)")
                }
            } else {
                print("🔍 DEBUG: Audio directory not found in bundle")
            }
        }
        
        // Check if we have a custom audio file for this word
        if let audioFileName = customAudioFiles[cleanWord] {
            print("🔍 DEBUG: Found mapping for word '\(word)' -> '\(audioFileName)'")
            
            // Try multiple path strategies
            let resourceName = audioFileName.replacingOccurrences(of: ".m4a", with: "")
            
            // Strategy 1: Look in Audio subdirectory
            if let audioURL = Bundle.main.url(forResource: resourceName, withExtension: "m4a", subdirectory: "Audio") {
                print("✅ DEBUG: Found audio file in Audio/ subdirectory: \(audioURL)")
                playCustomAudio(from: audioURL, word: word)
                return
            }
            
            // Strategy 2: Look in root bundle
            if let audioURL = Bundle.main.url(forResource: resourceName, withExtension: "m4a") {
                print("✅ DEBUG: Found audio file in root bundle: \(audioURL)")
                playCustomAudio(from: audioURL, word: word)
                return
            }
            
            // Strategy 3: Try with full filename
            if let audioURL = Bundle.main.url(forResource: audioFileName, withExtension: nil, subdirectory: "Audio") {
                print("✅ DEBUG: Found audio file with full name in Audio/: \(audioURL)")
                playCustomAudio(from: audioURL, word: word)
                return
            }
            
            // Strategy 4: Try with full filename in root
            if let audioURL = Bundle.main.url(forResource: audioFileName, withExtension: nil) {
                print("✅ DEBUG: Found audio file with full name in root: \(audioURL)")
                playCustomAudio(from: audioURL, word: word)
                return
            }
            
            print("❌ DEBUG: Could not find audio file '\(audioFileName)' for word '\(word)'")
            print("❌ DEBUG: Checked paths:")
            print("   - Audio/\(resourceName).m4a")
            print("   - \(resourceName).m4a") 
            print("   - Audio/\(audioFileName)")
            print("   - \(audioFileName)")
        } else {
            print("🔍 DEBUG: No custom audio mapping found for word: '\(word)'")
            print("🔍 DEBUG: Clean word was: '\(cleanWord)'")
            
            // Try alternative matching strategies for mother word
            if cleanWord.contains("dê") || cleanWord.contains("dayik") || cleanWord.contains("mother") {
                print("🔍 DEBUG: Detected mother-related word, trying alternative lookup")
                if let audioFileName = customAudioFiles["dê"] {
                    print("🔍 DEBUG: Using fallback mother audio file: \(audioFileName)")
                    
                    let resourceName = audioFileName.replacingOccurrences(of: ".m4a", with: "")
                    if let audioURL = Bundle.main.url(forResource: resourceName, withExtension: "m4a", subdirectory: "Audio") {
                        print("✅ DEBUG: Found fallback audio file: \(audioURL)")
                        playCustomAudio(from: audioURL, word: word)
                        return
                    }
                }
            }
        }
        
        // Check if we should use TTS fallback based on settings
        if SettingsManager.shared.useNativeKurdishAudio {
            print("🔇 No native Kurdish audio found and TTS fallback disabled by user settings")
            return
        }
        
        // Fallback to text-to-speech
        print("🔊 DEBUG: Falling back to TTS for word: '\(word)'")
        speakWithTTS(word)
    }
    
    private func playCustomAudio(from url: URL, word: String) {
        print("🔊 DEBUG: Attempting to load audio from: \(url)")
        print("🔊 DEBUG: File exists at path: \(FileManager.default.fileExists(atPath: url.path))")
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            
            print("🔊 SUCCESS: Loaded custom audio for Kurdish word: \(word)")
            print("🔊 DEBUG: Audio duration: \(audioPlayer?.duration ?? 0) seconds")
            
            DispatchQueue.main.async {
                self.isSpeaking = true
            }
            
            let playResult = audioPlayer?.play() ?? false
            print("🔊 DEBUG: Audio play() returned: \(playResult)")
            
        } catch {
            print("❌ FAILED to play custom audio for \(word): \(error)")
            print("❌ DEBUG: Error details: \(error.localizedDescription)")
            
            // Check if we should use TTS fallback based on settings
            if SettingsManager.shared.useNativeKurdishAudio {
                print("🔇 Custom audio failed and TTS fallback disabled by user settings")
                return
            }
            
            // Fallback to text-to-speech
            speakWithTTS(word)
        }
    }
    
    private func speakWithTTS(_ word: String) {
        let utterance = AVSpeechUtterance(string: word)
        
        // Try Kurdish language code first, fallback to Turkish which is closer to Kurdish
        if let kurdishVoice = AVSpeechSynthesisVoice(language: "ku") {
            utterance.voice = kurdishVoice
        } else if let turkishVoice = AVSpeechSynthesisVoice(language: "tr-TR") {
            utterance.voice = turkishVoice
        } else {
            // Fallback to default system voice
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        // Adjust speech parameters for better pronunciation
        utterance.rate = 0.4 // Slower for learning
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.8
        
        print("🔊 Speaking Kurdish word with TTS: \(word)")
        speechSynthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        // Stop text-to-speech
        if speechSynthesizer.isSpeaking {
        speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        // Stop custom audio
        if let player = audioPlayer, player.isPlaying {
            player.stop()
            DispatchQueue.main.async {
                self.isSpeaking = false
            }
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("❌ Audio player decode error: \(error)")
        }
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

// MARK: - Global Sound Manager
class GlobalSoundManager: ObservableObject {
    static let shared = GlobalSoundManager()
    
    private init() {
        print("✅ GlobalSoundManager initialized")
    }
    
    private var isSoundEnabled: Bool {
        // Check if click sounds are enabled in settings
        return SettingsManager.shared.clickSoundEnabled
    }
    
    func playTabClick() {
        guard isSoundEnabled else {
            print("🔇 Tab click sound disabled by user settings")
            return
        }
        
        // Play a pleasant system click sound for tab changes
        AudioServicesPlaySystemSound(1104) // Tock sound
        print("🔊 Tab click sound played")
        
        // Also add light haptic feedback for better UX
        DispatchQueue.main.async {
            HapticManager.shared.lightImpact()
        }
    }
    
    func playButtonClick() {
        guard isSoundEnabled else {
            print("🔇 Button click sound disabled by user settings")
            return
        }
        
        // Play a softer click sound for general buttons
        AudioServicesPlaySystemSound(1123) // Pop sound (softer than tock)
        print("🔊 Button click sound played")
        
        // Add very light haptic feedback for buttons
        DispatchQueue.main.async {
            HapticManager.shared.softImpact()
        }
    }
    
    func playActionSound() {
        guard isSoundEnabled else {
            print("🔇 Action sound disabled by user settings")
            return
        }
        
        // Play a confirmation sound for important actions
        AudioServicesPlaySystemSound(1016) // SMS tone (pleasant confirmation)
        print("🔊 Action sound played")
        
        // Medium haptic for important actions
        DispatchQueue.main.async {
            HapticManager.shared.mediumImpact()
        }
    }
}

// MARK: - Sound Button Styles
struct SoundButtonStyle: ButtonStyle {
    let soundType: ButtonSoundType
    
    enum ButtonSoundType {
        case normal    // Regular buttons
        case action    // Important actions (like Complete, Save, etc.)
        case silent    // No sound (for special cases)
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                // Play sound when button is pressed down
                if isPressed {
                    switch soundType {
                    case .normal:
                        GlobalSoundManager.shared.playButtonClick()
                    case .action:
                        GlobalSoundManager.shared.playActionSound()
                    case .silent:
                        break // No sound
                    }
                }
            }
    }
}

// MARK: - Convenience Extensions for Sound Buttons
extension Button {
    func soundButtonStyle(_ soundType: SoundButtonStyle.ButtonSoundType = .normal) -> some View {
        self.buttonStyle(SoundButtonStyle(soundType: soundType))
    }
    
    func actionSound() -> some View {
        self.buttonStyle(SoundButtonStyle(soundType: .action))
    }
    
    func silentButton() -> some View {
        self.buttonStyle(SoundButtonStyle(soundType: .silent))
    }
}

// MARK: - Global Button Style Environment
struct GlobalButtonStyleKey: EnvironmentKey {
    static let defaultValue: SoundButtonStyle.ButtonSoundType = .normal
}

extension EnvironmentValues {
    var globalButtonSound: SoundButtonStyle.ButtonSoundType {
        get { self[GlobalButtonStyleKey.self] }
        set { self[GlobalButtonStyleKey.self] = newValue }
    }
}

// MARK: - Audio Effects Manager
class AudioEffectsManager: ObservableObject {
    static let shared = AudioEffectsManager()
    
    private var correctSoundPlayer: AVAudioPlayer?
    private var wrongSoundPlayer: AVAudioPlayer?
    
    private init() {
        setupSoundPlayers()
    }
    
    private func setupSoundPlayers() {
        // Setup audio session for sound effects
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Audio Effects session setup failed: \(error)")
        }
        
        // Try to load bundled sound files, fallback to system sounds
        setupCorrectSound()
        setupWrongSound()
    }
    
    private func setupCorrectSound() {
        // Try to load custom sound file first
        if let path = Bundle.main.path(forResource: "correct", ofType: "wav") {
            let url = URL(fileURLWithPath: path)
            do {
                correctSoundPlayer = try AVAudioPlayer(contentsOf: url)
                correctSoundPlayer?.prepareToPlay()
                print("✅ Loaded custom correct sound")
                return
            } catch {
                print("❌ Failed to load custom correct sound: \(error)")
            }
        }
        
        // Fallback: Create a simple positive beep using system sound ID
        setupSystemCorrectSound()
    }
    
    private func setupWrongSound() {
        // Try to load custom sound file first
        if let path = Bundle.main.path(forResource: "wrong", ofType: "wav") {
            let url = URL(fileURLWithPath: path)
            do {
                wrongSoundPlayer = try AVAudioPlayer(contentsOf: url)
                wrongSoundPlayer?.prepareToPlay()
                print("✅ Loaded custom wrong sound")
                return
            } catch {
                print("❌ Failed to load custom wrong sound: \(error)")
            }
        }
        
        // Fallback: Create a simple negative sound
        setupSystemWrongSound()
    }
    
    private func setupSystemCorrectSound() {
        // Create a simple positive chime as fallback
        generateTone(frequency: 800, duration: 0.3, isCorrect: true)
    }
    
    private func setupSystemWrongSound() {
        // Create a simple negative buzz as fallback
        generateTone(frequency: 200, duration: 0.4, isCorrect: false)
    }
    
    private func generateTone(frequency: Double, duration: Double, isCorrect: Bool) {
        // This is a simplified version - generate basic tone data
        let sampleRate = 44100.0
        let samples = Int(sampleRate * duration)
        var audioData = Data()
        
        // Generate 16-bit PCM data
        for i in 0..<samples {
            let time = Double(i) / sampleRate
            let amplitude = sin(2.0 * Double.pi * frequency * time)
            let envelope = max(0, 1.0 - time / duration) // Fade out
            let sample = Int16(amplitude * envelope * 32767)
            
            audioData.append(contentsOf: withUnsafeBytes(of: sample.littleEndian) { Data($0) })
        }
        
        // Create temporary file for AVAudioPlayer
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(isCorrect ? "correct_tone.wav" : "wrong_tone.wav")
        
        // Create basic WAV header and save
        if createWAVFile(data: audioData, sampleRate: Int(sampleRate), channels: 1, bitsPerSample: 16, outputURL: tempURL) {
            do {
                let player = try AVAudioPlayer(contentsOf: tempURL)
                player.prepareToPlay()
                
                if isCorrect {
                    correctSoundPlayer = player
                } else {
                    wrongSoundPlayer = player
                }
                
                print("✅ Generated \(isCorrect ? "correct" : "wrong") tone")
            } catch {
                print("❌ Failed to create audio player from generated tone: \(error)")
            }
        }
    }
    
    private func createWAVFile(data: Data, sampleRate: Int, channels: Int, bitsPerSample: Int, outputURL: URL) -> Bool {
        // Simple WAV file creation
        let fileHeader = Data([
            // "RIFF" chunk descriptor
            0x52, 0x49, 0x46, 0x46, // "RIFF"
        ])
        
        var wavData = Data()
        wavData.append(fileHeader)
        
        // File size (will be updated)
        let fileSize = UInt32(36 + data.count).littleEndian
        wavData.append(contentsOf: withUnsafeBytes(of: fileSize) { Data($0) })
        
        // "WAVE" format
        wavData.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        
        // "fmt " sub-chunk
        wavData.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // Sub-chunk size
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // Audio format (PCM)
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian) { Data($0) }) // Channels
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) }) // Sample rate
        
        let byteRate = UInt32(sampleRate * channels * bitsPerSample / 8)
        wavData.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Data($0) }) // Byte rate
        
        let blockAlign = UInt16(channels * bitsPerSample / 8)
        wavData.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) }) // Block align
        wavData.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Data($0) }) // Bits per sample
        
        // "data" sub-chunk
        wavData.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        wavData.append(contentsOf: withUnsafeBytes(of: UInt32(data.count).littleEndian) { Data($0) }) // Data size
        wavData.append(data) // Audio data
        
        do {
            try wavData.write(to: outputURL)
            return true
        } catch {
            print("❌ Failed to write WAV file: \(error)")
            return false
        }
    }
    
    func playCorrectSound() {
        // Stop any currently playing sound to prevent overlap
        correctSoundPlayer?.stop()
        wrongSoundPlayer?.stop()
        
        correctSoundPlayer?.currentTime = 0
        correctSoundPlayer?.play()
        print("🔊 Playing correct answer sound")
    }
    
    func playWrongSound() {
        // Stop any currently playing sound to prevent overlap
        correctSoundPlayer?.stop()
        wrongSoundPlayer?.stop()
        
        wrongSoundPlayer?.currentTime = 0
        wrongSoundPlayer?.play()
        print("🔊 Playing wrong answer sound")
    }
}

// MARK: - Favorites Data Model
struct FavoriteWord: Codable, Identifiable {
    let id: UUID
    let kurdish: String
    let english: String
    let arabic: String
    let kurdishExample: String
    let englishExample: String
    let arabicExample: String
    let imageName: String
    let category: String
    let subcategory: String
    let dateAdded: Date
    
    init(kurdish: String, english: String, arabic: String, kurdishExample: String, englishExample: String, arabicExample: String, imageName: String, category: String, subcategory: String) {
        self.id = UUID()
        self.kurdish = kurdish
        self.english = english
        self.arabic = arabic
        self.kurdishExample = kurdishExample
        self.englishExample = englishExample
        self.arabicExample = arabicExample
        self.imageName = imageName
        self.category = category
        self.subcategory = subcategory
        self.dateAdded = Date()
    }
    
    // Convenience computed properties for the learning language manager
    func translation(for learningLanguage: LearningLanguageManager.LearningLanguage) -> String {
        switch learningLanguage {
        case .english: return english
        case .arabic: return arabic
        }
    }
    
    func example(for learningLanguage: LearningLanguageManager.LearningLanguage) -> String {
        switch learningLanguage {
        case .english: return englishExample
        case .arabic: return arabicExample
        }
    }
}

// MARK: - Review Data Model
struct ReviewWord: Codable, Identifiable {
    let id: UUID
    let kurdish: String
    let english: String
    let arabic: String
    let kurdishExample: String
    let englishExample: String
    let arabicExample: String
    let imageName: String
    let category: String
    let subcategory: String
    let dateAdded: Date
    let mistakeCount: Int
    
    init(kurdish: String, english: String, arabic: String, kurdishExample: String, englishExample: String, arabicExample: String, imageName: String, category: String, subcategory: String, mistakeCount: Int = 1) {
        self.id = UUID()
        self.kurdish = kurdish
        self.english = english
        self.arabic = arabic
        self.kurdishExample = kurdishExample
        self.englishExample = englishExample
        self.arabicExample = arabicExample
        self.imageName = imageName
        self.category = category
        self.subcategory = subcategory
        self.dateAdded = Date()
        self.mistakeCount = mistakeCount
    }
    
    // Convenience computed properties for the learning language manager
    func translation(for learningLanguage: LearningLanguageManager.LearningLanguage) -> String {
        switch learningLanguage {
        case .english: return english
        case .arabic: return arabic
        }
    }
    
    func example(for learningLanguage: LearningLanguageManager.LearningLanguage) -> String {
        switch learningLanguage {
        case .english: return englishExample
        case .arabic: return arabicExample
        }
    }
}

// MARK: - Favorites Manager
class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published var favoriteWords: [FavoriteWord] = []
    
    private let favoritesKey = "SavedFavoriteWords"
    
    private init() {
        loadFavorites()
    }
    
    func addToFavorites(_ word: FavoriteWord) {
        // Check if already exists (same Kurdish word in same category)
        if !favoriteWords.contains(where: { $0.kurdish == word.kurdish && $0.category == word.category }) {
            favoriteWords.append(word)
            saveFavorites()
            print("✅ Added to favorites: \(word.kurdish) from \(word.category)")
        }
    }
    
    func removeFromFavorites(kurdish: String, category: String) {
        favoriteWords.removeAll { $0.kurdish == kurdish && $0.category == category }
        saveFavorites()
        print("❌ Removed from favorites: \(kurdish) from \(category)")
    }
    
    func isWordFavorited(kurdish: String, category: String) -> Bool {
        return favoriteWords.contains { $0.kurdish == kurdish && $0.category == category }
    }
    
    func toggleFavorite(kurdish: String, english: String, arabic: String, kurdishExample: String, englishExample: String, arabicExample: String, imageName: String, category: String, subcategory: String) {
        if isWordFavorited(kurdish: kurdish, category: category) {
            removeFromFavorites(kurdish: kurdish, category: category)
        } else {
            let favoriteWord = FavoriteWord(
                kurdish: kurdish,
                english: english,
                arabic: arabic,
                kurdishExample: kurdishExample,
                englishExample: englishExample,
                arabicExample: arabicExample,
                imageName: imageName,
                category: category,
                subcategory: subcategory
            )
            addToFavorites(favoriteWord)
        }
    }
    
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favoriteWords) {
            UserDefaults.standard.set(encoded, forKey: favoritesKey)
            print("💾 Saved \(favoriteWords.count) favorites to UserDefaults")
        }
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let decoded = try? JSONDecoder().decode([FavoriteWord].self, from: data) {
            favoriteWords = decoded
            print("📱 Loaded \(favoriteWords.count) favorites from UserDefaults")
        }
    }
}

// MARK: - Review Manager
class ReviewManager: ObservableObject {
    static let shared = ReviewManager()
    
    @Published var reviewWords: [ReviewWord] = []
    @Published var shouldNavigateToReview: Bool = false
    
    private let reviewKey = "SavedReviewWords"
    
    private init() {
        loadReviewWords()
    }
    
    func addToReview(_ word: ReviewWord) {
        // Check if word already exists
        if let existingIndex = reviewWords.firstIndex(where: { $0.kurdish == word.kurdish && $0.category == word.category }) {
            // Increment mistake count for existing word
            let existingWord = reviewWords[existingIndex]
            let updatedWord = ReviewWord(
                kurdish: existingWord.kurdish,
                english: existingWord.english,
                arabic: existingWord.arabic,
                kurdishExample: existingWord.kurdishExample,
                englishExample: existingWord.englishExample,
                arabicExample: existingWord.arabicExample,
                imageName: existingWord.imageName,
                category: existingWord.category,
                subcategory: existingWord.subcategory,
                mistakeCount: existingWord.mistakeCount + 1
            )
            reviewWords[existingIndex] = updatedWord
        } else {
            // Add new word to review
            reviewWords.append(word)
        }
        saveReviewWords()
        print("✅ Added to review: \(word.kurdish) from \(word.category) (mistakes: \(word.mistakeCount))")
    }
    
    func removeFromReview(kurdish: String, category: String) {
        reviewWords.removeAll { $0.kurdish == kurdish && $0.category == category }
        saveReviewWords()
        print("❌ Removed from review: \(kurdish) from \(category)")
    }
    
    func isWordInReview(kurdish: String, category: String) -> Bool {
        return reviewWords.contains { $0.kurdish == kurdish && $0.category == category }
    }
    
    func markAsReviewed(kurdish: String, category: String) {
        removeFromReview(kurdish: kurdish, category: category)
    }
    
    func navigateToReviewSection() {
        shouldNavigateToReview = true
    }
    
    private func saveReviewWords() {
        if let encoded = try? JSONEncoder().encode(reviewWords) {
            UserDefaults.standard.set(encoded, forKey: reviewKey)
            print("💾 Saved \(reviewWords.count) review words to UserDefaults")
        }
    }
    
    private func loadReviewWords() {
        if let data = UserDefaults.standard.data(forKey: reviewKey),
           let decoded = try? JSONDecoder().decode([ReviewWord].self, from: data) {
            reviewWords = decoded
            print("📱 Loaded \(reviewWords.count) review words from UserDefaults")
        }
    }
}

// MARK: - Settings Manager
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // Audio & Interaction Settings
    @Published var clickSoundEnabled: Bool {
        didSet { UserDefaults.standard.set(clickSoundEnabled, forKey: "clickSoundEnabled") }
    }
    
    @Published var autoPlayWordAudio: Bool {
        didSet { UserDefaults.standard.set(autoPlayWordAudio, forKey: "autoPlayWordAudio") }
    }
    
    @Published var useNativeKurdishAudio: Bool {
        didSet { UserDefaults.standard.set(useNativeKurdishAudio, forKey: "useNativeKurdishAudio") }
    }
    
    @Published var hapticFeedbackEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticFeedbackEnabled, forKey: "hapticFeedbackEnabled") }
    }
    
    // Dark mode preference (existing)
    @Published var darkModePreference: DarkModePreference {
        didSet {
            UserDefaults.standard.set(darkModePreference.rawValue, forKey: "darkModePreference")
            updateColorScheme()
        }
    }
    
    private init() {
        // Load saved preferences with default values
        self.clickSoundEnabled = UserDefaults.standard.object(forKey: "clickSoundEnabled") as? Bool ?? true
        self.autoPlayWordAudio = UserDefaults.standard.object(forKey: "autoPlayWordAudio") as? Bool ?? true
        self.useNativeKurdishAudio = UserDefaults.standard.object(forKey: "useNativeKurdishAudio") as? Bool ?? true
        self.hapticFeedbackEnabled = UserDefaults.standard.object(forKey: "hapticFeedbackEnabled") as? Bool ?? true
        
        let darkModeRawValue = UserDefaults.standard.object(forKey: "darkModePreference") as? String ?? DarkModePreference.system.rawValue
        self.darkModePreference = DarkModePreference(rawValue: darkModeRawValue) ?? .system
        
        print("📱 Settings loaded - Click: \(clickSoundEnabled), AutoPlay: \(autoPlayWordAudio), Native: \(useNativeKurdishAudio), Haptic: \(hapticFeedbackEnabled)")
    }
    
    private func updateColorScheme() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        switch darkModePreference {
        case .light:
            windowScene.windows.forEach { $0.overrideUserInterfaceStyle = .light }
        case .dark:
            windowScene.windows.forEach { $0.overrideUserInterfaceStyle = .dark }
        case .system:
            windowScene.windows.forEach { $0.overrideUserInterfaceStyle = .unspecified }
        }
    }
}

// MARK: - Dark Mode Preference
enum DarkModePreference: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .system: return "gear"
        }
    }
}

// MARK: - Achievement Data Models
struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String
    let category: AchievementCategory
    let requirement: Int
    let currentProgress: Int
    let isUnlocked: Bool
    let unlockedDate: Date?
    
    enum AchievementCategory: String, Codable, CaseIterable {
        case learning = "Learning"
        case streak = "Consistency" 
        case mastery = "Mastery"
        case exploration = "Explorer"
        
        var color: Color {
            switch self {
            case .learning: return .blue
            case .streak: return .orange
            case .mastery: return .purple
            case .exploration: return .green
            }
        }
    }
    
    var progressPercentage: Double {
        guard requirement > 0 else { return isUnlocked ? 1.0 : 0.0 }
        return min(Double(currentProgress) / Double(requirement), 1.0)
    }
    
    var isInProgress: Bool {
        return currentProgress > 0 && !isUnlocked
    }
}

// MARK: - Achievement Manager
class AchievementManager: ObservableObject {
    static let shared = AchievementManager()
    
    @Published var achievements: [Achievement] = []
    @Published var recentlyUnlocked: [Achievement] = []
    
    private let achievementsKey = "userAchievements"
    private let recentUnlockedKey = "recentlyUnlockedAchievements"
    
    private init() {
        setupDefaultAchievements()
        loadAchievements()
    }
    
    private func setupDefaultAchievements() {
        let defaultAchievements = [
            // Learning Achievements
            Achievement(
                id: "first_lesson",
                title: "First Steps",
                subtitle: "Complete your first lesson",
                iconName: "graduationcap.fill",
                category: .learning,
                requirement: 1,
                currentProgress: 0,
                isUnlocked: false,
                unlockedDate: nil
            ),
            Achievement(
                id: "lessons_5",
                title: "Getting Started",
                subtitle: "Complete 5 lessons",
                iconName: "book.fill",
                category: .learning,
                requirement: 5,
                currentProgress: 0,
                isUnlocked: false,
                unlockedDate: nil
            ),
            Achievement(
                id: "lessons_25",
                title: "Dedicated Learner",
                subtitle: "Complete 25 lessons",
                iconName: "books.vertical.fill",
                category: .learning,
                requirement: 25,
                currentProgress: 0,
                isUnlocked: false,
                unlockedDate: nil
            ),
            
            // Vocabulary Achievements
            Achievement(
                id: "words_10",
                title: "Word Explorer",
                subtitle: "Learn 10 new words",
                iconName: "textformat.abc",
                category: .exploration,
                requirement: 10,
                currentProgress: 0,
                isUnlocked: false,
                unlockedDate: nil
            ),
            Achievement(
                id: "words_50",
                title: "Vocabulary Builder",
                subtitle: "Learn 50 new words",
                iconName: "text.book.closed.fill",
                category: .exploration,
                requirement: 50,
                currentProgress: 0,
                isUnlocked: false,
                unlockedDate: nil
            ),
            Achievement(
                id: "words_100",
                title: "Word Master",
                subtitle: "Learn 100 new words",
                iconName: "character.book.closed.fill",
                category: .mastery,
                requirement: 100,
                currentProgress: 0,
                isUnlocked: false,
                unlockedDate: nil
            ),
            
            // Streak Achievements
            Achievement(
                id: "streak_3",
                title: "Consistent",
                subtitle: "Practice 3 days in a row",
                iconName: "flame.fill",
                category: .streak,
                requirement: 3,
                currentProgress: 0,
                isUnlocked: false,
                unlockedDate: nil
            ),
            Achievement(
                id: "streak_7",
                title: "Week Warrior",
                subtitle: "Practice 7 days in a row",
                iconName: "calendar.badge.clock",
                category: .streak,
                requirement: 7,
                currentProgress: 0,
                isUnlocked: false,
                unlockedDate: nil
            ),
            Achievement(
                id: "streak_30",
                title: "Monthly Champion",
                subtitle: "Practice 30 days in a row",
                iconName: "crown.fill",
                category: .streak,
                requirement: 30,
                currentProgress: 0,
                isUnlocked: false,
                unlockedDate: nil
            ),
            
            // Category Achievements
            Achievement(
                id: "category_complete",
                title: "Category Master",
                subtitle: "Complete all lessons in a category",
                iconName: "checkmark.seal.fill",
                category: .mastery,
                requirement: 1,
                currentProgress: 0,
                isUnlocked: false,
                unlockedDate: nil
            )
        ]
        
        // Only set if achievements is empty (first run)
        if achievements.isEmpty {
            achievements = defaultAchievements
        }
    }
    
    private func loadAchievements() {
        if let data = UserDefaults.standard.data(forKey: achievementsKey),
           let savedAchievements = try? JSONDecoder().decode([Achievement].self, from: data) {
            achievements = savedAchievements
            print("📊 Loaded \(achievements.count) achievements from storage")
        }
        
        if let data = UserDefaults.standard.data(forKey: recentUnlockedKey),
           let savedRecent = try? JSONDecoder().decode([Achievement].self, from: data) {
            recentlyUnlocked = savedRecent
        }
    }
    
    private func saveAchievements() {
        if let data = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(data, forKey: achievementsKey)
        }
        
        if let data = try? JSONEncoder().encode(recentlyUnlocked) {
            UserDefaults.standard.set(data, forKey: recentUnlockedKey)
        }
    }
    
    // MARK: - Progress Tracking
    func updateProgress(for achievementId: String, newProgress: Int) {
        guard let index = achievements.firstIndex(where: { $0.id == achievementId }) else { return }
        
        var achievement = achievements[index]
        let oldProgress = achievement.currentProgress
        
        // Update progress
        achievement = Achievement(
            id: achievement.id,
            title: achievement.title,
            subtitle: achievement.subtitle,
            iconName: achievement.iconName,
            category: achievement.category,
            requirement: achievement.requirement,
            currentProgress: max(oldProgress, newProgress), // Only increase progress
            isUnlocked: achievement.isUnlocked,
            unlockedDate: achievement.unlockedDate
        )
        
        // Check if achievement should be unlocked
        if !achievement.isUnlocked && achievement.currentProgress >= achievement.requirement {
            unlockAchievement(at: index, achievement: achievement)
        } else {
            achievements[index] = achievement
            saveAchievements()
        }
    }
    
    private func unlockAchievement(at index: Int, achievement: Achievement) {
        let unlockedAchievement = Achievement(
            id: achievement.id,
            title: achievement.title,
            subtitle: achievement.subtitle,
            iconName: achievement.iconName,
            category: achievement.category,
            requirement: achievement.requirement,
            currentProgress: achievement.currentProgress,
            isUnlocked: true,
            unlockedDate: Date()
        )
        
        achievements[index] = unlockedAchievement
        recentlyUnlocked.append(unlockedAchievement)
        
        // Keep only the 5 most recent unlocks
        if recentlyUnlocked.count > 5 {
            recentlyUnlocked.removeFirst()
        }
        
        print("🏆 Achievement unlocked: \(achievement.title)")
        saveAchievements()
        
        // Trigger haptic feedback for achievement unlock
        DispatchQueue.main.async {
            HapticManager.shared.successNotification()
        }
    }
    
    // MARK: - Convenience Methods
    func recordLessonCompletion() {
        updateProgress(for: "first_lesson", newProgress: 1)
        
        let currentLessons = achievements.first(where: { $0.id == "lessons_5" })?.currentProgress ?? 0
        updateProgress(for: "lessons_5", newProgress: currentLessons + 1)
        updateProgress(for: "lessons_25", newProgress: currentLessons + 1)
    }
    
    func recordWordsLearned(count: Int) {
        let oldProgress = achievements.first(where: { $0.id == "words_10" })?.currentProgress ?? 0
        
        updateProgress(for: "words_10", newProgress: count)
        updateProgress(for: "words_50", newProgress: count)
        updateProgress(for: "words_100", newProgress: count)
        
        // Check if we just reached exactly 10 words
        if oldProgress < 10 && count >= 10 {
            showTenWordsMessage()
        }
        
        // Check if we just reached exactly 25 words
        if oldProgress < 25 && count >= 25 {
            showTwentyFiveWordsMessage()
        }
    }
    
    func recordStreak(days: Int) {
        updateProgress(for: "streak_3", newProgress: days)
        updateProgress(for: "streak_7", newProgress: days)
        updateProgress(for: "streak_30", newProgress: days)
    }
    
    func recordCategoryCompletion() {
        updateProgress(for: "category_complete", newProgress: 1)
    }
    
    var unlockedCount: Int {
        achievements.filter { $0.isUnlocked }.count
    }
    
    var totalCount: Int {
        achievements.count
    }
    
    // MARK: - Motivational Messages
    private func showTenWordsMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("tenWordsTitle"),
                message: localizationManager.localized("tenWordsMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("blooming"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            }
            
            print("🌸 10 words milestone reached - Kurdish is blooming!")
        }
    }
    
    private func showTwentyFiveWordsMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("twentyFiveWordsTitle"),
                message: localizationManager.localized("twentyFiveWordsMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("walking"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            }
            
            print("🚶‍♂️ 25 words milestone reached - Walking in ancestral language!")
        }
    }
    
    func showCulturalMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("culturalMessageTitle"),
                message: localizationManager.localized("culturalMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("beautiful"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            }
            
            print("🏔️ Cultural message displayed - Kurdish is more than words!")
        }
    }
    
    func showQuizStruggleMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("quizStruggleTitle"),
                message: localizationManager.localized("quizStruggleMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("hopeful"), style: .default) { _ in
                // Trigger gentle haptic feedback
                HapticManager.shared.lightImpact()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger gentle haptic feedback
                HapticManager.shared.lightImpact()
            }
            
            print("💫 Quiz struggle message displayed - encouraging hope!")
        }
    }
}

// MARK: - Learning Language Manager
class LearningLanguageManager: ObservableObject {
    static let shared = LearningLanguageManager()
    
    @Published var currentLearningLanguage: LearningLanguage = .english
    
    enum LearningLanguage: String, CaseIterable {
        case english = "en"
        case arabic = "ar"
        
        var displayName: String {
            switch self {
            case .english: return "🇺🇸 English"
            case .arabic: return "🇸🇾 Arabic"
            }
        }
        
        var nativeName: String {
            switch self {
            case .english: return "English"
            case .arabic: return "العربية"
            }
        }
    }
    
    private let learningLanguageKey = "LearningLanguage"
    
    private init() {
        loadLearningLanguagePreference()
    }
    
    func setLearningLanguage(_ language: LearningLanguage) {
        currentLearningLanguage = language
        saveLearningLanguagePreference()
    }
    
    private func loadLearningLanguagePreference() {
        if let savedLanguage = UserDefaults.standard.string(forKey: learningLanguageKey),
           let language = LearningLanguage(rawValue: savedLanguage) {
            currentLearningLanguage = language
        } else {
            // Default to English for learning
            currentLearningLanguage = .english
            saveLearningLanguagePreference()
        }
        print("📚 Loaded learning language preference: \(currentLearningLanguage.rawValue)")
    }
    
    private func saveLearningLanguagePreference() {
        UserDefaults.standard.set(currentLearningLanguage.rawValue, forKey: learningLanguageKey)
        print("💾 Saved learning language preference: \(currentLearningLanguage.rawValue)")
    }
}

// MARK: - Localization Manager
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: AppLanguage = .english
    
    enum AppLanguage: String, CaseIterable {
        case english = "en"
        case arabic = "ar"
        
        var displayName: String {
            switch self {
            case .english: return "🇺🇸 English"
            case .arabic: return "🇸🇾 العربية"
            }
        }
        
        var quickToggleSymbol: String {
            switch self {
            case .english: return "ع"  // Show Arabic symbol when in English mode
            case .arabic: return "EN"  // Show English when in Arabic mode
            }
        }
    }
    
    private let languageKey = "AppLanguage"
    
    // Localization data
    private let localizations: [String: [String: String]] = [
        "en": [
            // Tab Bar
            "settings": "Settings",
            "favorites": "Favorites",
            "profile": "Profile",
            "leaderboard": "Leaderboard",
            "dilan": "Dîlan",
            
            // Profile Tab
            "welcome": "Welcome,",
            "kurdishLanguageLearner": "Kurdish Language Learner",
            "learningProgress": "Learning Progress",
            "quickActions": "Quick Actions",
            "viewAllAchievements": "View all achievements",
            "reviewDifficultWords": "Review difficult words",
            "learningActivity": "Learning Activity",
            "timeSpentLearning": "Time spent learning",
            "lastActive": "Last active",
            "accountInformation": "Account Information",
            "accountActions": "Account Actions",
            "signOut": "Sign Out",
            "logOutAccount": "Log out of your account",
            "email": "Email",
            "displayName": "Display Name",
            "userID": "User ID",
            
            // Settings Tab
            "customizeExperience": "Customize your learning experience",
            "developerOptions": "Developer Options",
            "skipAuthentication": "Skip Authentication",
            "bypassLoginTesting": "Bypass login and onboarding for testing",
            "resetDebugSettings": "Reset Debug Settings",
            "clearDebugPreferences": "Clear all debug preferences",
            "reset": "Reset",
            "appPreferences": "App Preferences",
            "appLanguage": "App Language",
            "chooseInterfaceLanguage": "Choose your interface language",
            "learningPreferences": "Learning Preferences",
            "learningLanguage": "Learning Language",
            "chooseLearningLanguage": "Choose the language you want to learn Kurdish through",
            "clickSound": "Click Sound",
            "enableSoundsInteractions": "Enable sounds on taps and interactions",
            "autoPlayWordAudio": "Auto-Play Word Audio",
            "autoPlayKurdishWords": "Automatically play Kurdish words when shown",
            "useNativeKurdishAudio": "Use Native Kurdish Audio",
            "useCustomRecordings": "Use only custom Kurdish recordings, no system TTS",
            
            // Favorites Tab
            "yourFavoriteWords": "Your favorite Kurdish words",
            "wordsToReview": "Words to review from quizzes",
            "toReview": "To Review",
            "noFavoritesYet": "No favorites yet",
            "tapHeartIcon": "Tap the heart icon on words you want to remember!",
            "noWordsToReview": "No words to review",
            "takeQuizzesIdentify": "Take quizzes to identify words that need more practice!",
            "wordsAnsweredIncorrectly": "Words you answered incorrectly in quizzes",
            
            // Common Actions
            "done": "Done",
            "close": "Close",
            "tryAgain": "Try Again",
            "perfectDone": "Perfect! Done",
            
            // Learning Progress
            "wordsLearned": "Words Learned",
            "lessonsCompleted": "Lessons Completed",
            "quizAccuracy": "Quiz Accuracy",
            
            // Quiz
            "quizCompleted": "Quiz Completed!",
            "youScored": "You scored",
            "outOf": "out of",
            "whatDoesThisMean": "What does this mean in English?",
            "question": "Question",
            "of": "of",
            
            // First Lesson Message
            "firstLessonTitle": "🎉 Dest xêrê!",
            "firstLessonMessage": "You've started your Kurdish journey with strength.",
            "continue": "Continue",
            
            // Category Completion Message
            "categoryCompleteTitle": "🏆 Category Mastered!",
            "categoryCompleteMessage": "You've mastered a full category! Like weaving a kilim, every piece matters.",
            "amazing": "Amazing!",
            
            // Greetings Subcategory Completion Message
            "greetingsCompleteTitle": "👋 Silav kir!",
            "greetingsCompleteMessage": "You now greet like a true Kurd.",
            "wonderful": "Wonderful!",
            
            // Family Relationships Subcategory Completion Message
            "familyCompleteTitle": "👨‍👩‍👧‍👦 Language of Kinship",
            "familyCompleteMessage": "You're speaking the language of kinship — Kurdî is the voice of connection.",
            "beautiful": "Beautiful!",
            
            // Polite Phrases Subcategory Completion Message
            "politeCompleteTitle": "🙏 Zarokê hunermendî",
            "politeCompleteMessage": "Zarokê hunermendî — politeness is power. Spas dikim!",
            "excellent": "Excellent!",
            
            // Basic Questions Subcategory Completion Message
            "questionsCompleteTitle": "❓ Like a Local!",
            "questionsCompleteMessage": "You ask like a local! Curious minds grow fast.",
            "fantastic": "Fantastic!",
            
            // Day 1 Streak Message
            "dayOneStreakTitle": "🔥 Rojek nû, zimanek nû!",
            "dayOneStreakMessage": "Rojek nû, zimanek nû! One step closer today.",
            "letsGo": "Let's go!",
            
            // Day 2 Streak Message
            "dayTwoStreakTitle": "🌱 Dayîkê Kurdistan",
            "dayTwoStreakMessage": "Dayîkê Kurdistan dibêje: 'Bi hevrê ziman dibin nas.'",
            "inspiring": "Inspiring!",
            
            // Day 3 Streak Message
            "dayThreeStreakTitle": "🐐 Mountain Strong!",
            "dayThreeStreakMessage": "Three days strong! Like a mountain goat — sure-footed and rising.",
            "unstoppable": "Unstoppable!",
            
            // Day 5 Streak Message
            "dayFiveStreakTitle": "💪 Growing Stronger!",
            "dayFiveStreakMessage": "You're growing stronger in spirit and words. her biji",
            "powerful": "Powerful!",
            
            // Day 7 Streak Message
            "daySevenStreakTitle": "🔥 Fire of Fluency!",
            "daySevenStreakMessage": "You've lit your first fire of fluency! 🔥 Ronahî li te ye.",
            "brilliant": "Brilliant!",
            
            // Day 14 Streak Message
            "dayFourteenStreakTitle": "🏛️ Heritage Guardian",
            "dayFourteenStreakMessage": "Bi dengê xwe, çanda xwe biparêze — your voice protects your heritage.",
            "guardian": "Guardian!",
            
            // Day 30 Streak Message
            "dayThirtyStreakTitle": "🥁 Rhythm of the Daf",
            "dayThirtyStreakMessage": "30 days of commitment — like the rhythm of the daf, you never stopped beating!",
            "rhythmic": "Rhythmic!",
            
            // 10 Words Milestone Message
            "tenWordsTitle": "🌸 Blooming in Afrin",
            "tenWordsMessage": "10 words down — your Kurdish is blooming like spring in Afrin.",
            "blooming": "Blooming!",
            
            // 25 Words Milestone Message
            "twentyFiveWordsTitle": "🚶‍♂️ First Steps of Heritage",
            "twentyFiveWordsMessage": "You're walking your first kilometers in the language of your ancestors.",
            "walking": "Walking Strong!",
            
            // General Cultural Message
            "culturalMessageTitle": "🏔️ Beyond Words",
            "culturalMessage": "Kurdish is more than words — it's dance, mountains, and resistance.",
            "beautiful": "Beautiful!",
            
            // Quiz Struggle/Failure Message
            "quizStruggleTitle": "💫 Her tişt bi hêvî",
            "quizStruggleMessage": "Her tişt bi hêvî dest pê dike — all things begin with hope.",
            "hopeful": "Keep Going!"
        ],
        "ar": [
            // Tab Bar
            "settings": "الإعدادات",
            "favorites": "المفضلة",
            "profile": "الملف الشخصي",
            "leaderboard": "لوحة المتصدرين",
            "dilan": "دیلان",
            
            // Profile Tab
            "welcome": "مرحباً،",
            "kurdishLanguageLearner": "متعلم اللغة الكردية",
            "learningProgress": "تقدم التعلم",
            "quickActions": "إجراءات سريعة",
            "viewAllAchievements": "عرض جميع الإنجازات",
            "reviewDifficultWords": "مراجعة الكلمات الصعبة",
            "learningActivity": "نشاط التعلم",
            "timeSpentLearning": "الوقت المُستغرق في التعلم",
            "lastActive": "آخر نشاط",
            "accountInformation": "معلومات الحساب",
            "accountActions": "إجراءات الحساب",
            "signOut": "تسجيل الخروج",
            "logOutAccount": "تسجيل الخروج من حسابك",
            "email": "البريد الإلكتروني",
            "displayName": "اسم العرض",
            "userID": "معرف المستخدم",
            
            // Settings Tab
            "customizeExperience": "تخصيص تجربة التعلم الخاصة بك",
            "developerOptions": "خيارات المطور",
            "skipAuthentication": "تخطي المصادقة",
            "bypassLoginTesting": "تجاوز تسجيل الدخول والإعداد للاختبار",
            "resetDebugSettings": "إعادة تعيين إعدادات التصحيح",
            "clearDebugPreferences": "مسح جميع تفضيلات التصحيح",
            "reset": "إعادة تعيين",
            "appPreferences": "تفضيلات التطبيق",
            "appLanguage": "لغة التطبيق",
            "chooseInterfaceLanguage": "اختر لغة الواجهة",
            "learningPreferences": "تفضيلات التعلم",
            "learningLanguage": "لغة التعلم",
            "chooseLearningLanguage": "اختر اللغة التي تريد تعلم الكردية من خلالها",
            "clickSound": "صوت النقر",
            "enableSoundsInteractions": "تمكين الأصوات عند النقر والتفاعل",
            "autoPlayWordAudio": "تشغيل صوت الكلمة تلقائياً",
            "autoPlayKurdishWords": "تشغيل الكلمات الكردية تلقائياً عند عرضها",
            "useNativeKurdishAudio": "استخدام الصوت الكردي الأصلي",
            "useCustomRecordings": "استخدام التسجيلات الكردية المخصصة فقط، بدون تحويل النص إلى كلام",
            
            // Favorites Tab
            "yourFavoriteWords": "كلماتك الكردية المفضلة",
            "wordsToReview": "كلمات للمراجعة من الاختبارات",
            "toReview": "للمراجعة",
            "noFavoritesYet": "لا توجد مفضلة بعد",
            "tapHeartIcon": "اضغط على أيقونة القلب على الكلمات التي تريد تذكرها!",
            "noWordsToReview": "لا توجد كلمات للمراجعة",
            "takeQuizzesIdentify": "أجري اختبارات لتحديد الكلمات التي تحتاج المزيد من الممارسة!",
            "wordsAnsweredIncorrectly": "الكلمات التي أجبت عليها خطأً في الاختبارات",
            
            // Common Actions
            "done": "تم",
            "close": "إغلاق",
            "tryAgain": "حاول مرة أخرى",
            "perfectDone": "ممتاز! تم",
            
            // Learning Progress
            "wordsLearned": "كلمات مُتعلمة",
            "lessonsCompleted": "دروس مكتملة",
            "quizAccuracy": "دقة الاختبار",
            
            // Quiz
            "quizCompleted": "اكتمل الاختبار!",
            "youScored": "لقد حصلت على",
            "outOf": "من",
            "whatDoesThisMean": "ماذا تعني هذه بالإنجليزية؟",
            "question": "سؤال",
            "of": "من",
            
            // First Lesson Message
            "firstLessonTitle": "🎉 !Dest xêrê",
            "firstLessonMessage": "لقد بدأت رحلتك الكردية بقوة.",
            "continue": "متابعة",
            
            // Category Completion Message
            "categoryCompleteTitle": "🏆 !أتقنت الفئة",
            "categoryCompleteMessage": "لقد أتقنت فئة كاملة! مثل نسج الكليم، كل قطعة مهمة.",
            "amazing": "رائع!",
            
            // Greetings Subcategory Completion Message
            "greetingsCompleteTitle": "👋 !Silav kir",
            "greetingsCompleteMessage": "أنت الآن تحيي مثل كردي حقيقي.",
            "wonderful": "رائع!",
            
            // Family Relationships Subcategory Completion Message
            "familyCompleteTitle": "👨‍👩‍👧‍👦 لغة القرابة",
            "familyCompleteMessage": "أنت تتحدث بلغة القرابة — الكردية هي صوت التواصل.",
            "beautiful": "جميل!",
            
            // Polite Phrases Subcategory Completion Message
            "politeCompleteTitle": "🙏 Zarokê hunermendî",
            "politeCompleteMessage": "Zarokê hunermendî — الأدب قوة. !Spas dikim",
            "excellent": "ممتاز!",
            
            // Basic Questions Subcategory Completion Message
            "questionsCompleteTitle": "❓ !مثل السكان المحليين",
            "questionsCompleteMessage": "تسأل مثل السكان المحليين! العقول الفضولية تنمو بسرعة.",
            "fantastic": "رائع!",
            
            // Day 1 Streak Message
            "dayOneStreakTitle": "🔥 !Rojek nû, zimanek nû",
            "dayOneStreakMessage": "!Rojek nû, zimanek nû خطوة أقرب اليوم.",
            "letsGo": "!هيا بنا",
            
            // Day 2 Streak Message
            "dayTwoStreakTitle": "🌱 Dayîkê Kurdistan",
            "dayTwoStreakMessage": "Dayîkê Kurdistan dibêje: 'Bi hevrê ziman dibin nas.'",
            "inspiring": "!ملهم",
            
            // Day 3 Streak Message
            "dayThreeStreakTitle": "🐐 !قوي كالجبل",
            "dayThreeStreakMessage": "ثلاثة أيام قوية! مثل تيس الجبل — قدم ثابتة وصاعد.",
            "unstoppable": "!لا يمكن إيقافه",
            
            // Day 5 Streak Message
            "dayFiveStreakTitle": "💪 !تنمو أقوى",
            "dayFiveStreakMessage": "أنت تنمو أقوى في الروح والكلمات. her biji",
            "powerful": "!قوي",
            
            // Day 7 Streak Message
            "daySevenStreakTitle": "🔥 !نار الطلاقة",
            "daySevenStreakMessage": "لقد أشعلت أول نار الطلاقة! 🔥 .Ronahî li te ye",
            "brilliant": "!رائع",
            
            // Day 14 Streak Message
            "dayFourteenStreakTitle": "🏛️ حارس التراث",
            "dayFourteenStreakMessage": "Bi dengê xwe, çanda xwe biparêze — صوتك يحمي تراثك.",
            "guardian": "!حارس",
            
            // Day 30 Streak Message
            "dayThirtyStreakTitle": "🥁 إيقاع الدف",
            "dayThirtyStreakMessage": "30 يوماً من الالتزام — مثل إيقاع الدف، لم تتوقف عن الضرب!",
            "rhythmic": "!إيقاعي",
            
            // 10 Words Milestone Message
            "tenWordsTitle": "🌸 يزهر في عفرين",
            "tenWordsMessage": "10 كلمات انتهت — كرديتك تزهر مثل الربيع في عفرين.",
            "blooming": "!يزهر",
            
            // 25 Words Milestone Message
            "twentyFiveWordsTitle": "🚶‍♂️ خطوات التراث الأولى",
            "twentyFiveWordsMessage": "أنت تسير أولى كيلومتراتك في لغة أجدادك.",
            "walking": "!تسير بقوة",
            
            // General Cultural Message
            "culturalMessageTitle": "🏔️ أبعد من الكلمات",
            "culturalMessage": "الكردية أكثر من كلمات — إنها رقص وجبال ومقاومة.",
            "beautiful": "!جميل",
            
            // Quiz Struggle/Failure Message
            "quizStruggleTitle": "💫 Her tişt bi hêvî",
            "quizStruggleMessage": "Her tişt bi hêvî dest pê dike — كل شيء يبدأ بالأمل.",
            "hopeful": "!استمر"
        ]
    ]
    
    private init() {
        loadLanguagePreference()
    }
    
    func localized(_ key: String) -> String {
        return localizations[currentLanguage.rawValue]?[key] ?? key
    }
    
    func toggleLanguage() {
        currentLanguage = currentLanguage == .english ? .arabic : .english
        saveLanguagePreference()
    }
    
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        saveLanguagePreference()
    }
    
    private func loadLanguagePreference() {
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            currentLanguage = language
        } else {
            // Default to device language if available, otherwise English
            let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            currentLanguage = deviceLanguage.hasPrefix("ar") ? .arabic : .english
            saveLanguagePreference()
        }
        print("📱 Loaded language preference: \(currentLanguage.rawValue)")
    }
    
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        print("💾 Saved language preference: \(currentLanguage.rawValue)")
    }
}

// MARK: - Streak Manager
class StreakManager: ObservableObject {
    static let shared = StreakManager()
    
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var totalLearningTime: TimeInterval = 0 // Total learning time in seconds
    
    private let currentStreakKey = "dailyStreak"
    private let longestStreakKey = "longestStreak"
    private let lastActivityDateKey = "lastActivityDate"
    private let totalLearningTimeKey = "totalLearningTime"
    private let sessionStartTimeKey = "sessionStartTime"
    
    private init() {
        loadStreak()
        checkStreakContinuity()
    }
    
    private func loadStreak() {
        currentStreak = UserDefaults.standard.integer(forKey: currentStreakKey)
        longestStreak = UserDefaults.standard.integer(forKey: longestStreakKey)
        totalLearningTime = UserDefaults.standard.double(forKey: totalLearningTimeKey)
        print("📊 Loaded streak - Current: \(currentStreak), Longest: \(longestStreak), Learning time: \(totalLearningTime)s")
    }
    
    private func saveStreak() {
        UserDefaults.standard.set(currentStreak, forKey: currentStreakKey)
        UserDefaults.standard.set(longestStreak, forKey: longestStreakKey)
        UserDefaults.standard.set(totalLearningTime, forKey: totalLearningTimeKey)
        print("💾 Saved streak - Current: \(currentStreak), Longest: \(longestStreak), Learning time: \(totalLearningTime)s")
    }
    
    func startLearningSession() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: sessionStartTimeKey)
        print("⏱️ Learning session started")
    }
    
    func endLearningSession() {
        guard let startTime = UserDefaults.standard.object(forKey: sessionStartTimeKey) as? TimeInterval else {
            print("⚠️ No session start time found")
            return
        }
        
        let sessionDuration = Date().timeIntervalSince1970 - startTime
        totalLearningTime += sessionDuration
        saveStreak()
        
        // Clear session start time
        UserDefaults.standard.removeObject(forKey: sessionStartTimeKey)
        print("⏱️ Learning session ended. Duration: \(sessionDuration)s, Total: \(totalLearningTime)s")
    }
    
    func getLastActivityDate() -> Date? {
        return UserDefaults.standard.object(forKey: lastActivityDateKey) as? Date
    }
    
    func getFormattedLearningTime() -> String {
        let hours = Int(totalLearningTime) / 3600
        let minutes = Int(totalLearningTime) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    func getLastActivityString() -> String {
        guard let lastActivity = getLastActivityDate() else {
            return "No recent activity"
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let lastActivityDay = Calendar.current.startOfDay(for: lastActivity)
        
        if Calendar.current.isDate(lastActivityDay, inSameDayAs: today) {
            return "Active today"
        } else {
            let daysDifference = Calendar.current.dateComponents([.day], from: lastActivityDay, to: today).day ?? 0
            if daysDifference == 1 {
                return "Active yesterday"
            } else {
                return "\(daysDifference) days ago"
            }
        }
    }
    
    func recordActivity() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastActivityDate = UserDefaults.standard.object(forKey: lastActivityDateKey) as? Date
        
        // Check if activity already recorded today
        if let lastDate = lastActivityDate,
           Calendar.current.isDate(lastDate, inSameDayAs: today) {
            print("🔥 Activity already recorded today")
            return
        }
        
        // Check if this continues the streak
        if let lastDate = lastActivityDate {
            let daysBetween = Calendar.current.dateComponents([.day], from: lastDate, to: today).day ?? 0
            
            if daysBetween == 1 {
                // Consecutive day - increment streak
                currentStreak += 1
                print("🔥 Streak continued! Day \(currentStreak)")
                
                // Show Day 2 message
                if currentStreak == 2 {
                    showDayTwoStreakMessage()
                }
                // Show Day 3 message
                else if currentStreak == 3 {
                    showDayThreeStreakMessage()
                }
                // Show Day 5 message
                else if currentStreak == 5 {
                    showDayFiveStreakMessage()
                }
                // Show Day 7 message
                else if currentStreak == 7 {
                    showDaySevenStreakMessage()
                }
                // Show Day 14 message
                else if currentStreak == 14 {
                    showDayFourteenStreakMessage()
                }
                // Show Day 30 message
                else if currentStreak == 30 {
                    showDayThirtyStreakMessage()
                }
            } else if daysBetween > 1 {
                // Gap in activity - reset streak
                currentStreak = 1
                print("🔥 Streak reset due to gap. Starting fresh at day 1")
                showDayOneStreakMessage()
            }
            // If daysBetween == 0, it's the same day (shouldn't happen due to check above)
        } else {
            // First time activity
            currentStreak = 1
            print("🔥 First activity recorded! Starting streak at day 1")
            showDayOneStreakMessage()
        }
        
        // Update longest streak if needed
        if currentStreak > longestStreak {
            longestStreak = currentStreak
            print("🏆 New longest streak record: \(longestStreak) days!")
        }
        
        // Save the activity date and streak
        UserDefaults.standard.set(today, forKey: lastActivityDateKey)
        saveStreak()
        
        // Update streak achievements
        AchievementManager.shared.recordStreak(days: currentStreak)
    }
    
    private func checkStreakContinuity() {
        guard let lastActivityDate = UserDefaults.standard.object(forKey: lastActivityDateKey) as? Date else {
            print("📊 No previous activity found")
            return
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let daysSinceLastActivity = Calendar.current.dateComponents([.day], from: lastActivityDate, to: today).day ?? 0
        
        if daysSinceLastActivity > 1 {
            // Streak broken - reset to 0
            print("💔 Streak broken! Days since last activity: \(daysSinceLastActivity)")
            currentStreak = 0
            saveStreak()
        } else {
            print("🔥 Streak maintained! Days since last activity: \(daysSinceLastActivity)")
        }
    }
    
    func getStreakMessage() -> String {
        if currentStreak == 0 {
            return "Start your learning streak today!"
        } else if currentStreak == 1 {
            return "You've practiced 1 day in a row!"
        } else {
            return "You've practiced \(currentStreak) days in a row!"
        }
    }
    
    private func showDayOneStreakMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("dayOneStreakTitle"),
                message: localizationManager.localized("dayOneStreakMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("letsGo"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger immediate haptic feedback
                HapticManager.shared.successNotification()
            }
            
            print("🔥 Day 1 streak message shown!")
        }
    }
    
    private func showDayTwoStreakMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("dayTwoStreakTitle"),
                message: localizationManager.localized("dayTwoStreakMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("inspiring"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            }
            
            print("🌱 Day 2 streak message shown!")
        }
    }
    
    private func showDayThreeStreakMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("dayThreeStreakTitle"),
                message: localizationManager.localized("dayThreeStreakMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("unstoppable"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            }
            
            print("🐐 Day 3 streak message shown!")
        }
    }
    
    private func showDayFiveStreakMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("dayFiveStreakTitle"),
                message: localizationManager.localized("dayFiveStreakMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("powerful"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            }
            
            print("💪 Day 5 streak message shown!")
        }
    }
    
    private func showDaySevenStreakMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("daySevenStreakTitle"),
                message: localizationManager.localized("daySevenStreakMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("brilliant"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            }
            
            print("🔥 Day 7 streak message shown!")
        }
    }
    
    private func showDayFourteenStreakMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("dayFourteenStreakTitle"),
                message: localizationManager.localized("dayFourteenStreakMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("guardian"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            }
            
            print("🏛️ Day 14 streak message shown!")
        }
    }
    
    private func showDayThirtyStreakMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("dayThirtyStreakTitle"),
                message: localizationManager.localized("dayThirtyStreakMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("rhythmic"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            }
            
            print("🥁 Day 30 streak message shown!")
        }
    }
}

// MARK: - Progress Manager
class ProgressManager: ObservableObject {
    static let shared = ProgressManager()
    
    @Published var viewedVocabulary: Set<String> = []
    
    private let progressKey = "ViewedVocabularyItems"
    
    private init() {
        loadProgress()
    }
    
    func markVocabularyAsViewed(categoryId: String, subtopicId: String) {
        let key = "\(categoryId)_\(subtopicId)"
        let wasFirstLesson = viewedVocabulary.isEmpty
        viewedVocabulary.insert(key)
        saveProgress()
        print("📚 Marked as viewed: \(key)")
        
        // Show first lesson motivational message
        if wasFirstLesson {
            showFirstLessonMessage()
        }
        
        // Check for specific subcategory completion (Greetings & Farewells)
        if categoryId == "greetings_essentials" && subtopicId == "greetings_farewells" {
            showGreetingsCompleteMessage()
        }
        
        // Check for specific subcategory completion (Family Relationships)
        if categoryId == "people_relationships" && subtopicId == "family_relationships" {
            showFamilyCompleteMessage()
        }
        
        // Check for specific subcategory completion (Polite Phrases)
        if categoryId == "greetings_essentials" && subtopicId == "polite_phrases" {
            showPolitePhrasesCompleteMessage()
        }
        
        // Check for specific subcategory completion (Basic Questions)
        if categoryId == "greetings_essentials" && subtopicId == "basic_questions" {
            showBasicQuestionsCompleteMessage()
        }
        
        // Check for category completion
        let viewedCount = getViewedCount(for: categoryId)
        let totalCount = getTotalVocabularyCount(for: categoryId)
        if totalCount > 0 && viewedCount == totalCount {
            showCategoryCompleteMessage(categoryId: categoryId)
            AchievementManager.shared.recordCategoryCompletion()
        }
        
        // Update achievements
        AchievementManager.shared.recordLessonCompletion()
        AchievementManager.shared.recordWordsLearned(count: viewedVocabulary.count * 6) // Approximate 6 words per lesson
        
        // Occasionally show cultural message (25% chance)
        if !wasFirstLesson && Int.random(in: 1...4) == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                AchievementManager.shared.showCulturalMessage()
            }
        }
    }
    
    private func showFirstLessonMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("firstLessonTitle"),
                message: localizationManager.localized("firstLessonMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("continue"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger immediate haptic feedback
                HapticManager.shared.successNotification()
            }
        }
    }
    
    private func showGreetingsCompleteMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("greetingsCompleteTitle"),
                message: localizationManager.localized("greetingsCompleteMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("wonderful"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            }
            
            print("👋 Greetings subcategory completed!")
        }
    }
    
    private func showFamilyCompleteMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("familyCompleteTitle"),
                message: localizationManager.localized("familyCompleteMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("beautiful"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            }
            
            print("👨‍👩‍👧‍👦 Family Relationships subcategory completed!")
        }
    }
    
    private func showPolitePhrasesCompleteMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("politeCompleteTitle"),
                message: localizationManager.localized("politeCompleteMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("excellent"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            }
            
            print("🙏 Polite Phrases subcategory completed!")
        }
    }
    
    private func showBasicQuestionsCompleteMessage() {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("questionsCompleteTitle"),
                message: localizationManager.localized("questionsCompleteMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("fantastic"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            }
            
            print("❓ Basic Questions subcategory completed!")
        }
    }
    
    private func showCategoryCompleteMessage(categoryId: String) {
        DispatchQueue.main.async {
            let localizationManager = LocalizationManager.shared
            
            // Create the alert with localized text
            let alert = UIAlertController(
                title: localizationManager.localized("categoryCompleteTitle"),
                message: localizationManager.localized("categoryCompleteMessage"),
                preferredStyle: .alert
            )
            
            // Add an OK button with localized text
            alert.addAction(UIAlertAction(title: localizationManager.localized("amazing"), style: .default) { _ in
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            })
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingVC = rootViewController
                while let presentedVC = presentingVC.presentedViewController {
                    presentingVC = presentedVC
                }
                
                presentingVC.present(alert, animated: true)
                
                // Trigger celebration haptic feedback
                HapticManager.shared.successNotification()
            }
            
            print("🏆 Category completed: \(categoryId)")
        }
    }
    
    func isVocabularyViewed(categoryId: String, subtopicId: String) -> Bool {
        let key = "\(categoryId)_\(subtopicId)"
        return viewedVocabulary.contains(key)
    }
    
    func getViewedCount(for categoryId: String) -> Int {
        return viewedVocabulary.filter { $0.hasPrefix("\(categoryId)_") }.count
    }
    
    func getTotalVocabularyCount(for categoryId: String) -> Int {
        // For now, only Family relationships has vocabulary (1 subtopic)
        // Extend this as more lessons are added
        switch categoryId {
        case "people_relationships":
            return 1 // Family relationships subtopic completion
        case "greetings_essentials":
            return 5 // All 5 subcategories need to be completed
        default:
            return 0
        }
    }
    
    func isQuizUnlocked(for categoryId: String) -> Bool {
        let viewedCount = getViewedCount(for: categoryId)
        let totalCount = getTotalVocabularyCount(for: categoryId)
        return totalCount > 0 && viewedCount >= totalCount
    }
    
    private func saveProgress() {
        let progressArray = Array(viewedVocabulary)
        UserDefaults.standard.set(progressArray, forKey: progressKey)
    }
    
    private func loadProgress() {
        if let saved = UserDefaults.standard.array(forKey: progressKey) as? [String] {
            viewedVocabulary = Set(saved)
            print("📱 Loaded \(viewedVocabulary.count) viewed vocabulary items")
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var reviewManager = ReviewManager.shared
    @StateObject private var progressManager = ProgressManager.shared
    @StateObject private var globalSoundManager = GlobalSoundManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var learningLanguageManager = LearningLanguageManager.shared
    @State private var selectedTab: Int = 2 // Default to Dîlan (center tab)
    @State private var previousTab: Int = 2 // Track previous tab to detect changes
    
    var body: some View {
        ZStack {
        TabView(selection: $selectedTab) {
            // Settings Tab (Position 1 - far left)
            SettingsTabView()
                .environmentObject(authManager)
                .environmentObject(localizationManager)
                .environmentObject(learningLanguageManager)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text(localizationManager.localized("settings"))
                }
                .tag(0)
            
            // Favorites Tab (Position 2)
            FavoritesView()
                .environmentObject(favoritesManager)
                .environmentObject(reviewManager)
                .environmentObject(localizationManager)
                .environmentObject(learningLanguageManager)
                .tabItem {
                    Image(systemName: "star.fill")
                    Text(localizationManager.localized("favorites"))
                }
                .tag(1)
            
            // Journey Tab (Position 3 - center)
            CategorySelectionView()
                .environmentObject(authManager)
                .environmentObject(favoritesManager)
                .environmentObject(progressManager)
                .environmentObject(reviewManager)
                .environmentObject(localizationManager)
                .environmentObject(learningLanguageManager)
                .tabItem {
                    Image(systemName: "map.fill")
                    Text(localizationManager.localized("dilan"))
                }
                .tag(2)
            
            // Leaderboard Tab (Position 4)
            LeaderboardView()
                .environmentObject(localizationManager)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text(localizationManager.localized("leaderboard"))
                }
                .tag(3)
            
            // Profile Tab (Position 5 - far right)
            ProfileView(selectedTab: $selectedTab)
                .environmentObject(authManager)
                    .environmentObject(progressManager)
                .environmentObject(reviewManager)
                .environmentObject(localizationManager)
                .tabItem {
                    Image(systemName: "person.fill")
                    Text(localizationManager.localized("profile"))
                }
                .tag(4)
        }
        .accentColor(.orange) // Orange accent for selected tabs
            .onChange(of: selectedTab) { _, newTab in
                // Only play sound if tab actually changed
                if newTab != previousTab {
                    globalSoundManager.playTabClick()
                    print("Tab changed from \(previousTab) to \(newTab)")
                    previousTab = newTab
                }
            }
            
            // Invisible overlay to detect taps on tab bar area for same-tab taps
            VStack {
                Spacer()
                
                HStack {
                    // Create invisible tap areas for each tab
                    ForEach(0..<5) { tabIndex in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Play sound for same-tab tap (when selectedTab doesn't change)
                                if selectedTab == tabIndex {
                                    globalSoundManager.playTabClick()
                                    print("Same tab tapped: \(tabIndex)")
                                }
                                // Set the tab (this will trigger onChange if different)
                                selectedTab = tabIndex
                            }
                    }
                }
                .frame(height: 50) // Approximate tab bar height
                .padding(.bottom, 34) // Account for safe area
            }
        }
        .onAppear {
            print("TabView appeared with selectedTab: \(selectedTab)")
            previousTab = selectedTab
        }
        // Apply global sound button style to all buttons in the app
        .buttonStyle(SoundButtonStyle(soundType: .normal))
    }
}

// MARK: - Settings Tab View
struct SettingsTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var learningLanguageManager: LearningLanguageManager
    @StateObject private var debugManager = DebugManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text(localizationManager.localized("settings"))
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                        
                        Text(localizationManager.localized("customizeExperience"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Settings Sections
                    VStack(spacing: 16) {
                        // App Preferences Section
                        SettingsSection(title: localizationManager.localized("appPreferences"), icon: "slider.horizontal.3") {
                            VStack(spacing: 12) {
                                // Language Selection
                                SettingsRow(
                                    title: localizationManager.localized("appLanguage"),
                                    subtitle: localizationManager.localized("chooseInterfaceLanguage"),
                                    icon: "globe"
                                ) {
                                    Picker("Language", selection: $localizationManager.currentLanguage) {
                                        ForEach(LocalizationManager.AppLanguage.allCases, id: \.self) { language in
                                            Text(language.displayName).tag(language)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .frame(width: 140)
                                }
                                
                                Divider()
                                    .padding(.horizontal, 16)
                                
                                SettingsRow(
                                    title: localizationManager.localized("clickSound"),
                                    subtitle: localizationManager.localized("enableSoundsInteractions"),
                                    icon: "speaker.wave.2.fill"
                                ) {
                                    Toggle("", isOn: $settingsManager.clickSoundEnabled)
                                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                                }
                                
                                Divider()
                                    .padding(.horizontal, 16)
                                
                                SettingsRow(
                                    title: localizationManager.localized("autoPlayWordAudio"),
                                    subtitle: localizationManager.localized("autoPlayKurdishWords"),
                                    icon: "play.circle.fill"
                                ) {
                                    Toggle("", isOn: $settingsManager.autoPlayWordAudio)
                                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                                }
                                
                                Divider()
                                    .padding(.horizontal, 16)
                                
                                SettingsRow(
                                    title: localizationManager.localized("useNativeKurdishAudio"),
                                    subtitle: localizationManager.localized("useCustomRecordings"),
                                    icon: "waveform.and.mic"
                                ) {
                                    Toggle("", isOn: $settingsManager.useNativeKurdishAudio)
                                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                                }
                            }
                        }
                        
                        // Learning Preferences Section
                        SettingsSection(title: localizationManager.localized("learningPreferences"), icon: "book.fill") {
                            VStack(spacing: 12) {
                                // Learning Language Selection
                                SettingsRow(
                                    title: localizationManager.localized("learningLanguage"),
                                    subtitle: localizationManager.localized("chooseLearningLanguage"),
                                    icon: "globe.badge.chevron.backward"
                                ) {
                                    Picker("Learning Language", selection: $learningLanguageManager.currentLearningLanguage) {
                                        ForEach(LearningLanguageManager.LearningLanguage.allCases, id: \.self) { language in
                                            Text(language.displayName).tag(language)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .frame(width: 140)
                                }
                            }
                        }
                        
                        // Debug Settings Section
                        SettingsSection(title: localizationManager.localized("developerOptions"), icon: "ladybug.fill") {
                            VStack(spacing: 12) {
                                SettingsRow(
                                    title: localizationManager.localized("skipAuthentication"),
                                    subtitle: localizationManager.localized("bypassLoginTesting"),
                                    icon: "bolt.fill"
                                ) {
                                    Toggle("", isOn: $debugManager.skipAuthentication)
                                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                                }
                                
                                Divider()
                                    .padding(.horizontal, 16)
                                
                                SettingsRow(
                                    title: localizationManager.localized("resetDebugSettings"),
                                    subtitle: localizationManager.localized("clearDebugPreferences"),
                                    icon: "arrow.clockwise"
                                ) {
                                    Button(localizationManager.localized("reset")) {
                                        debugManager.resetDebugSettings()
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.orange)
                                }
                            }
                        }
                        
                        // Account Section
                        SettingsSection(title: localizationManager.localized("accountActions"), icon: "person.crop.circle") {
                            VStack(spacing: 12) {
                                SettingsRow(
                                    title: localizationManager.localized("signOut"),
                                    subtitle: localizationManager.localized("logOutAccount"),
                                    icon: "rectangle.portrait.and.arrow.right"
                                ) {
                                    Button(localizationManager.localized("signOut")) {
                                        authManager.signOut()
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.red)
                                }
                            }
                        }
                        
                        // App Info Section
                        SettingsSection(title: "About", icon: "info.circle") {
                            VStack(spacing: 12) {
                                SettingsRow(
                                    title: "Version",
                                    subtitle: "1.0.0 (Beta)",
                                    icon: "app.badge"
                                ) {
                                    Text("Beta")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.orange.opacity(0.1))
                                        )
                                }
                                
                                Divider()
                                    .padding(.horizontal, 16)
                                
                                SettingsRow(
                                    title: "Privacy Policy",
                                    subtitle: "Learn about your data",
                                    icon: "hand.raised.fill"
                                ) {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Bottom spacing
                    Color.clear.frame(height: 40)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color.orange.opacity(0.02)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Settings Section Component
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Section Header
            HStack {
                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.orange)
                
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Section Content
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - Settings Row Component
struct SettingsRow<Accessory: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let accessory: Accessory
    
    init(title: String, subtitle: String, icon: String, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accessory = accessory()
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 24, height: 24)
            
            // Title and Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Accessory View
            accessory
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Favorites View
struct FavoritesView: View {
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var reviewManager: ReviewManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var learningLanguageManager: LearningLanguageManager
    @State private var selectedSection: FavoriteSection = .favorites
    
    enum FavoriteSection: CaseIterable {
        case favorites, toReview
        
        func title(using localizationManager: LocalizationManager) -> String {
            switch self {
            case .favorites: return localizationManager.localized("favorites")
            case .toReview: return localizationManager.localized("toReview")
            }
        }
        
        var icon: String {
            switch self {
            case .favorites: return "star.fill"
            case .toReview: return "wrench.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 8) {
                        Image(systemName: selectedSection.icon)
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text(selectedSection.title(using: localizationManager))
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                        
                        Text(selectedSection == .favorites ? 
                             localizationManager.localized("yourFavoriteWords") : 
                             localizationManager.localized("wordsToReview"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Segmented Control
                    Picker("Section", selection: $selectedSection) {
                        ForEach(FavoriteSection.allCases, id: \.self) { section in
                            Text(section.title(using: localizationManager)).tag(section)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 20)
                    
                    // Content based on selected section
                    Group {
                        if selectedSection == .favorites {
                            favoritesContent
                        } else {
                            toReviewContent
                        }
                    }
                    
                    // Bottom spacing
                    Color.clear.frame(height: 40)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color.orange.opacity(0.02)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle(selectedSection.title(using: localizationManager))
            .navigationBarTitleDisplayMode(.large)
            .navigationBarHidden(true)
        }
        .onReceive(reviewManager.$shouldNavigateToReview) { shouldNavigate in
            if shouldNavigate {
                selectedSection = .toReview
                reviewManager.shouldNavigateToReview = false
            }
        }
    }
    
    // MARK: - Favorites Content
    private var favoritesContent: some View {
        Group {
                    if favoritesManager.favoriteWords.isEmpty {
                // Empty state for favorites
                        VStack(spacing: 16) {
                            Image(systemName: "heart.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.6))
                            
                    Text(localizationManager.localized("noFavoritesYet"))
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                    Text(localizationManager.localized("tapHeartIcon"))
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 60)
                    } else {
                        // Favorites list
                        LazyVStack(spacing: 16) {
                            ForEach(favoritesManager.favoriteWords) { favoriteWord in
                                FavoriteWordCard(
                                    favoriteWord: favoriteWord,
                                    onRemove: {
                                        favoritesManager.removeFromFavorites(
                                            kurdish: favoriteWord.kurdish,
                                            category: favoriteWord.category
                                        )
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
        }
    }
    
    // MARK: - To Review Content
    private var toReviewContent: some View {
        Group {
            if reviewManager.reviewWords.isEmpty {
                // Empty state for to review
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.6))
                    
                    Text(localizationManager.localized("noWordsToReview"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(localizationManager.localized("takeQuizzesIdentify"))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
            }
                .padding(.top, 60)
            } else {
                // Section header
                VStack(spacing: 8) {
                    HStack {
                        Text("🛠️ " + localizationManager.localized("toReview"))
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(reviewManager.reviewWords.count) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)
                    
                    Text(localizationManager.localized("wordsAnsweredIncorrectly"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                }
                
                // Review words list
                LazyVStack(spacing: 16) {
                    ForEach(reviewManager.reviewWords) { reviewWord in
                        ReviewWordCard(
                            reviewWord: reviewWord,
                            onMarkAsReviewed: {
                                reviewManager.markAsReviewed(
                                    kurdish: reviewWord.kurdish,
                                    category: reviewWord.category
                                )
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Favorite Word Card Component
struct FavoriteWordCard: View {
    let favoriteWord: FavoriteWord
    let onRemove: () -> Void
    @State private var showExample = false
    @EnvironmentObject var learningLanguageManager: LearningLanguageManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showExample.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    // Word image
                    Image(favoriteWord.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Word details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(favoriteWord.kurdish)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.orange)
                        
                        Text(favoriteWord.translation(for: learningLanguageManager.currentLearningLanguage))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text(favoriteWord.subcategory)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Actions
                    VStack(spacing: 8) {
                        // Remove button
                        Button(action: onRemove) {
                            Image(systemName: "heart.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                        }
                        .soundButtonStyle(.normal)
                        
                        // Expand indicator
                        Image(systemName: showExample ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .soundButtonStyle(.normal)
            
            // Example section (expandable)
            if showExample {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 8) {
                        Text(favoriteWord.kurdishExample)
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text(favoriteWord.example(for: learningLanguageManager.currentLearningLanguage))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Review Word Card Component
struct ReviewWordCard: View {
    let reviewWord: ReviewWord
    let onMarkAsReviewed: () -> Void
    @State private var showExample = false
    @EnvironmentObject var learningLanguageManager: LearningLanguageManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showExample.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    // Word image
                    Image(reviewWord.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Word details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reviewWord.kurdish)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.orange)
                        
                        Text(reviewWord.translation(for: learningLanguageManager.currentLearningLanguage))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Text(reviewWord.subcategory)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            // Mistake count indicator
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                
                                Text("×\(reviewWord.mistakeCount)")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    
                    Spacer()
                    
                    // Actions
                    VStack(spacing: 8) {
                        // Mark as reviewed button
                        Button(action: onMarkAsReviewed) {
                            Image(systemName: "checkmark.circle")
                                .font(.title3)
                                .foregroundColor(.green)
                        }
                        .soundButtonStyle(.normal)
                        
                        // Expand indicator
                        Image(systemName: showExample ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .soundButtonStyle(.normal)
            
            // Example section (expandable)
            if showExample {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 8) {
                        Text(reviewWord.kurdishExample)
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text(reviewWord.example(for: learningLanguageManager.currentLearningLanguage))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var progressManager: ProgressManager
    @EnvironmentObject var reviewManager: ReviewManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @Binding var selectedTab: Int
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Profile Header Section
                    ProfileHeaderView(authManager: authManager, showingEditProfile: $showingEditProfile)
                        .environmentObject(localizationManager)
                    
                    // Learning Progress Section
                    LearningProgressView(
                        progressManager: progressManager,
                        reviewManager: reviewManager,
                        selectedTab: $selectedTab
                    )
                    .environmentObject(localizationManager)
                    
                    // User Info Section
                    if let user = authManager.user {
                        VStack(spacing: 16) {
                            SettingsSection(title: localizationManager.localized("accountInformation"), icon: "person.crop.circle") {
                                VStack(spacing: 12) {
                                    if let email = user.email {
                                        SettingsRow(
                                            title: localizationManager.localized("email"),
                                            subtitle: email,
                                            icon: "envelope.fill"
                                        ) {
                                            EmptyView()
                                        }
                                    }
                                    
                                    if let displayName = user.displayName, !displayName.isEmpty {
                                        Divider()
                                            .padding(.horizontal, 16)
                                        
                                        SettingsRow(
                                            title: localizationManager.localized("displayName"),
                                            subtitle: displayName,
                                            icon: "person.text.rectangle"
                                        ) {
                                            EmptyView()
                                        }
                                    }
                                    
                                    Divider()
                                        .padding(.horizontal, 16)
                                    
                                    SettingsRow(
                                        title: localizationManager.localized("userID"),
                                        subtitle: String(user.uid.prefix(8)) + "...",
                                        icon: "number"
                                    ) {
                                        EmptyView()
                                    }
                                }
                            }
                        }
                    }
                    
                    // Account Actions Section
                    VStack(spacing: 16) {
                        SettingsSection(title: localizationManager.localized("accountActions"), icon: "gear") {
                            VStack(spacing: 12) {
                                SettingsRow(
                                    title: localizationManager.localized("signOut"),
                                    subtitle: localizationManager.localized("logOutAccount"),
                                    icon: "rectangle.portrait.and.arrow.right"
                                ) {
                                    Button(localizationManager.localized("signOut")) {
                                        authManager.signOut()
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Bottom spacing
                    Color.clear.frame(height: 40)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color.orange.opacity(0.02)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle(localizationManager.localized("profile"))
            .navigationBarTitleDisplayMode(.large)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    LanguageToggleButton()
                        .environmentObject(localizationManager)
                }
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView(authManager: authManager)
        }
    }
}

// MARK: - Profile Header Component
struct ProfileHeaderView: View {
    let authManager: AuthenticationManager
    @Binding var showingEditProfile: Bool
    @EnvironmentObject var localizationManager: LocalizationManager
    
    private var displayName: String {
        if let user = authManager.user {
            if let name = user.displayName, !name.isEmpty {
                return name
            } else if let email = user.email {
                // Extract name part from email
                return String(email.split(separator: "@").first ?? "User")
            }
        }
        return "Bano" // Default placeholder
    }
    
    private var userInitials: String {
        let name = displayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let firstInitial = String(components[0].prefix(1)).uppercased()
            let lastInitial = String(components[1].prefix(1)).uppercased()
            return firstInitial + lastInitial
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Avatar
            ZStack {
                // Background card
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .frame(width: 140, height: 140)
                
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.orange.opacity(0.8), .orange]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    // User initials
                    Text(userInitials)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            
            // Welcome message and name
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    VStack(spacing: 4) {
                        Text(localizationManager.localized("welcome"))
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Text(displayName)
                            .font(.title.bold())
                            .foregroundColor(.primary)
                    }
                    
                    // Edit button
                    Button(action: {
                        showingEditProfile = true
                        // Play button click sound
                        GlobalSoundManager.shared.playButtonClick()
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 32, height: 32)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Subtitle
                Text(localizationManager.localized("kurdishLanguageLearner"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .opacity(0.8)
            }
        }
        .padding(.top, 30)
        .padding(.horizontal, 20)
    }
}

// MARK: - Learning Progress Component
struct LearningProgressView: View {
    let progressManager: ProgressManager
    let reviewManager: ReviewManager
    @Binding var selectedTab: Int
    @StateObject private var streakManager = StreakManager.shared
    @EnvironmentObject var localizationManager: LocalizationManager
    
    // Calculate total categories and subcategories
    private let totalCategories = 13
    private let totalSubcategories = 78 // 13 categories × 6 subcategories each
    
    private var vocabularyLearned: Int {
        return progressManager.viewedVocabulary.count
    }
    
    private var subcategoriesCompleted: Int {
        // Count how many subcategories have been viewed
        return progressManager.viewedVocabulary.count
    }
    
    private var quizAccuracy: Double {
        // Placeholder calculation - can be improved when quiz system is enhanced
        // For now, base it on completion percentage
        let completionRate = Double(subcategoriesCompleted) / Double(totalSubcategories)
        return min(100.0, max(0.0, completionRate * 100.0 + Double.random(in: 10...30)))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Section Title
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text(localizationManager.localized("learningProgress"))
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Progress Cards
            VStack(spacing: 12) {
                // Top row - Vocabulary and Subcategories
                HStack(spacing: 12) {
                    // Vocabulary Learned Card
                    ProgressCard(
                        icon: "book.fill",
                        title: localizationManager.localized("wordsLearned"),
                        value: "\(vocabularyLearned)",
                        total: "150", // Placeholder total
                        color: .blue,
                        progress: Double(vocabularyLearned) / 150.0
                    )
                    
                    // Subcategories Completed Card
                    ProgressCard(
                        icon: "list.bullet.rectangle",
                        title: localizationManager.localized("lessonsCompleted"),
                        value: "\(subcategoriesCompleted)",
                        total: "\(totalSubcategories)",
                        color: .green,
                        progress: Double(subcategoriesCompleted) / Double(totalSubcategories)
                    )
                }
                
                // Bottom row - Quiz Performance (full width)
                ProgressCard(
                    icon: "target",
                    title: localizationManager.localized("quizAccuracy"),
                    value: String(format: "%.0f%%", quizAccuracy),
                    total: nil,
                    color: .purple,
                    progress: quizAccuracy / 100.0,
                    isFullWidth: true
                )
            }
            .padding(.horizontal, 20)
            
            // Quick Actions
            VStack(spacing: 12) {
                HStack {
                    Text(localizationManager.localized("quickActions"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                VStack(spacing: 8) {
                    // View all achievements link
                    Button(action: {
                        selectedTab = 3 // Leaderboard tab
                        HapticManager.shared.lightImpact()
                    }) {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .frame(width: 16)
                            
                            Text(localizationManager.localized("viewAllAchievements"))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )
                    }
                    .soundButtonStyle(.normal)
                    
                    // Review difficult words link
                    Button(action: {
                        reviewManager.navigateToReviewSection()
                        selectedTab = 1 // Favorites tab
                        HapticManager.shared.lightImpact()
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(width: 16)
                            
                            Text(localizationManager.localized("reviewDifficultWords"))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Show count of words to review
                            if reviewManager.reviewWords.count > 0 {
                                Text("\(reviewManager.reviewWords.count)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.red)
                                    )
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )
                    }
                    .soundButtonStyle(.normal)
                }
                .padding(.horizontal, 20)
            }
            
            // Learning Activity Information
            VStack(spacing: 12) {
                HStack {
                    Text(localizationManager.localized("learningActivity"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                VStack(spacing: 8) {
                    // Time spent learning
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(width: 16)
                        
                        Text(localizationManager.localized("timeSpentLearning"))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(streakManager.getFormattedLearningTime())
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
                    
                    // Last activity
                    HStack {
                        Image(systemName: "calendar.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .frame(width: 16)
                        
                        Text(localizationManager.localized("lastActive"))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(streakManager.getLastActivityString())
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Progress Card Component
struct ProgressCard: View {
    let icon: String
    let title: String
    let value: String
    let total: String?
    let color: Color
    let progress: Double
    let isFullWidth: Bool
    
    init(icon: String, title: String, value: String, total: String?, color: Color, progress: Double, isFullWidth: Bool = false) {
        self.icon = icon
        self.title = title
        self.value = value
        self.total = total
        self.color = color
        self.progress = progress
        self.isFullWidth = isFullWidth
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Card Background
            VStack(spacing: 16) {
                // Header with icon and title
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                        .frame(width: 24, height: 24)
                    
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                
                // Progress Section
                VStack(spacing: 8) {
                    // Value and total
                    HStack {
                        if let total = total {
                            Text("\(value) / \(total)")
                                .font(.title2.bold())
                                .foregroundColor(.primary)
                        } else {
                            Text(value)
                                .font(.title2.bold())
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        // Percentage badge
                        Text("\(Int(progress * 100))%")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(color.opacity(0.8))
                            )
                    }
                    
                    // Progress bar
                    ProgressBar(progress: progress, color: color)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
        }
        .frame(maxWidth: isFullWidth ? .infinity : nil)
    }
}

// MARK: - Progress Bar Component
struct ProgressBar: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.2))
                    .frame(height: 8)
                
                // Progress fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.8), color]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * max(0, min(1, progress)), height: 8)
                    .animation(.easeInOut(duration: 0.5), value: progress)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Edit Profile Sheet (Placeholder)
struct EditProfileView: View {
    let authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Edit Profile")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text("Update your profile information")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Form
            VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Name")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        
                        TextField("Enter your name", text: $displayName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                    }
                    
                    // Coming soon notice
                    VStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.title3)
                            .foregroundColor(.orange.opacity(0.7))
                        
                        Text("Profile editing coming soon!")
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                        
                        Text("This feature will be available in a future update.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.orange.opacity(0.1))
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                    GlobalSoundManager.shared.playButtonClick()
                }
                .foregroundColor(.orange),
                trailing: Button("Save") {
                    // Future: Save profile changes
                    dismiss()
                    GlobalSoundManager.shared.playActionSound()
                }
                .foregroundColor(.orange)
                .disabled(true) // Disabled for now
                .opacity(0.5)
            )
        }
        .onAppear {
            if let user = authManager.user, let name = user.displayName {
                displayName = name
            }
        }
    }
}

// MARK: - Animated Flame Component
struct AnimatedFlame: View {
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    let streakCount: Int
    
    var body: some View {
        ZStack {
            // Glow effect
            Image(systemName: "flame.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange.opacity(0.3))
                .scaleEffect(1.8)
                .blur(radius: 8)
                .opacity(isAnimating ? 0.8 : 0.4)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            
            // Main flame
            Image(systemName: "flame.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
                .scaleEffect(pulseScale)
                .rotation3DEffect(.degrees(isAnimating ? 5 : -5), axis: (x: 0, y: 0, z: 1))
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            
            // Inner flame highlight
            Image(systemName: "flame.fill")
                .font(.system(size: 30))
                .foregroundColor(.yellow)
                .offset(y: -5)
                .opacity(0.8)
                .scaleEffect(pulseScale * 0.7)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isAnimating)
        }
        .onAppear {
            isAnimating = true
            
            // Pulsing animation
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseScale = streakCount > 0 ? 1.1 : 0.9
            }
        }
    }
}

// MARK: - Achievement Badge Component
struct AchievementBadge: View {
    let achievement: Achievement
    @State private var isAnimating = false
    @State private var showUnlockAnimation = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Badge Icon
            ZStack {
                // Background circle
                Circle()
                    .fill(achievement.isUnlocked ? achievement.category.color.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 70, height: 70)
                
                // Unlock glow effect
                if achievement.isUnlocked && showUnlockAnimation {
                    Circle()
                        .stroke(achievement.category.color, lineWidth: 3)
                        .frame(width: 75, height: 75)
                        .scaleEffect(isAnimating ? 1.3 : 1.0)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(.easeOut(duration: 1.0).repeatCount(3, autoreverses: false), value: isAnimating)
                }
                
                // Icon
                Image(systemName: achievement.iconName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(achievement.isUnlocked ? achievement.category.color : Color.gray.opacity(0.5))
                    .scaleEffect(showUnlockAnimation ? (isAnimating ? 1.2 : 1.0) : 1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isAnimating)
            }
            
            // Badge Info
            VStack(spacing: 4) {
                Text(achievement.title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(achievement.subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            // Progress bar for in-progress achievements
            if achievement.isInProgress {
                VStack(spacing: 4) {
                    ProgressView(value: achievement.progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: achievement.category.color))
                        .frame(height: 4)
                    
                    Text("\(achievement.currentProgress)/\(achievement.requirement)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 100, height: 140)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(achievement.isUnlocked ? achievement.category.color.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(showUnlockAnimation ? (isAnimating ? 1.05 : 1.0) : 1.0)
        .onAppear {
            // Trigger unlock animation if recently unlocked
            if achievement.isUnlocked,
               let unlockedDate = achievement.unlockedDate,
               Date().timeIntervalSince(unlockedDate) < 5.0 { // Within 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    triggerUnlockAnimation()
                }
            }
        }
    }
    
    private func triggerUnlockAnimation() {
        showUnlockAnimation = true
        withAnimation {
            isAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                isAnimating = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showUnlockAnimation = false
        }
    }
}

// MARK: - Achievements Section Component
struct AchievementsSection: View {
    @StateObject private var achievementManager = AchievementManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Section Title
            HStack {
                Image(systemName: "trophy.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Achievements")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Achievement count
                Text("\(achievementManager.unlockedCount)/\(achievementManager.totalCount)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.1))
                    )
            }
            .padding(.horizontal, 20)
            
            // Achievement Grid
            VStack(spacing: 16) {
                // Group achievements by category
                ForEach(Achievement.AchievementCategory.allCases, id: \.self) { category in
                    let categoryAchievements = achievementManager.achievements.filter { $0.category == category }
                    
                    if !categoryAchievements.isEmpty {
                        VStack(spacing: 12) {
                            // Category Header
                            HStack {
                                Text(category.rawValue)
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(category.color)
                                
                                Spacer()
                                
                                let unlockedInCategory = categoryAchievements.filter { $0.isUnlocked }.count
                                Text("\(unlockedInCategory)/\(categoryAchievements.count)")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            
                            // Achievement Badges
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(categoryAchievements) { achievement in
                                        AchievementBadge(achievement: achievement)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.orange.opacity(0.3), .orange.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Daily Streak Section Component
struct DailyStreakSection: View {
    @StateObject private var streakManager = StreakManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Section Title
            HStack {
                Image(systemName: "flame.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("Daily Streak")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Streak Display Card
            VStack(spacing: 16) {
                // Animated Flame
                AnimatedFlame(streakCount: streakManager.currentStreak)
                
                // Streak Count
                VStack(spacing: 8) {
                    Text("\(streakManager.currentStreak)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    
                    Text(streakManager.getStreakMessage())
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                // Longest Streak Badge
                if streakManager.longestStreak > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        
                        Text("Best: \(streakManager.longestStreak) days")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.yellow.opacity(0.1))
                    )
                }
                
                // Motivation Message
                VStack(spacing: 4) {
                    if streakManager.currentStreak == 0 {
                        Text("Complete a lesson to start your streak!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if streakManager.currentStreak < 7 {
                        Text("Keep going! Consistency builds fluency.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if streakManager.currentStreak < 30 {
                        Text("Amazing! You're building a great habit!")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    } else {
                        Text("Incredible dedication! You're a Kurdish champion!")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.orange.opacity(0.3), .orange.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Leaderboard View
struct LeaderboardView: View {
    @StateObject private var streakManager = StreakManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 16) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                        Text("Progress & Rankings")
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)
                
                        Text("Track your learning journey and compete with other Kurdish learners")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    }
                    .padding(.top, 20)
                    
                    // Daily Streak Section
                    DailyStreakSection()
                    
                    // Achievements Section
                    AchievementsSection()
                    
                    // Coming Soon Section
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "trophy.circle.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                            
                            Text("Global Rankings")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.primary)
                
                Spacer()
            }
                        .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange.opacity(0.6))
                            
                            Text("Coming Soon")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            Text("Global leaderboards and achievements will be available in a future update")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 30)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Bottom spacing
                    Color.clear.frame(height: 40)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color.orange.opacity(0.02)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Subtopic Data Model
struct LearningSubtopic: Identifiable {
    let id: String
    let englishTitle: String
    let kurdishTitle: String
    
    init(id: String, englishTitle: String, kurdishTitle: String) {
        self.id = id
        self.englishTitle = englishTitle
        self.kurdishTitle = kurdishTitle
    }
}

// MARK: - Data Models
struct LearningCategory: Identifiable {
    let id: String
    let englishTitle: String
    let kurdishTitle: String
    let emoji: String
    let subtopics: [LearningSubtopic]
}

// MARK: - Category Configuration
struct CategoryConfiguration {
    let iconName: String
    let backgroundColor: Color
    
    static let configurations: [String: CategoryConfiguration] = [
        "greetings_essentials": CategoryConfiguration(iconName: "hand.wave.fill", backgroundColor: .blue),
        "people_relationships": CategoryConfiguration(iconName: "person.2.fill", backgroundColor: .orange),
        "health_body": CategoryConfiguration(iconName: "heart.fill", backgroundColor: .red),
        "clothing_accessories": CategoryConfiguration(iconName: "tshirt.fill", backgroundColor: .purple),
        "home_living": CategoryConfiguration(iconName: "house.fill", backgroundColor: .blue),
        "food_cooking": CategoryConfiguration(iconName: "fork.knife", backgroundColor: .green),
        "in_city": CategoryConfiguration(iconName: "building.2.fill", backgroundColor: .cyan),
        "transport": CategoryConfiguration(iconName: "car.fill", backgroundColor: .indigo),
        "school_work": CategoryConfiguration(iconName: "graduationcap.fill", backgroundColor: .teal),
        "communication": CategoryConfiguration(iconName: "antenna.radiowaves.left.and.right", backgroundColor: .mint),
        "free_time_sports": CategoryConfiguration(iconName: "sportscourt.fill", backgroundColor: .yellow),
        "world_nature": CategoryConfiguration(iconName: "globe.americas.fill", backgroundColor: .brown),
        "numbers_measures": CategoryConfiguration(iconName: "number", backgroundColor: .gray)
    ]
    
    static func configuration(for categoryId: String) -> CategoryConfiguration {
        return configurations[categoryId] ?? CategoryConfiguration(iconName: "questionmark", backgroundColor: .gray)
    }
}

// MARK: - Category Selection View
struct CategorySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var progressManager: ProgressManager
    @EnvironmentObject var reviewManager: ReviewManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject var learningLanguageManager: LearningLanguageManager
    @State private var selectedCategory: LearningCategory?
    // Remove the unlocked categories restriction - make all available
    // @State private var unlockedCategories: Set<String> = ["people_relationships"] // First category unlocked by default
    
    private let categories = [
        LearningCategory(
            id: "greetings_essentials",
            englishTitle: "Greetings & Essentials",
            kurdishTitle: "Silav û bingehîn",
            emoji: "👋",
            subtopics: [
                LearningSubtopic(id: "greetings_farewells", englishTitle: "Greetings & Farewells", kurdishTitle: "Silav û bi xatirê te"),
                LearningSubtopic(id: "polite_phrases", englishTitle: "Polite Phrases", kurdishTitle: "Gotinên edebî"),
                LearningSubtopic(id: "introductions", englishTitle: "Introductions", kurdishTitle: "Nasnamekirin"),
                LearningSubtopic(id: "basic_questions", englishTitle: "Basic Questions", kurdishTitle: "Pirsên bingehîn"),
                LearningSubtopic(id: "yes_no_confirmation", englishTitle: "Yes / No & Confirmation", kurdishTitle: "Erê / Na û piştrastkirin")
            ]
        ),
        LearningCategory(
            id: "people_relationships",
            englishTitle: "People & Relationships",
            kurdishTitle: "Meriv û têkilî",
            emoji: "👨‍👩‍👧‍👦",
            subtopics: [
                LearningSubtopic(id: "family_relationships", englishTitle: "Family relationships", kurdishTitle: "Têkiliyên merivayi /eqrebati"),
                LearningSubtopic(id: "personal_info_age", englishTitle: "Personal info & age stages", kurdishTitle: "Agahiyên nasnameyê û gihînekên temenan"),
                LearningSubtopic(id: "relationships", englishTitle: "Relationships", kurdishTitle: "Têkili"),
                LearningSubtopic(id: "events_celebrations", englishTitle: "Events and celebrations", kurdishTitle: "Bûyer û sahîr"),
                LearningSubtopic(id: "emotions_personality", englishTitle: "Emotions and personality", kurdishTitle: "Hest û kesayeti"),
                LearningSubtopic(id: "physical_appearance", englishTitle: "Physical appearance", kurdishTitle: "Xuyang")
            ]
        ),
        LearningCategory(
            id: "health_body",
            englishTitle: "Health & Body",
            kurdishTitle: "Beden û tenduristî",
            emoji: "🧠",
            subtopics: [
                LearningSubtopic(id: "body_parts", englishTitle: "Body Parts", kurdishTitle: "Endamên bedenî"),
                LearningSubtopic(id: "health_problems", englishTitle: "Health Problems", kurdishTitle: "Pirsgirêkên tenduristiyê"),
                LearningSubtopic(id: "at_doctor", englishTitle: "At the Doctor", kurdishTitle: "Li cem bijîşk"),
                LearningSubtopic(id: "medicine", englishTitle: "Medicine", kurdishTitle: "Derman"),
                LearningSubtopic(id: "exercise", englishTitle: "Exercise", kurdishTitle: "Werzîş"),
                LearningSubtopic(id: "mental_health", englishTitle: "Mental Health", kurdishTitle: "Tenduristiya derûnî")
            ]
        ),
        LearningCategory(
            id: "clothing_accessories",
            englishTitle: "Clothing & Accessories",
            kurdishTitle: "Kinc û aksesûwar",
            emoji: "👕",
            subtopics: [
                LearningSubtopic(id: "clothing_items", englishTitle: "Clothing Items", kurdishTitle: "Cûreyên kincê"),
                LearningSubtopic(id: "colors", englishTitle: "Colors", kurdishTitle: "Reng"),
                LearningSubtopic(id: "sizes", englishTitle: "Sizes", kurdishTitle: "Mezinahî"),
                LearningSubtopic(id: "shopping", englishTitle: "Shopping", kurdishTitle: "Firotandin"),
                LearningSubtopic(id: "jewelry", englishTitle: "Jewelry", kurdishTitle: "Zêrîn"),
                LearningSubtopic(id: "shoes", englishTitle: "Shoes", kurdishTitle: "Pêlav")
            ]
        ),
        LearningCategory(
            id: "home_living",
            englishTitle: "Home & Living",
            kurdishTitle: "Xanî / Mal",
            emoji: "🏠",
            subtopics: [
                LearningSubtopic(id: "rooms", englishTitle: "Rooms", kurdishTitle: "Oda"),
                LearningSubtopic(id: "furniture", englishTitle: "Furniture", kurdishTitle: "Mobîlya"),
                LearningSubtopic(id: "household_items", englishTitle: "Household Items", kurdishTitle: "Tiştên malê"),
                LearningSubtopic(id: "cleaning", englishTitle: "Cleaning", kurdishTitle: "Paqijkirin"),
                LearningSubtopic(id: "cooking_utensils", englishTitle: "Cooking Utensils", kurdishTitle: "Amûrên pijandinê"),
                LearningSubtopic(id: "garden", englishTitle: "Garden", kurdishTitle: "Bax")
            ]
        ),
        LearningCategory(
            id: "food_cooking",
            englishTitle: "Food & Cooking",
            kurdishTitle: "Xwarin û pijandin",
            emoji: "🍎",
            subtopics: [
                LearningSubtopic(id: "fruits", englishTitle: "Fruits", kurdishTitle: "Fêkî"),
                LearningSubtopic(id: "vegetables", englishTitle: "Vegetables", kurdishTitle: "Sebze"),
                LearningSubtopic(id: "meat_fish", englishTitle: "Meat & Fish", kurdishTitle: "Goşt û masî"),
                LearningSubtopic(id: "drinks", englishTitle: "Drinks", kurdishTitle: "Vexwarin"),
                LearningSubtopic(id: "cooking_methods", englishTitle: "Cooking Methods", kurdishTitle: "Rêbazên pijandinê"),
                LearningSubtopic(id: "recipes", englishTitle: "Recipes", kurdishTitle: "Rêçete")
            ]
        ),
        LearningCategory(
            id: "in_city",
            englishTitle: "In the City",
            kurdishTitle: "Li bajar",
            emoji: "🏙️",
            subtopics: [
                LearningSubtopic(id: "buildings", englishTitle: "Buildings", kurdishTitle: "Avahî"),
                LearningSubtopic(id: "shops", englishTitle: "Shops", kurdishTitle: "Dikan"),
                LearningSubtopic(id: "directions", englishTitle: "Directions", kurdishTitle: "Asta"),
                LearningSubtopic(id: "public_places", englishTitle: "Public Places", kurdishTitle: "Cihên gelemperî"),
                LearningSubtopic(id: "services", englishTitle: "Services", kurdishTitle: "Xizmet"),
                LearningSubtopic(id: "street_life", englishTitle: "Street Life", kurdishTitle: "Jiyana kuçê")
            ]
        ),
        LearningCategory(
            id: "transport",
            englishTitle: "Transport",
            kurdishTitle: "Hatûçû / Trafîk",
            emoji: "🚗",
            subtopics: [
                LearningSubtopic(id: "vehicles", englishTitle: "Vehicles", kurdishTitle: "Otomobîl"),
                LearningSubtopic(id: "public_transport", englishTitle: "Public Transport", kurdishTitle: "Hatûçûya gelemperî"),
                LearningSubtopic(id: "traffic", englishTitle: "Traffic", kurdishTitle: "Trafîk"),
                LearningSubtopic(id: "travel", englishTitle: "Travel", kurdishTitle: "Rêwîtî"),
                LearningSubtopic(id: "directions_transport", englishTitle: "Directions", kurdishTitle: "Asta"),
                LearningSubtopic(id: "road_signs", englishTitle: "Road Signs", kurdishTitle: "Nîşaneyên rê")
            ]
        ),
        LearningCategory(
            id: "school_work",
            englishTitle: "School & Work",
            kurdishTitle: "Xwendegeh û kar",
            emoji: "🏫",
            subtopics: [
                LearningSubtopic(id: "school_subjects", englishTitle: "School Subjects", kurdishTitle: "Dersên dibistanê"),
                LearningSubtopic(id: "office_items", englishTitle: "Office Items", kurdishTitle: "Tiştên ofîsê"),
                LearningSubtopic(id: "professions", englishTitle: "Professions", kurdishTitle: "Pîşe"),
                LearningSubtopic(id: "education", englishTitle: "Education", kurdishTitle: "Perwerde"),
                LearningSubtopic(id: "business", englishTitle: "Business", kurdishTitle: "Karsazî"),
                LearningSubtopic(id: "study_tools", englishTitle: "Study Tools", kurdishTitle: "Amûrên xwendinê")
            ]
        ),
        LearningCategory(
            id: "communication",
            englishTitle: "Communication",
            kurdishTitle: "Ragihandin",
            emoji: "📡",
            subtopics: [
                LearningSubtopic(id: "technology", englishTitle: "Technology", kurdishTitle: "Teknolojî"),
                LearningSubtopic(id: "phone_calls", englishTitle: "Phone Calls", kurdishTitle: "Bangên telefônê"),
                LearningSubtopic(id: "internet", englishTitle: "Internet", kurdishTitle: "Înternet"),
                LearningSubtopic(id: "social_media", englishTitle: "Social Media", kurdishTitle: "Medyaya civakî"),
                LearningSubtopic(id: "letters", englishTitle: "Letters", kurdishTitle: "Name"),
                LearningSubtopic(id: "news", englishTitle: "News", kurdishTitle: "Nûçe")
            ]
        ),
        LearningCategory(
            id: "free_time_sports",
            englishTitle: "Free Time & Sports",
            kurdishTitle: "Dema vala û spor",
            emoji: "⚽",
            subtopics: [
                LearningSubtopic(id: "sports", englishTitle: "Sports", kurdishTitle: "Spor"),
                LearningSubtopic(id: "hobbies", englishTitle: "Hobbies", kurdishTitle: "Sersêrî"),
                LearningSubtopic(id: "games", englishTitle: "Games", kurdishTitle: "Lîstik"),
                LearningSubtopic(id: "music", englishTitle: "Music", kurdishTitle: "Muzîk"),
                LearningSubtopic(id: "entertainment", englishTitle: "Entertainment", kurdishTitle: "Eğlence"),
                LearningSubtopic(id: "outdoor_activities", englishTitle: "Outdoor Activities", kurdishTitle: "Çalakiyên derveyî")
            ]
        ),
        LearningCategory(
            id: "world_nature",
            englishTitle: "World & Nature",
            kurdishTitle: "Cîhan û xweza",
            emoji: "🌍",
            subtopics: [
                LearningSubtopic(id: "weather", englishTitle: "Weather", kurdishTitle: "Hewa"),
                LearningSubtopic(id: "animals", englishTitle: "Animals", kurdishTitle: "Heywanl"),
                LearningSubtopic(id: "plants", englishTitle: "Plants", kurdishTitle: "Nebat"),
                LearningSubtopic(id: "geography", englishTitle: "Geography", kurdishTitle: "Cografya"),
                LearningSubtopic(id: "countries", englishTitle: "Countries", kurdishTitle: "Welat"),
                LearningSubtopic(id: "environment", englishTitle: "Environment", kurdishTitle: "Jîngeh")
            ]
        ),
        LearningCategory(
            id: "numbers_measures",
            englishTitle: "Numbers & Measures",
            kurdishTitle: "Hejmara û mezinahî",
            emoji: "🔢",
            subtopics: [
                LearningSubtopic(id: "numbers_1_100", englishTitle: "Numbers 1-100", kurdishTitle: "Hejmar 1-100"),
                LearningSubtopic(id: "time", englishTitle: "Time", kurdishTitle: "Dem"),
                LearningSubtopic(id: "dates", englishTitle: "Dates", kurdishTitle: "Dîrok"),
                LearningSubtopic(id: "money", englishTitle: "Money", kurdishTitle: "Pere"),
                LearningSubtopic(id: "measurements", englishTitle: "Measurements", kurdishTitle: "Pîvan"),
                LearningSubtopic(id: "math_operations", englishTitle: "Math Operations", kurdishTitle: "Operasyonên matematîkê")
            ]
        )
    ]
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header Section
                    VStack(spacing: 16) {
                        Text("Your Learning Journey")
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                        
                        Text("Complete each milestone to unlock the next")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                    
                    // Vertical Category List
                    LazyVStack(spacing: 20) {
                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                            CategoryMilestoneCard(
                                category: category,
                                onTap: {
                                    selectedCategory = category
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Bottom spacing
                    Color.clear.frame(height: 40)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color.orange.opacity(0.02)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localized("close")) {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    LanguageToggleButton()
                        .environmentObject(localizationManager)
                }
            }
        }
        .sheet(item: $selectedCategory) { category in
            SubtopicsView(category: category)
                .environmentObject(favoritesManager)
                .environmentObject(progressManager)
                .environmentObject(reviewManager)
                .environmentObject(learningLanguageManager)
        }
    }
}

// MARK: - Language Toggle Button Component
struct LanguageToggleButton: View {
    @EnvironmentObject var localizationManager: LocalizationManager
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            localizationManager.toggleLanguage()
        }) {
            Text(localizationManager.currentLanguage.quickToggleSymbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.orange)
                        .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
                )
        }
        .soundButtonStyle(.normal)
    }
}

// MARK: - Category Milestone Card Component
struct CategoryMilestoneCard: View {
    let category: LearningCategory
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            onTap()
        }) {
            HStack(spacing: 16) {
                // Category Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.orange,
                                    Color.orange.opacity(0.8)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(
                            color: Color.orange.opacity(0.3),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                    
                    // Category emoji
                    Text(category.emoji)
                        .font(.system(size: 28))
                }
                
                // Category Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.englishTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(category.kurdishTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.leading)
                    
                    // Subtopic count
                    Text("\(category.subtopics.count) lessons")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                VStack {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: Color.black.opacity(0.08),
                        radius: 10,
                        x: 0,
                        y: 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        Color.orange.opacity(0.2),
                        lineWidth: 2
                    )
            )
        }
        .soundButtonStyle(.normal)
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.1), value: false)
    }
}

// MARK: - Category Info Card Component
struct CategoryInfoCard: View {
    let category: LearningCategory
    let isUnlocked: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(category.englishTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isUnlocked ? .primary : .gray)
                .lineLimit(2)
            
            Text(category.kurdishTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isUnlocked ? .orange : .gray.opacity(0.7))
                .lineLimit(1)
            
            if !isUnlocked {
                Text("Locked")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(
                    color: isUnlocked ? Color.black.opacity(0.1) : Color.black.opacity(0.05),
                    radius: isUnlocked ? 6 : 3,
                    x: 0,
                    y: 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isUnlocked ? Color.orange.opacity(0.2) : Color.gray.opacity(0.1),
                    lineWidth: 1
                )
        )
        .frame(width: 140)
    }
}

// MARK: - Category Card Component
struct CategoryCard: View {
    let category: LearningCategory
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Emoji Icon
                Text(category.emoji)
                    .font(.system(size: 40))
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                    )
                
                // Text Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.englishTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(category.kurdishTitle)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow Indicator
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.1), lineWidth: 1)
            )
        }
        .soundButtonStyle(.normal)
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.1), value: false)
    }
}

// MARK: - Subtopic Row Component
struct SubtopicRowView: View {
    let subtopic: LearningSubtopic
    let isViewed: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            GlobalSoundManager.shared.playButtonClick()
            HapticManager.shared.lightImpact()
            onTap()
        }) {
            rowContent
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(rowBackground)
                .overlay(rowBorder)
        }
        .buttonStyle(SoundButtonStyle(soundType: .silent))
    }
    
    private var rowContent: some View {
        HStack(spacing: 16) {
            subtopicIcon
            titleSection
            Spacer()
            viewedIndicator
            lessonIndicator
            chevronIcon
        }
    }
    
    private var subtopicIcon: some View {
        Image(systemName: subtopic.id == "family_relationships" ? "person.2.fill" : "book.pages")
            .font(.title3)
            .foregroundColor(.orange)
            .frame(width: 24, height: 24)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(subtopic.englishTitle)
                .font(.body.weight(.medium))
                .foregroundColor(.primary)
            
            Text(subtopic.kurdishTitle)
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
    
    @ViewBuilder
    private var viewedIndicator: some View {
        if isViewed {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
        }
    }
    
    @ViewBuilder
    private var lessonIndicator: some View {
        if subtopic.id == "family_relationships" {
            Text("15 lessons")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(lessonBadgeBackground)
        }
    }
    
    private var lessonBadgeBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.orange.opacity(0.1))
    }
    
    private var chevronIcon: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.medium))
            .foregroundColor(.secondary)
    }
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground))
            .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
    
    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                isViewed ? Color.green.opacity(0.3) : Color.orange.opacity(0.08),
                lineWidth: isViewed ? 2 : 1
            )
    }
}

// MARK: - Quiz Button Component
struct QuizButtonView: View {
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            separatorLine
            headerSection
            quizButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(containerBackground)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private var separatorLine: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(height: 1)
            .padding(.horizontal, 40)
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.orange)
                Text("Ready for Quiz!")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Text("You've completed all vocabulary lessons. Test your knowledge!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
    }
    
    private var quizButton: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            onTap()
        }) {
            buttonContent
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(buttonGradient)
        }
        .actionSound()
    }
    
    private var buttonContent: some View {
        HStack {
            Image(systemName: "questionmark.circle.fill")
                .font(.title3)
            Text("Take a Quiz")
                .font(.headline.weight(.semibold))
            Spacer()
            Image(systemName: "arrow.right")
                .font(.subheadline.weight(.medium))
        }
    }
    
    private var buttonGradient: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
    
    private var containerBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.orange.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Subtopics View (Simplified)
struct SubtopicsView: View {
    let category: LearningCategory
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var progressManager: ProgressManager
    @EnvironmentObject var reviewManager: ReviewManager
    @EnvironmentObject var learningLanguageManager: LearningLanguageManager
    @State private var showVocabularyLesson = false
    @State private var showQuiz = false
    @State private var selectedSubtopic: String = ""
    
    var body: some View {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    headerView
                    
                    // Subtopics List
                    subtopicsListView
                    
                // Quiz button for greetings_essentials (shows when all subcategories completed)
                if category.id == "greetings_essentials" && progressManager.isQuizUnlocked(for: category.id) {
                    QuizButtonView {
                        showQuiz = true
                    }
                }
                // Quiz button for other categories (excluded for people_relationships - quiz moved to subcategory level)
                else if category.id != "people_relationships" && progressManager.isQuizUnlocked(for: category.id) {
                        QuizButtonView {
                            showQuiz = true
                        }
                    }
                    
                    // Bottom spacing
                    Color.clear.frame(height: 20)
                }
            }
            .background(backgroundGradient)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .foregroundColor(.orange)
            }
        }
        .fullScreenCover(isPresented: $showVocabularyLesson) {
            getLessonView()
        }
        .fullScreenCover(isPresented: $showQuiz) {
            QuizView(category: category)
                .environmentObject(progressManager)
                .environmentObject(reviewManager)
        }
    }
    
    // MARK: - View Components
    private var headerView: some View {
        VStack(spacing: 12) {
            Text(category.emoji)
                .font(.system(size: 60))
            
            VStack(spacing: 4) {
                Text(category.englishTitle)
                    .font(.title.bold())
                    .foregroundColor(.primary)
                
                Text(category.kurdishTitle)
                    .font(.title3)
                    .foregroundColor(.orange)
            }
        }
        .padding(.top, 20)
    }
    
    private var subtopicsListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(0..<category.subtopics.count, id: \.self) { index in
                let subtopic = category.subtopics[index]
                let isViewed = progressManager.isVocabularyViewed(categoryId: category.id, subtopicId: subtopic.id)
                
                SubtopicRowView(
                    subtopic: subtopic,
                    isViewed: isViewed
                ) {
                    selectedSubtopic = subtopic.id
                    showVocabularyLesson = true
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color(.systemBackground), Color.orange.opacity(0.02)]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    @ViewBuilder
    private func getLessonView() -> some View {
        if category.id == "people_relationships" {
            // Handle different subcategories in people_relationships
            switch selectedSubtopic {
            case "family_relationships":
            FamilyMembersLessonView()
                .environmentObject(favoritesManager)
                .environmentObject(progressManager)
                    .environmentObject(reviewManager)
                    .environmentObject(learningLanguageManager)
            case "greetings":
                VocabularyLessonView(
                    categoryId: "people_relationships",
                    subcategoryId: "greetings",
                    subcategoryTitle: "Greetings"
                )
                .environmentObject(learningLanguageManager)
            case "emotions":
                VocabularyLessonView(
                    categoryId: "people_relationships",
                    subcategoryId: "emotions",
                    subcategoryTitle: "Emotions"
                )
                .environmentObject(learningLanguageManager)
            case "personality":
                VocabularyLessonView(
                    categoryId: "people_relationships",
                    subcategoryId: "personality",
                    subcategoryTitle: "Personality"
                )
                .environmentObject(learningLanguageManager)
            case "social_interactions":
                VocabularyLessonView(
                    categoryId: "people_relationships",
                    subcategoryId: "social_interactions",
                    subcategoryTitle: "Social Interactions"
                )
                .environmentObject(learningLanguageManager)
            case "introductions":
                VocabularyLessonView(
                    categoryId: "people_relationships",
                    subcategoryId: "introductions",
                    subcategoryTitle: "Introductions"
                )
                .environmentObject(learningLanguageManager)
            default:
                // If selectedSubtopic is empty or unknown, show family_relationships as default
                FamilyMembersLessonView()
                    .environmentObject(favoritesManager)
                    .environmentObject(progressManager)
                    .environmentObject(reviewManager)
                    .environmentObject(learningLanguageManager)
            }
        } else if category.id == "greetings_essentials" {
            // Handle different subcategories in greetings_essentials
            switch selectedSubtopic {
            case "greetings_farewells":
                GreetingsFarewellsLessonView()
                    .environmentObject(favoritesManager)
                    .environmentObject(progressManager)
                    .environmentObject(learningLanguageManager)
            case "polite_phrases":
                PolitePhrasesLessonView()
                    .environmentObject(favoritesManager)
                    .environmentObject(progressManager)
                    .environmentObject(learningLanguageManager)
            case "introductions":
                IntroductionsLessonView()
                    .environmentObject(favoritesManager)
                    .environmentObject(progressManager)
                    .environmentObject(learningLanguageManager)
            case "basic_questions":
                BasicQuestionsLessonView()
                    .environmentObject(favoritesManager)
                    .environmentObject(progressManager)
                    .environmentObject(learningLanguageManager)
            case "yes_no_confirmation":
                YesNoConfirmationLessonView()
                    .environmentObject(favoritesManager)
                    .environmentObject(progressManager)
                    .environmentObject(learningLanguageManager)
            default:
                // If selectedSubtopic is empty or unknown, show greetings_farewells as default
                GreetingsFarewellsLessonView()
                    .environmentObject(favoritesManager)
                    .environmentObject(progressManager)
                    .environmentObject(learningLanguageManager)
            }
        } else {
            // Coming soon view for other categories or empty state
            ComingSoonView(subtopic: "Please select a subcategory")
        }
    }
}

// MARK: - Family Members Lesson View
struct FamilyMembersLessonView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var progressManager: ProgressManager
    @EnvironmentObject var reviewManager: ReviewManager
    @EnvironmentObject var learningLanguageManager: LearningLanguageManager
    @StateObject private var audioManager = AudioManager.shared
    @State private var currentWordIndex = 0
    @State private var showTranslation = false
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var showQuiz = false
    @State private var lessonCompleted = false
    
    // Category object for quiz
    private let familyCategory = LearningCategory(
        id: "people_relationships",
        englishTitle: "People & Relationships",
        kurdishTitle: "Kes û Pêwendî",
        emoji: "👨‍👩‍👧‍👦",
        subtopics: [
            LearningSubtopic(id: "family_relationships", englishTitle: "Family Members", kurdishTitle: "Endamên malbatê")
        ]
    )
    
    // Your 15 Kurdish family words with images (Assets folders are for organization only)
    private let familyWords = [
        ("bav", "Father", "Bavê min kar dike.", "My father is working.", "father", "الأب", "والدي يعمل."),
        ("dê/dayik", "Mother", "Dayika min xwarin çêkir.", "My mother cooked food.", "mother", "الأم", "والدتي طبخت الطعام."),
        ("kurmet", "Cousin (male)", "Kurmeta min li dibistanekê dixwîne.", "My cousin studies at a school.", "cousin_male", "ابن العم", "ابن عمي يدرس في المدرسة."),
        ("xwişk", "Sister", "Ez bi xwişka xwe re bazdikevim.", "I run with my sister.", "sister", "الأخت", "أركض مع أختي."),
        ("bira", "Brother", "Birayê min biçûktir e.", "My brother is younger.", "brother", "الأخ", "أخي أصغر."),
        ("dapîr", "Grandmother", "Dapîra min ji çayê hez dike.", "My grandmother loves tea.", "grandmother", "الجدة", "جدتي تحب الشاي."),
        ("bapîr", "Grandfather", "Bapîra min li bajêr dijî.", "My grandfather lives in the city.", "grandfather", "الجد", "جدي يعيش في المدينة."),
        ("dotmam/keçap", "Cousin (female)", "Dotmama min li Efrînê dijî.", "My female cousin lives in Afrin.", "cousin_female", "بنت العم", "بنت عمي تعيش في عفرين."),
        ("met/xaltîk", "Aunt", "Meta min qehwe çêkir.", "My aunt made coffee.", "aunt", "العمة", "عمتي صنعت القهوة."),
        ("ap/mam", "Uncle", "Xalê min ji xwendina pirtûkan hez dike.", "My uncle loves reading Books.", "uncle", "العم", "عمي يحب قراءة الكتب."),
        ("hevjîn/hevaljin", "Partner / Spouse", "Hevaljina min bi min re diçe bazarê.", "My partner goes to the market with me.", "partner", "الشريك", "شريكي يذهب إلى السوق معي."),
        ("kur/law", "Son", "Kurê min ji fûtbolê hez dike.", "My son loves football.", "son", "الابن", "ابني يحب كرة القدم."),
        ("keç", "Daughter", "Keça min çîrokên xwe dixwîne.", "My daughter reads her stories.", "daughter", "الابنة", "ابنتي تقرأ قصصها."),
        ("birazî", "Nephew", "biraziyê min li parka lîstikê ye.", "My nephew is at the playground.", "nephew", "ابن الأخ", "ابن أخي في الملعب."),
        ("xwarzî", "Niece", "Xwarzîya min wêneyekî çêdike.", "My niece is drawing a picture.", "niece", "بنت الأخت", "بنت أختي ترسم صورة.")
    ]
    
    private var currentWord: (kurdish: String, english: String, kurdishExample: String, englishExample: String, imageName: String, arabic: String, arabicExample: String) {
        let word = familyWords[currentWordIndex]
        return (kurdish: word.0, english: word.1, kurdishExample: word.2, englishExample: word.3, imageName: word.4, arabic: word.5, arabicExample: word.6)
    }
    
    // Helper functions for Arabic translations (temporary for supporting old data structure)
    private func getArabicTranslation(for english: String) -> String {
        let arabicTranslations = [
            "Father": "الأب",
            "Mother": "الأم", 
            "Cousin (male)": "ابن العم",
            "Sister": "الأخت",
            "Brother": "الأخ",
            "Grandmother": "الجدة",
            "Grandfather": "الجد",
            "Cousin (female)": "بنت العم",
            "Aunt": "العمة",
            "Uncle": "العم",
            "Partner / Spouse": "الشريك",
            "Son": "الابن",
            "Daughter": "الابنة",
            "Nephew": "ابن الأخ",
            "Niece": "بنت الأخت"
        ]
        return arabicTranslations[english] ?? english
    }
    
    private func getArabicExample(for englishExample: String) -> String {
        let arabicExamples = [
            "My father is working.": "والدي يعمل.",
            "My mother cooked food.": "والدتي طبخت الطعام.",
            "My cousin studies at a school.": "ابن عمي يدرس في المدرسة.",
            "I run with my sister.": "أركض مع أختي.",
            "My brother is younger.": "أخي أصغر.",
            "My grandmother loves tea.": "جدتي تحب الشاي.",
            "My grandfather lives in the city.": "جدي يعيش في المدينة.",
            "My female cousin lives in Afrin.": "بنت عمي تعيش في عفرين.",
            "My aunt made coffee.": "عمتي صنعت القهوة.",
            "My uncle loves reading Books.": "عمي يحب قراءة الكتب.",
            "My partner goes to the market with me.": "شريكي يذهب إلى السوق معي.",
            "My son loves football.": "ابني يحب كرة القدم.",
            "My daughter reads her stories.": "ابنتي تقرأ قصصها.",
            "My nephew is at the playground.": "ابن أخي في الملعب.",
            "My niece is drawing a picture.": "بنت أختي ترسم صورة."
        ]
        return arabicExamples[englishExample] ?? englishExample
    }
    
    var body: some View {
        NavigationView {
            if lessonCompleted {
                lessonCompletedView
            } else {
                mainLessonView
            }
        }
        .fullScreenCover(isPresented: $showQuiz) {
            QuizView(category: familyCategory)
                .environmentObject(progressManager)
                .environmentObject(reviewManager)
        }
        .onAppear {
            StreakManager.shared.startLearningSession()
        }
        .onDisappear {
            StreakManager.shared.endLearningSession()
        }
    }
    
    // MARK: - Main Lesson View
    private var mainLessonView: some View {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Progress indicator
                    VStack(spacing: 8) {
                        HStack {
                            ForEach(0..<familyWords.count, id: \.self) { index in
                                Circle()
                                    .fill(index <= currentWordIndex ? Color.orange : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        
                        Text("\(currentWordIndex + 1) of \(familyWords.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 10)
                    
                    // Main content with proper spacing
                    VStack(spacing: 30) {
                        // Interactive Flip Card
                        VStack(spacing: 20) {
                            FlipCard(
                                word: currentWord,
                                isFlipped: $showTranslation,
                                isFavorite: favoritesManager.isWordFavorited(kurdish: currentWord.kurdish, category: "people_relationships"),
                                audioManager: audioManager,
                                onFavoriteToggle: {
                                    favoritesManager.toggleFavorite(
                                        kurdish: currentWord.kurdish,
                                        english: currentWord.english,
                                        arabic: currentWord.arabic,
                                        kurdishExample: currentWord.kurdishExample,
                                        englishExample: currentWord.englishExample,
                                        arabicExample: currentWord.arabicExample,
                                        imageName: currentWord.imageName,
                                        category: "people_relationships",
                                        subcategory: "Family Members"
                                    )
                                },
                                onSpeakerTap: {
                                    // Audio functionality for all family words
                                    let kurdishWord = currentWord.kurdish
                                    print("🔊 Playing pronunciation for: \(kurdishWord)")
                                    audioManager.speakKurdishWord(kurdishWord)
                                }
                            )
                            .frame(width: 280, height: 380)
                            .offset(dragOffset)
                            .scaleEffect(isDragging ? 0.95 : 1.0)
                            .opacity(isDragging ? 0.8 : 1.0)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    showTranslation.toggle()
                                }
                            }
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragOffset = value.translation
                                        isDragging = true
                                    }
                                    .onEnded { value in
                                        let swipeThreshold: CGFloat = 100
                                        let horizontalMovement = value.translation.width
                                        
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            dragOffset = .zero
                                            isDragging = false
                                        }
                                        
                                        // Swipe right (previous card)
                                        if horizontalMovement > swipeThreshold && currentWordIndex > 0 {
                                            HapticManager.shared.softImpact()
                                            withAnimation(.easeInOut) {
                                                currentWordIndex -= 1
                                                showTranslation = false
                                            }
                                        }
                                        // Swipe left (next card)
                                        else if horizontalMovement < -swipeThreshold && currentWordIndex < familyWords.count - 1 {
                                            HapticManager.shared.softImpact()
                                            withAnimation(.easeInOut) {
                                                currentWordIndex += 1
                                                showTranslation = false
                                            }
                                        }
                                        // Complete lesson on last card swipe left
                                        else if horizontalMovement < -swipeThreshold && currentWordIndex == familyWords.count - 1 {
                                            HapticManager.shared.mediumImpact()
                                            progressManager.markVocabularyAsViewed(categoryId: "people_relationships", subtopicId: "family_relationships")
                                            StreakManager.shared.recordActivity()
                                            lessonCompleted = true
                                        }
                                    }
                            )
                            
                            // Swipe indicator hints
                            HStack(spacing: 40) {
                                if currentWordIndex > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                            .font(.caption)
                                            .foregroundColor(.orange.opacity(0.6))
                                        Text("Swipe right")
                                            .font(.caption)
                                            .foregroundColor(.orange.opacity(0.6))
                                    }
                                } else {
                                    Color.clear.frame(height: 20)
                                }
                                
                                Spacer()
                                
                                if currentWordIndex < familyWords.count - 1 {
                                    HStack(spacing: 4) {
                                        Text("Swipe left")
                                            .font(.caption)
                                            .foregroundColor(.orange.opacity(0.6))
                                        Image(systemName: "chevron.left")
                                            .font(.caption)
                                            .foregroundColor(.orange.opacity(0.6))
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Text("Swipe left to complete")
                                            .font(.caption)
                                            .foregroundColor(.green.opacity(0.8))
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .foregroundColor(.green.opacity(0.8))
                                    }
                                }
                            }
                            .padding(.horizontal, 40)
                            
                            // Audio availability indicator
                            HStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("Audio available")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.green.opacity(0.1))
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Extra spacing before navigation buttons
                    Spacer()
                        .frame(height: 40)
                    
                    // Navigation buttons with better positioning
                    HStack(spacing: 15) {
                        if currentWordIndex > 0 {
                            Button("Previous") {
                                HapticManager.shared.lightImpact()
                                withAnimation(.easeInOut) {
                                    currentWordIndex -= 1
                                    showTranslation = false
                                }
                            }
                            .soundButtonStyle(.normal)
                            .font(.headline)
                            .foregroundColor(.orange)
                            .frame(minWidth: 120, minHeight: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange, lineWidth: 2)
                            )
                        } else {
                            // Invisible spacer to keep Next button centered when Previous is hidden
                            Color.clear
                                .frame(minWidth: 120, minHeight: 50)
                        }
                        
                        Spacer()
                        
                        Button(currentWordIndex < familyWords.count - 1 ? "Next" : "Complete") {
                            HapticManager.shared.lightImpact()
                            withAnimation(.easeInOut) {
                                if currentWordIndex < familyWords.count - 1 {
                                    currentWordIndex += 1
                                    showTranslation = false
                                } else {
                                    // Mark as completed when all vocabulary is viewed
                                    progressManager.markVocabularyAsViewed(categoryId: "people_relationships", subtopicId: "family_relationships")
                                    StreakManager.shared.recordActivity()
                                    lessonCompleted = true
                                }
                            }
                        }
                        .soundButtonStyle(currentWordIndex < familyWords.count - 1 ? .normal : .action)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(minWidth: 120, minHeight: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange)
                        )
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color.orange.opacity(0.02)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Family Members")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showTranslation)
        }
    
    // MARK: - Lesson Completed View
    private var lessonCompletedView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            // Completion message
            VStack(spacing: 16) {
                Text("🎉 Congratulations!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)
                
                Text("You've completed the Family Members vocabulary!")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Ready to test your knowledge?")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                // Quiz button
                Button("Take Quiz") {
                    HapticManager.shared.lightImpact()
                    showQuiz = true
                }
                .actionSound()
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange)
                )
                
                // Review button
                Button("Review Vocabulary") {
                    HapticManager.shared.lightImpact()
                    withAnimation(.easeInOut) {
                        lessonCompleted = false
                        currentWordIndex = 0
                        showTranslation = false
                    }
                }
                .soundButtonStyle(.normal)
                .font(.headline)
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange, lineWidth: 2)
                )
                
                // Done button
                Button("Done") {
                    HapticManager.shared.lightImpact()
                    dismiss()
                }
                .soundButtonStyle(.normal)
                .font(.headline)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground), Color.green.opacity(0.02)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .navigationTitle("Lesson Complete")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    HapticManager.shared.lightImpact()
                    dismiss()
                }
                .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - Flip Card Component
struct FlipCard: View {
    let word: (kurdish: String, english: String, kurdishExample: String, englishExample: String, imageName: String, arabic: String, arabicExample: String)
    @Binding var isFlipped: Bool
    let isFavorite: Bool
    let audioManager: AudioManager
    let onFavoriteToggle: () -> Void
    let onSpeakerTap: () -> Void
    
    var body: some View {
        ZStack {
            // Front side (Image + Kurdish word)
            CardFront(
                word: word,
                isFavorite: isFavorite,
                audioManager: audioManager,
                onFavoriteToggle: onFavoriteToggle,
                onSpeakerTap: onSpeakerTap
            )
                .rotation3DEffect(
                    .degrees(isFlipped ? 90 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                .opacity(isFlipped ? 0 : 1)
            
            // Back side (Example sentences)
            CardBack(word: word)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -90),
                    axis: (x: 0, y: 1, z: 0)
                )
                .opacity(isFlipped ? 1 : 0)
        }
    }
}

// MARK: - Card Front Component
struct CardFront: View {
    let word: (kurdish: String, english: String, kurdishExample: String, englishExample: String, imageName: String, arabic: String, arabicExample: String)
    let isFavorite: Bool
    let audioManager: AudioManager
    let onFavoriteToggle: () -> Void
    let onSpeakerTap: () -> Void
    
    @State private var heartScale: CGFloat = 1.0
    @State private var speakerScale: CGFloat = 1.0
    @EnvironmentObject var learningLanguageManager: LearningLanguageManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Image section
            Image(word.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Kurdish word
            VStack(spacing: 8) {
                Text(word.kurdish)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                
                Text(learningLanguageManager.currentLearningLanguage == .english ? word.english : word.arabic)
                    .font(.title3.weight(.medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Interactive buttons
            HStack(spacing: 24) {
                // Favorite button
                Button(action: {
                    HapticManager.shared.lightImpact()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        heartScale = 1.3
                        onFavoriteToggle()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            heartScale = 1.0
                        }
                    }
                }) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isFavorite ? .red : .orange)
                        .scaleEffect(heartScale)
                }
                .soundButtonStyle(.normal)
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
                
                // Speaker button
                Button(action: {
                    HapticManager.shared.lightImpact()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        speakerScale = 1.3
                        onSpeakerTap()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            speakerScale = 1.0
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: audioManager.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(audioManager.isSpeaking ? .green : .orange)
                            .scaleEffect(speakerScale)
                        
                        if audioManager.isSpeaking {
                            Text("Playing...")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.green)
                        }
                    }
                }
                .soundButtonStyle(.normal)
                .accessibilityLabel("Play pronunciation")
            }
            .padding(.top, 8)
            
            // Tap hint
            Text("Tap card to see example")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Card Back Component
struct CardBack: View {
    let word: (kurdish: String, english: String, kurdishExample: String, englishExample: String, imageName: String, arabic: String, arabicExample: String)
    @EnvironmentObject var learningLanguageManager: LearningLanguageManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Example header
            Text("Example:")
                .font(.title2.weight(.bold))
                .foregroundColor(.orange)
            
            Spacer()
            
            // Kurdish example
            VStack(spacing: 12) {
                Text(word.kurdishExample)
                    .font(.title3.weight(.medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                
                // Separator line
                Rectangle()
                    .fill(Color.orange.opacity(0.3))
                    .frame(height: 1)
                    .frame(maxWidth: 150)
                
                Text(learningLanguageManager.currentLearningLanguage == .english ? word.englishExample : word.arabicExample)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            
            Spacer()
            
            // Tap hint
            Text("Tap to go back")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.orange.opacity(0.05),
                            Color.orange.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.orange.opacity(0.4), lineWidth: 2)
        )
    }
}

// MARK: - Hexagon Shape
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        let centerX = width / 2
        let centerY = height / 2
        let radius = min(width, height) / 2
        
        // Create hexagon with 6 points
        for i in 0..<6 {
            let angle = Double(i) * Double.pi / 3.0 - Double.pi / 2.0
            let x = centerX + radius * cos(angle)
            let y = centerY + radius * sin(angle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Hexagon Category Button
struct HexagonCategoryButton: View {
    let category: LearningCategory
    let isUnlocked: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var categoryConfig: CategoryConfiguration {
        CategoryConfiguration.configuration(for: category.id)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                // Hexagon with SF symbol icon
                ZStack {
                    // Main hexagon background
                    Image(systemName: "hexagon.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(isUnlocked ? categoryConfig.backgroundColor : Color.gray.opacity(0.4))
                        .overlay(
                            // White border
                            Image(systemName: "hexagon")
                                .resizable()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.white)
                                .opacity(0.8)
                        )
                        .shadow(
                            color: isUnlocked ? categoryConfig.backgroundColor.opacity(0.3) : Color.gray.opacity(0.2),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                    
                    // Centered category icon
                    Image(systemName: categoryConfig.iconName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .foregroundColor(.white)
                        .opacity(isUnlocked ? 1.0 : 0.6)
                    
                    // Lock indicator (top-right corner)
                    if !isUnlocked {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.red)
                                    .background(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 22, height: 22)
                                    )
                                    .offset(x: 8, y: -8)
                            }
                            Spacer()
                        }
                    } else {
                        // Optional: Show unlock indicator for unlocked categories
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "lock.open.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.green)
                                    .background(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 22, height: 22)
                                    )
                                    .offset(x: 8, y: -8)
                            }
                            Spacer()
                        }
                    }
                }
                
                // Category title
                VStack(spacing: 2) {
                    Text(category.englishTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isUnlocked ? .primary : .gray)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(category.kurdishTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isUnlocked ? categoryConfig.backgroundColor : .gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                }
                .frame(width: 110)
            }
        }
        .soundButtonStyle(.normal)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .disabled(!isUnlocked)
    }
}

// MARK: - Quiz View
struct QuizView: View {
    let category: LearningCategory
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var progressManager: ProgressManager
    @EnvironmentObject var reviewManager: ReviewManager
    @StateObject private var audioEffectsManager = AudioEffectsManager.shared
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswer: String? = nil
    @State private var showResult = false
    @State private var score = 0
    @State private var quizCompleted = false
    @State private var quizQuestionsCache: [QuizQuestion] = []
    
    // Sample quiz questions for Family relationships
    private let familyQuizQuestions = [
        QuizQuestion(
            kurdishWord: "bav",
            correctAnswer: "Father",
            options: ["Father", "Mother", "Brother", "Sister"]
        ),
        QuizQuestion(
            kurdishWord: "xwişk",
            correctAnswer: "Sister",
            options: ["Brother", "Sister", "Mother", "Cousin"]
        ),
        QuizQuestion(
            kurdishWord: "dapîr",
            correctAnswer: "Grandmother",
            options: ["Grandfather", "Grandmother", "Aunt", "Uncle"]
        ),
        QuizQuestion(
            kurdishWord: "kur/law",
            correctAnswer: "Son",
            options: ["Daughter", "Son", "Nephew", "Niece"]
        ),
        QuizQuestion(
            kurdishWord: "hevjîn/hevaljin",
            correctAnswer: "Partner / Spouse",
            options: ["Friend", "Partner / Spouse", "Cousin", "Neighbor"]
        )
    ]
    
    // Quiz questions for Greetings & Essentials category
    private func getGreetingsEssentialsQuizQuestions() -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        
        // Greetings & Farewells questions
        questions.append(contentsOf: [
            QuizQuestion(
                kurdishWord: "Roj baş",
                correctAnswer: "Good morning",
                options: ["Good morning", "Good evening", "Good night", "Goodbye"]
            ),
            QuizQuestion(
                kurdishWord: "Êvar baş",
                correctAnswer: "Good evening",
                options: ["Good morning", "Good evening", "Good afternoon", "Good night"]
            ),
            QuizQuestion(
                kurdishWord: "Şev baş",
                correctAnswer: "Good night",
                options: ["Good morning", "Good evening", "Good night", "Sweet dreams"]
            ),
            QuizQuestion(
                kurdishWord: "Bi xatirê te",
                correctAnswer: "Goodbye",
                options: ["Hello", "Good morning", "Goodbye", "Thank you"]
            ),
            QuizQuestion(
                kurdishWord: "Xewn xweş",
                correctAnswer: "Sweet dreams",
                options: ["Good night", "Sweet dreams", "Sleep well", "Good evening"]
            ),
            QuizQuestion(
                kurdishWord: "Dîsa em ê bibînin",
                correctAnswer: "See you later",
                options: ["See you later", "Goodbye", "Good night", "Take care"]
            )
        ])
        
        // Polite Phrases questions
        questions.append(contentsOf: [
            QuizQuestion(
                kurdishWord: "Ji kerema xwe",
                correctAnswer: "Please",
                options: ["Please", "Thank you", "Excuse me", "Sorry"]
            ),
            QuizQuestion(
                kurdishWord: "Spas",
                correctAnswer: "Thank you",
                options: ["Please", "Thank you", "You're welcome", "Sorry"]
            ),
            QuizQuestion(
                kurdishWord: "Ser çavan",
                correctAnswer: "You're welcome",
                options: ["Thank you", "You're welcome", "Excuse me", "No problem"]
            ),
            QuizQuestion(
                kurdishWord: "Biborî",
                correctAnswer: "Sorry",
                options: ["Please", "Thank you", "Sorry", "Excuse me"]
            )
        ])
        
        // Introductions questions
        questions.append(contentsOf: [
            QuizQuestion(
                kurdishWord: "Navê te çi ye?",
                correctAnswer: "What's your name?",
                options: ["What's your name?", "How are you?", "Where are you from?", "Nice to meet you"]
            ),
            QuizQuestion(
                kurdishWord: "Navê min ... e",
                correctAnswer: "My name is…",
                options: ["My name is…", "I am from…", "I am fine", "Nice to meet you"]
            ),
            QuizQuestion(
                kurdishWord: "Ez kêfxweş bûm ku te nas kirim",
                correctAnswer: "Nice to meet you",
                options: ["How are you?", "Nice to meet you", "What's your name?", "I'm fine"]
            ),
            QuizQuestion(
                kurdishWord: "Tu ji ku derê yî?",
                correctAnswer: "Where are you from?",
                options: ["What's your name?", "How are you?", "Where are you from?", "How old are you?"]
            ),
            QuizQuestion(
                kurdishWord: "Ez ji ... me",
                correctAnswer: "I'm from...",
                options: ["I'm from...", "My name is...", "I live in...", "I work in..."]
            )
        ])
        
        // Basic Questions questions
        questions.append(contentsOf: [
            QuizQuestion(
                kurdishWord: "Tu çawa yî?",
                correctAnswer: "How are you?",
                options: ["How are you?", "What's your name?", "Where are you from?", "How old are you?"]
            ),
            QuizQuestion(
                kurdishWord: "Ez baş im, spas",
                correctAnswer: "I'm fine, thanks",
                options: ["I'm fine, thanks", "Not bad", "Very good", "I'm tired"]
            ),
            QuizQuestion(
                kurdishWord: "Tu bi Kurdî diaxivî?",
                correctAnswer: "Do you speak Kurdish?",
                options: ["Do you speak Kurdish?", "Do you understand Kurdish?", "Can you help me?", "Where do you live?"]
            ),
            QuizQuestion(
                kurdishWord: "Hinek",
                correctAnswer: "A little",
                options: ["A lot", "A little", "Very well", "Not at all"]
            ),
            QuizQuestion(
                kurdishWord: "Ez nizanim",
                correctAnswer: "I don't understand",
                options: ["I don't understand", "I don't know", "I can't speak", "I'm learning"]
            )
        ])
        
        // Yes/No & Confirmation questions
        questions.append(contentsOf: [
            QuizQuestion(
                kurdishWord: "Erê",
                correctAnswer: "Yes",
                options: ["Yes", "No", "Maybe", "OK"]
            ),
            QuizQuestion(
                kurdishWord: "Na",
                correctAnswer: "No",
                options: ["Yes", "No", "Maybe", "I don't know"]
            ),
            QuizQuestion(
                kurdishWord: "Dibe",
                correctAnswer: "Maybe",
                options: ["Yes", "No", "Maybe", "OK"]
            ),
            QuizQuestion(
                kurdishWord: "Baş e",
                correctAnswer: "OK",
                options: ["Yes", "No", "Maybe", "OK"]
            )
        ])
        
        return questions.shuffled() // Randomize the order
    }
    
    // Get appropriate quiz questions based on category
    private var quizQuestions: [QuizQuestion] {
        if !quizQuestionsCache.isEmpty {
            return quizQuestionsCache
        }
        
        switch category.id {
        case "people_relationships":
            return familyQuizQuestions
        case "greetings_essentials":
            return generateGreetingsQuizQuestions()
        default:
            return familyQuizQuestions // fallback
        }
    }
    
    private func generateGreetingsQuizQuestions() -> [QuizQuestion] {
        // Limit to 8 questions and shuffle answer options for each question
        let allQuestions = getGreetingsEssentialsQuizQuestions()
        let selectedQuestions = Array(allQuestions.prefix(8))
        return selectedQuestions.map { question in
            QuizQuestion(
                kurdishWord: question.kurdishWord,
                correctAnswer: question.correctAnswer,
                options: question.options.shuffled()
            )
        }
    }
    
    var currentQuestion: QuizQuestion {
        quizQuestions[currentQuestionIndex]
    }
    
    var body: some View {
        VStack(spacing: 30) {
            if !quizCompleted {
                quizActiveView
            } else {
                quizCompletedView
            }
        }
        .background(backgroundGradient)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    HapticManager.shared.lightImpact()
                    dismiss()
                }
                .foregroundColor(.orange)
            }
        }
        .onAppear {
            StreakManager.shared.startLearningSession()
            initializeQuizQuestions()
        }
        .onDisappear {
            StreakManager.shared.endLearningSession()
        }
    }
    
    // MARK: - View Components
    private var quizActiveView: some View {
        Group {
            quizHeader
            Spacer()
            questionSection
            answerOptionsSection
            Spacer()
        }
    }
    
    private var quizHeader: some View {
        VStack(spacing: 16) {
            Text("\(category.englishTitle) Quiz")
                .font(.largeTitle.bold())
                .foregroundColor(.primary)
            
            Text(category.kurdishTitle)
                .font(.title3)
                .foregroundColor(.orange)
            
            Text("Question \(currentQuestionIndex + 1) of \(quizQuestions.count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ProgressView(value: Double(currentQuestionIndex), total: Double(quizQuestions.count))
                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                .frame(height: 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var questionSection: some View {
        VStack(spacing: 20) {
            Text("What does this mean in English?")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(currentQuestion.kurdishWord)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.orange)
                .padding(.horizontal, 30)
                .padding(.vertical, 20)
                .background(questionBackground)
        }
    }
    
    private var questionBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.orange.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 2)
            )
    }
    
    private var answerOptionsSection: some View {
        VStack(spacing: 12) {
            ForEach(currentQuestion.options, id: \.self) { option in
                AnswerOptionButton(
                    option: option,
                    isSelected: selectedAnswer == option,
                    isCorrect: option == currentQuestion.correctAnswer,
                    showResult: showResult,
                    audioEffectsManager: audioEffectsManager
                ) {
                    selectedAnswer = option
                    showResult = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        nextQuestion()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var quizCompletedView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: isPerfectScore ? "trophy.fill" : "target")
                .font(.system(size: 80))
                .foregroundColor(isPerfectScore ? .orange : .blue)
            
            scoreSection
            
            Spacer()
            
            // Show different buttons based on score
            VStack(spacing: 12) {
                if !isPerfectScore {
                    tryAgainButton
                }
            doneButton
            }
        }
    }
    
    private var isPerfectScore: Bool {
        score == quizQuestions.count
    }
    
    private var scoreSection: some View {
        VStack(spacing: 12) {
            Text("Quiz Completed!")
                .font(.largeTitle.bold())
                .foregroundColor(.primary)
            
            Text("You scored \(score) out of \(quizQuestions.count)")
                .font(.title2)
                .foregroundColor(.secondary)
            
            let percentage = Int((Double(score) / Double(quizQuestions.count)) * 100)
            Text("\(percentage)%")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(isPerfectScore ? .green : .orange)
            
            // Encouraging message based on performance
            Text(getEncouragingMessage(percentage: percentage))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }
    
    private func getEncouragingMessage(percentage: Int) -> String {
        switch percentage {
        case 100:
            return "🎉 Perfect! You've mastered these words!"
        case 75...99:
            return "🌟 Great job! You're almost there!"
        case 50...74:
            return "📚 Good effort! Keep practicing to improve!"
        case 25...49:
            return "💪 Don't give up! Review the words and try again!"
        default:
            return "🎯 Practice makes perfect! Review and try again!"
        }
    }
    
    private var tryAgainButton: some View {
        Button("Try Again") {
            HapticManager.shared.lightImpact()
            resetQuiz()
        }
        .font(.headline.weight(.semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue)
        )
        .padding(.horizontal, 20)
    }
    
    private var doneButton: some View {
        Button(isPerfectScore ? "Perfect! Done" : "Done") {
            HapticManager.shared.lightImpact()
            dismiss()
        }
        .font(.headline.weight(.semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPerfectScore ? Color.green : Color.orange)
        )
        .padding(.horizontal, 20)
    }
    
    private func initializeQuizQuestions() {
        if category.id == "greetings_essentials" {
            quizQuestionsCache = generateGreetingsQuizQuestions()
        }
    }
    
    private func resetQuiz() {
        // Reset all quiz state for a fresh attempt
        currentQuestionIndex = 0
        selectedAnswer = nil
        showResult = false
        score = 0
        quizCompleted = false
        
        // Regenerate questions with new shuffled order
        if category.id == "greetings_essentials" {
            quizQuestionsCache = generateGreetingsQuizQuestions()
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color(.systemBackground), Color.orange.opacity(0.02)]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func nextQuestion() {
        if selectedAnswer == currentQuestion.correctAnswer {
            score += 1
        } else {
            // Track incorrect answer for review
            addToReview(currentQuestion)
        }
        
        if currentQuestionIndex < quizQuestions.count - 1 {
            currentQuestionIndex += 1
            selectedAnswer = nil
            showResult = false
        } else {
            quizCompleted = true
            
            // Check if user is struggling (scored 50% or below)
            let percentage = Int((Double(score) / Double(quizQuestions.count)) * 100)
            if percentage <= 50 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    AchievementManager.shared.showQuizStruggleMessage()
                }
            }
        }
    }
    
    private func addToReview(_ question: QuizQuestion) {
        // Map quiz question to review word data
        let wordData = getWordDataForQuizQuestion(question)
        
        let reviewWord = ReviewWord(
            kurdish: wordData.kurdish,
            english: wordData.english,
            arabic: getArabicTranslationForQuiz(for: wordData.english),
            kurdishExample: wordData.kurdishExample,
            englishExample: wordData.englishExample,
            arabicExample: getArabicExampleForQuiz(for: wordData.englishExample),
            imageName: wordData.imageName,
            category: category.id,
            subcategory: getSubcategoryForWord(wordData.kurdish)
        )
        
        reviewManager.addToReview(reviewWord)
    }
    
    private func getWordDataForQuizQuestion(_ question: QuizQuestion) -> (kurdish: String, english: String, kurdishExample: String, englishExample: String, imageName: String) {
        // Map quiz questions to actual word data
        // This is a simplified mapping - in a real app you'd want a more robust system
        
        switch category.id {
        case "people_relationships":
            return getFamilyWordData(for: question.kurdishWord)
        case "greetings_essentials":
            return getGreetingsWordData(for: question.kurdishWord)
        default:
            return (
                kurdish: question.kurdishWord,
                english: question.correctAnswer,
                kurdishExample: "\(question.kurdishWord) - example",
                englishExample: "\(question.correctAnswer) - example",
                imageName: "default"
            )
        }
    }
    
    private func getFamilyWordData(for kurdishWord: String) -> (kurdish: String, english: String, kurdishExample: String, englishExample: String, imageName: String) {
        switch kurdishWord {
        case "bav":
            return ("bav", "Father", "Bavê min ji Kurdistanê ye.", "My father is from Kurdistan.", "father")
        case "xwişk":
            return ("xwişk", "Sister", "Xwişka min dixwîne.", "My sister is studying.", "sister")
        case "dapîr":
            return ("dapîr", "Grandmother", "Dapîra min çîrokên xweş dibêje.", "My grandmother tells nice stories.", "grandmother")
        case "kur/law":
            return ("kur/law", "Son", "Kurê min li dibistanê ye.", "My son is at school.", "son")
        case "hevjîn/hevaljin":
            return ("hevjîn/hevaljin", "Partner / Spouse", "Hevjîna min gelek xweş e.", "My partner is very nice.", "partner")
        default:
            return (kurdishWord, "Unknown", "Example not available.", "Example not available.", "family")
        }
    }
    
    private func getGreetingsWordData(for kurdishWord: String) -> (kurdish: String, english: String, kurdishExample: String, englishExample: String, imageName: String) {
        switch kurdishWord {
        case "Roj baş":
            return ("Roj baş", "Good morning", "Roj baş, ez hêvî dikim roja te baş be.", "Good morning, I hope you have a good day.", "Good_Morning")
        case "Êvar baş":
            return ("Êvar baş", "Good evening", "Êvar baş, hevalno.", "Good evening, my friend.", "Good_evening")
        case "Şev baş":
            return ("Şev baş", "Good night", "Şev baş, xewa şirin bibî.", "Good night, sweet dreams.", "Good_night")
        case "Bi xatirê te":
            return ("Bi xatirê te", "Goodbye", "Ez diçim, bi xatirê te.", "I'm leaving, goodbye.", "Goodbye")
        case "Dîsa em ê bibînin":
            return ("Dîsa em ê bibînin", "See you later", "Dîsa em ê bibînin, heval.", "See you later, friend.", "see_you_later")
        case "Xewn xweş":
            return ("Xewn xweş", "Sweet dreams", "Şev baş û xewnên xweş.", "Good night and sweet dreams.", "Sweet_dreams")
        case "Ji kerema xwe":
            return ("Ji kerema xwe", "Please", "Ji kerema xwe, alîkariya min bike.", "Please, help me.", "Please")
        case "Spas":
            return ("Spas", "Thank you", "Spas ji bo alîkariya te.", "Thank you for your help.", "Thank_you")
        case "Ser çavan":
            return ("Ser çavan", "You're welcome", "Ser çavan, ev karê min e.", "You're welcome, it's my job.", "You_are_welcome")
        case "Biborî":
            return ("Biborî", "Sorry", "Biborî, ez dereng bûm.", "Sorry, I was late.", "sorry")
        case "pirsgirêk tune":
            return ("pirsgirêk tune", "No problem", "pirsgirêk tune, ez dikarim alîkariya te bikim.", "No problem, I can help you.", "No_problem")
        case "Navê te çi ye?":
            return ("Navê te çi ye?", "What's your name?", "Navê te çi ye? Ez dixwazim te nas bikim.", "What's your name? I want to get to know you.", "question")
        case "Navê min ... e":
            return ("Navê min ... e", "My name is…", "Navê min Ahmed e.", "My name is Ahmed.", "introduction")
        case "Ez kêfxweş bûm ku te nas kirim":
            return ("Ez kêfxweş bûm ku te nas kirim", "Nice to meet you", "Ez kêfxweş bûm ku te nas kirim.", "Nice to meet you.", "meeting")
        case "Tu ji ku derê yî?":
            return ("Tu ji ku derê yî?", "Where are you from?", "Tu ji ku derê yî? Ez ji Kurdistanê me.", "Where are you from? I'm from Kurdistan.", "origin")
        case "Ez ji ... me":
            return ("Ez ji ... me", "I'm from...", "Ez ji Kurdistanê me.", "I'm from Kurdistan.", "from")
        case "Tu çawa yî?":
            return ("Tu çawa yî?", "How are you?", "Tu çawa yî? Ez baş im.", "How are you? I'm fine.", "how_are_you")
        case "Ez baş im, spas":
            return ("Ez baş im, spas", "I'm fine, thanks", "Ez baş im, spas. Tu çawa yî?", "I'm fine, thanks. How are you?", "fine")
        case "Tu bi Kurdî diaxivî?":
            return ("Tu bi Kurdî diaxivî?", "Do you speak Kurdish?", "Tu bi Kurdî diaxivî? Ez dixwazim fêr bibim.", "Do you speak Kurdish? I want to learn.", "speak_kurdish")
        case "Hinek":
            return ("Hinek", "A little", "Ez hinek Kurdî dizanim.", "I know a little Kurdish.", "little")
        case "Ez nizanim":
            return ("Ez nizanim", "I don't understand", "Ez nizanim, dîsa bide gotin.", "I don't understand, please say it again.", "understand")
        case "Erê":
            return ("Erê", "Yes", "Erê, ez dixwazim.", "Yes, I want to.", "yes")
        case "Na":
            return ("Na", "No", "Na, ez naxwazim.", "No, I don't want to.", "no")
        case "Dibe":
            return ("Dibe", "Maybe", "Dibe, ez ê li vê fikirînim.", "Maybe, I'll think about it.", "maybe")
        case "Baş e":
            return ("Baş e", "OK", "Baş e, em wilo bikin.", "OK, let's do it like that.", "ok")
        default:
            return (kurdishWord, "Unknown", "Example not available.", "Example not available.", "greeting")
        }
    }
    
    private func getSubcategoryForWord(_ kurdishWord: String) -> String {
        switch category.id {
        case "people_relationships":
            return "Family Relationships"
        case "greetings_essentials":
            if ["Roj baş", "Êvar baş", "Şev baş", "Bi xatirê te", "Dîsa em ê bibînin", "Xewn xweş"].contains(kurdishWord) {
                return "Greetings & Farewells"
            } else if ["Ji kerema xwe", "Spas", "Ser çavan", "Biborî", "pirsgirêk tune"].contains(kurdishWord) {
                return "Polite Phrases"
            } else if ["Navê te çi ye?", "Navê min ... e", "Ez kêfxweş bûm ku te nas kirim", "Tu ji ku derê yî?", "Ez ji ... me"].contains(kurdishWord) {
                return "Introductions"
            } else if ["Tu çawa yî?", "Ez baş im, spas", "Tu bi Kurdî diaxivî?", "Hinek", "Ez nizanim"].contains(kurdishWord) {
                return "Basic Questions"
            } else {
                return "Yes/No & Confirmation"
            }
        default:
            return "General"
        }
    }
    
    // Helper functions for Arabic translations in quiz context
    private func getArabicTranslationForQuiz(for english: String) -> String {
        let arabicTranslations = [
            // Family members
            "Father": "الأب",
            "Sister": "الأخت",
            "Grandmother": "الجدة", 
            "Son": "الابن",
            "Partner / Spouse": "الشريك",
            "Unknown": "غير معروف",
            
            // Greetings & Farewells
            "Good morning": "صباح الخير",
            "Good evening": "مساء الخير",
            "Good night": "تصبح على خير",
            "Goodbye": "مع السلامة",
            "See you later": "أراك لاحقاً",
            "Sweet dreams": "أحلام سعيدة",
            
            // Polite Phrases
            "Please": "من فضلك",
            "Thank you": "شكراً",
            "You're welcome": "على الرحب والسعة",
            "Sorry": "آسف",
            "Excuse me": "المعذرة",
            "No problem": "لا مشكلة",
            
            // Introductions
            "What's your name?": "ما اسمك؟",
            "My name is…": "اسمي...",
            "Nice to meet you": "تشرفنا",
            "Where are you from?": "من أين أنت؟",
            "I'm from...": "أنا من...",
            
            // Basic Questions
            "How are you?": "كيف حالك؟",
            "I'm fine, thanks": "أنا بخير، شكراً",
            "Do you speak Kurdish?": "هل تتحدث الكردية؟",
            "A little": "قليلاً",
            "I don't understand": "لا أفهم",
            
            // Yes/No & Confirmation
            "Yes": "نعم",
            "No": "لا",
            "Maybe": "ربما",
            "OK": "حسناً"
        ]
        return arabicTranslations[english] ?? english
    }
    
    private func getArabicExampleForQuiz(for englishExample: String) -> String {
        let arabicExamples = [
            // Family examples
            "My father is from Kurdistan.": "والدي من كردستان.",
            "My sister is studying.": "أختي تدرس.",
            "My grandmother tells nice stories.": "جدتي تحكي قصصاً جميلة.",
            "My son is at school.": "ابني في المدرسة.",
            "My partner is very nice.": "شريكي لطيف جداً.",
            "Example not available.": "المثال غير متوفر.",
            
            // Greetings examples
            "Good morning, I hope you have a good day.": "صباح الخير، أتمنى لك يوماً سعيداً.",
            "Good evening, my friend.": "مساء الخير، يا صديقي.",
            "Good night, sweet dreams.": "تصبح على خير، أحلام سعيدة.",
            "I'm leaving, goodbye.": "أنا ذاهب، مع السلامة.",
            "See you later, friend.": "أراك لاحقاً، يا صديق.",
            "Good night and sweet dreams.": "تصبح على خير وأحلام سعيدة.",
            
            // More examples...
            "Please, help me.": "من فضلك، ساعدني.",
            "Thank you for your help.": "شكراً لمساعدتك.",
            "You're welcome, it's my job.": "على الرحب والسعة، هذا عملي.",
            "Sorry, I was late.": "آسف، لقد تأخرت.",
            "Please, I want to speak with you.": "من فضلك، أريد أن أتحدث معك.",
            "You're welcome, you can always ask.": "على الرحب والسعة، يمكنك السؤال دائماً.",
            "Sorry, I made a mistake.": "آسف، لقد أخطأت.",
            "Excuse me, I want to leave.": "المعذرة، أريد أن أغادر.",
            "No problem, I can help you.": "لا مشكلة، يمكنني مساعدتك.",
            "What's your name? I want to get to know you.": "ما اسمك؟ أريد أن أتعرف عليك.",
            "My name is Ahmed.": "اسمي أحمد.",
            "Nice to meet you.": "تشرفنا.",
            "Where are you from? I'm from Kurdistan.": "من أين أنت؟ أنا من كردستان.",
            "I'm from Kurdistan.": "أنا من كردستان.",
            "How are you? I'm fine.": "كيف حالك؟ أنا بخير.",
            "I'm fine, thanks. How are you?": "أنا بخير، شكراً. كيف حالك؟",
            "Do you speak Kurdish? I want to learn.": "هل تتحدث الكردية؟ أريد أن أتعلم.",
            "I know a little Kurdish.": "أعرف القليل من الكردية.",
            "I don't understand, please say it again.": "لا أفهم، من فضلك قلها مرة أخرى.",
            "Yes, I want to.": "نعم، أريد ذلك.",
            "No, I don't want to.": "لا، لا أريد ذلك.",
            "Maybe, I'll think about it.": "ربما، سأفكر في الأمر.",
            "OK, let's do it like that.": "حسناً، لنفعل ذلك هكذا."
        ]
        return arabicExamples[englishExample] ?? englishExample
    }
}

// MARK: - Answer Option Button Component
struct AnswerOptionButton: View {
    let option: String
    let isSelected: Bool
    let isCorrect: Bool
    let showResult: Bool
    let audioEffectsManager: AudioEffectsManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            // Trigger feedback immediately when answer is selected
            if isCorrect {
                // This is the correct answer
                HapticManager.shared.successNotification()
                audioEffectsManager.playCorrectSound()
            } else {
                // This is a wrong answer
                HapticManager.shared.errorNotification()
                audioEffectsManager.playWrongSound()
            }
            
            // Then call the original onTap action
            onTap()
        }) {
            HStack {
                Text(option)
                    .font(.body.weight(.medium))
                    .foregroundColor(textColor)
                
                Spacer()
                
                if showResult && isSelected {
                    Image(systemName: resultIcon)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(buttonBackground)
        }
        .soundButtonStyle(.normal)
        .disabled(showResult)
    }
    
    private var textColor: Color {
        showResult && isSelected ? .white : .primary
    }
    
    private var resultIcon: String {
        isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
    }
    
    private var backgroundColor: Color {
        if showResult && isSelected {
            return isCorrect ? .green : .red
        }
        return Color(.systemBackground)
    }
}

// MARK: - Quiz Question Model
struct QuizQuestion {
    let kurdishWord: String
    let correctAnswer: String
    let options: [String]
}

// MARK: - Haptic Manager
class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    private var isHapticEnabled: Bool {
        return SettingsManager.shared.hapticFeedbackEnabled
    }
    
    func lightImpact() {
        guard isHapticEnabled else {
            print("🔇 Light haptic disabled by user settings")
            return
        }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func mediumImpact() {
        guard isHapticEnabled else {
            print("🔇 Medium haptic disabled by user settings")
            return
        }
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    func softImpact() {
        guard isHapticEnabled else {
            print("🔇 Soft haptic disabled by user settings")
            return
        }
        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
        impactFeedback.impactOccurred()
    }
    
    func successNotification() {
        guard isHapticEnabled else {
            print("🔇 Success haptic disabled by user settings")
            return
        }
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    func errorNotification() {
        guard isHapticEnabled else {
            print("🔇 Error haptic disabled by user settings")
            return
        }
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
}

// MARK: - Coming Soon View Component
struct ComingSoonView: View {
    let subtopic: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Lessons for \(subtopic) coming soon!")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Close") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.orange)
            .cornerRadius(12)
        }
        .padding()
    }
}

// MARK: - Greetings & Farewells Lesson View
struct GreetingsFarewellsLessonView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var progressManager: ProgressManager
    @StateObject private var audioManager = AudioManager.shared
    @State private var currentWordIndex = 0
    @State private var showTranslation = false
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    
    private let greetingsWords = [
        ("Roj baş", "Good morning", "Roj baş, ez hêvî dikim roja te baş be.", "Good morning, I hope you have a good day.", "Good_Morning"),
        ("Êvar baş", "Good evening", "Êvar baş, hevalno.", "Good evening, my friend.", "Good_evening"),
        ("Şev baş", "Good night", "Şev baş, xewa şirin bibî.", "Good night, sweet dreams.", "Good_night"),
        ("Bi xatirê te", "Goodbye", "Ez diçim, bi xatirê te.", "I'm leaving, goodbye.", "Goodbye"),
        ("Dîsa em ê bibînin", "See you later", "Dîsa em ê bibînin, heval.", "See you later, friend.", "see_you_later"),
        ("Xewn xweş", "Sweet dreams", "Şev baş û xewnên xweş.", "Good night and sweet dreams.", "Sweet_dreams")
    ]
    
    private var currentWord: (kurdish: String, english: String, kurdishExample: String, englishExample: String, imageName: String) {
        let word = greetingsWords[currentWordIndex]
        return (kurdish: word.0, english: word.1, kurdishExample: word.2, englishExample: word.3, imageName: word.4)
    }
    
    var body: some View {
        LessonViewTemplate(
            title: "Greetings & Farewells",
            words: greetingsWords,
            currentWordIndex: $currentWordIndex,
            showTranslation: $showTranslation,
            dragOffset: $dragOffset,
            isDragging: $isDragging,
            categoryId: "greetings_essentials",
            subtopicId: "greetings_farewells",
            favoritesManager: favoritesManager,
            progressManager: progressManager,
            audioManager: audioManager,
            dismiss: dismiss
        )
    }
}

// MARK: - Polite Phrases Lesson View
struct PolitePhrasesLessonView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var progressManager: ProgressManager
    @StateObject private var audioManager = AudioManager.shared
    @State private var currentWordIndex = 0
    @State private var showTranslation = false
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    
    private let politeWords = [
        ("Ji kerema xwe", "Please", "Ji kerema xwe, ez dixwazim bi te re biaxivim.", "Please, I want to speak with you.", "Please"),
        ("Spas", "Thank you", "Spas bo alîkariyê te.", "Thank you for your help.", "Thank_you"),
        ("Ser çavan", "You're welcome", "Ser çavan, tu her dikarî bipirse.", "You're welcome, you can always ask.", "You_are_welcome"),
        ("Biborî", "Sorry", "Biborî, ez şaşî kirim.", "Sorry, I made a mistake.", "sorry"),
        ("Biborî", "Excuse me", "Biborî, ez dixwazim derkevim.", "Excuse me, I want to leave.", "Excuse_me"),
        ("pirsgirêk tune", "No problem", "pirsgirêk tune, ez dikarim alîkariya te bikim.", "No problem, I can help you.", "No_problem")
    ]
    
    var body: some View {
        LessonViewTemplate(
            title: "Polite Phrases",
            words: politeWords,
            currentWordIndex: $currentWordIndex,
            showTranslation: $showTranslation,
            dragOffset: $dragOffset,
            isDragging: $isDragging,
            categoryId: "greetings_essentials",
            subtopicId: "polite_phrases",
            favoritesManager: favoritesManager,
            progressManager: progressManager,
            audioManager: audioManager,
            dismiss: dismiss
        )
    }
}

// MARK: - Introductions Lesson View
struct IntroductionsLessonView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var progressManager: ProgressManager
    @StateObject private var audioManager = AudioManager.shared
    @State private var currentWordIndex = 0
    @State private var showTranslation = false
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    
    private let introductionWords = [
        ("Navê te çi ye?", "What's your name?", "Navê te çi ye?", "What's your name?", "name_question"),
        ("Navê min ... e", "My name is…", "Navê min Bano ye.", "My name is Bano.", "my_name"),
        ("Ez kêfxweş bûm ku te nas kirim", "Nice to meet you", "Ez kêfxweş bûm ku te nas kirim.", "Nice to meet you.", "nice_to_meet"),
        ("Tu ji ku derê yî?", "Where are you from?", "Tu ji ku derê yî? Ez ji Afrînê me.", "Where are you from? I am from Afrin.", "where_from"),
        ("Ez ji ... me", "I'm from...", "Ez ji Kurdistanê me.", "I'm from Kurdistan.", "im_from")
    ]
    
    var body: some View {
        LessonViewTemplate(
            title: "Introductions",
            words: introductionWords,
            currentWordIndex: $currentWordIndex,
            showTranslation: $showTranslation,
            dragOffset: $dragOffset,
            isDragging: $isDragging,
            categoryId: "greetings_essentials",
            subtopicId: "introductions",
            favoritesManager: favoritesManager,
            progressManager: progressManager,
            audioManager: audioManager,
            dismiss: dismiss
        )
    }
}

// MARK: - Basic Questions Lesson View
struct BasicQuestionsLessonView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var progressManager: ProgressManager
    @StateObject private var audioManager = AudioManager.shared
    @State private var currentWordIndex = 0
    @State private var showTranslation = false
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    
    private let basicQuestionWords = [
        ("Tu çawa yî?", "How are you?", "Tu çawa yî, hevalno?", "How are you, my friend?", "how_are_you"),
        ("Ez baş im, spas", "I'm fine, thanks", "Ez baş im, spas bo pirsê te.", "I'm fine, thanks for asking.", "im_fine"),
        ("Tu çi?", "And you?", "Ez baş im. Tu çi?", "I'm fine. And you?", "and_you"),
        ("Tu bi Kurdî diaxivî?", "Do you speak Kurdish?", "Tu bi Kurdî diaxivî an bi Tirkî?", "Do you speak Kurdish or Turkish?", "speak_kurdish"),
        ("Hinek", "A little", "Ez bi Kurdî hinek dizanim.", "I know a little Kurdish.", "a_little"),
        ("Ez nizanim", "I don't understand", "Biborî, ez ev nabînim.", "Sorry, I don't understand this.", "dont_understand")
    ]
    
    var body: some View {
        LessonViewTemplate(
            title: "Basic Questions",
            words: basicQuestionWords,
            currentWordIndex: $currentWordIndex,
            showTranslation: $showTranslation,
            dragOffset: $dragOffset,
            isDragging: $isDragging,
            categoryId: "greetings_essentials",
            subtopicId: "basic_questions",
            favoritesManager: favoritesManager,
            progressManager: progressManager,
            audioManager: audioManager,
            dismiss: dismiss
        )
    }
}

// MARK: - Yes/No & Confirmation Lesson View
struct YesNoConfirmationLessonView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var progressManager: ProgressManager
    @StateObject private var audioManager = AudioManager.shared
    @State private var currentWordIndex = 0
    @State private var showTranslation = false
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    
    private let yesNoWords = [
        ("Erê", "Yes", "Erê, ez ê were.", "Yes, I will come.", "yes"),
        ("Na", "No", "Na, ez neçarim.", "No, I can't.", "no"),
        ("Dibe", "Maybe", "Dibe ez ê têbim.", "Maybe I'll join.", "maybe"),
        ("Baş e", "OK", "Baş e, em ê destpê bikin.", "OK, let's start.", "ok"),
        ("Ez nizanim", "I don't know", "Ez nizanim ku ew li ku ye.", "I don't know where he is.", "dont_know")
    ]
    
    var body: some View {
        LessonViewTemplate(
            title: "Yes / No & Confirmation",
            words: yesNoWords,
            currentWordIndex: $currentWordIndex,
            showTranslation: $showTranslation,
            dragOffset: $dragOffset,
            isDragging: $isDragging,
            categoryId: "greetings_essentials",
            subtopicId: "yes_no_confirmation",
            favoritesManager: favoritesManager,
            progressManager: progressManager,
            audioManager: audioManager,
            dismiss: dismiss
        )
    }
}

// MARK: - Lesson View Template
struct LessonViewTemplate: View {
    let title: String
    let words: [(String, String, String, String, String)]
    @Binding var currentWordIndex: Int
    @Binding var showTranslation: Bool
    @Binding var dragOffset: CGSize
    @Binding var isDragging: Bool
    let categoryId: String
    let subtopicId: String
    let favoritesManager: FavoritesManager
    let progressManager: ProgressManager
    let audioManager: AudioManager
    let dismiss: DismissAction
    
    private var currentWord: (kurdish: String, english: String, kurdishExample: String, englishExample: String, imageName: String, arabic: String, arabicExample: String) {
        let word = words[currentWordIndex]
        return (
            kurdish: word.0, 
            english: word.1, 
            kurdishExample: word.2, 
            englishExample: word.3, 
            imageName: word.4,
            arabic: getArabicTranslation(for: word.1),
            arabicExample: getArabicExample(for: word.3)
        )
    }
    
    // Helper functions for Arabic translations (temporary for supporting old data structure)
    private func getArabicTranslation(for english: String) -> String {
        let arabicTranslations = [
            // Greetings & Farewells
            "Good morning": "صباح الخير",
            "Good evening": "مساء الخير",
            "Good night": "تصبح على خير",
            "Goodbye": "مع السلامة",
            "See you later": "أراك لاحقاً",
            "Sweet dreams": "أحلام سعيدة",
            
            // Polite Phrases
            "Please": "من فضلك",
            "Thank you": "شكراً",
            "You're welcome": "على الرحب والسعة",
            "Sorry": "آسف",
            "Excuse me": "المعذرة",
            "No problem": "لا مشكلة",
            
            // Introductions
            "What's your name?": "ما اسمك؟",
            "My name is…": "اسمي...",
            "Nice to meet you": "تشرفنا",
            "Where are you from?": "من أين أنت؟",
            "I'm from...": "أنا من...",
            
            // Basic Questions
            "How are you?": "كيف حالك؟",
            "I'm fine, thanks": "أنا بخير، شكراً",
            "And you?": "وأنت؟",
            "Do you speak Kurdish?": "هل تتحدث الكردية؟",
            "A little": "قليلاً",
            "I don't understand": "لا أفهم",
            
            // Yes/No & Confirmation
            "Yes": "نعم",
            "No": "لا",
            "Maybe": "ربما",
            "OK": "حسناً",
            "I don't know": "لا أعرف"
        ]
        return arabicTranslations[english] ?? english
    }
    
    private func getArabicExample(for englishExample: String) -> String {
        let arabicExamples = [
            // Greetings Examples
            "Good morning, I hope you have a good day.": "صباح الخير، أتمنى لك يوماً سعيداً.",
            "Good evening, my friend.": "مساء الخير، يا صديقي.",
            "Good night, sweet dreams.": "تصبح على خير، أحلام سعيدة.",
            "I'm leaving, goodbye.": "أنا ذاهب، مع السلامة.",
            "See you later, friend.": "أراك لاحقاً، يا صديق.",
            "Good night and sweet dreams.": "تصبح على خير وأحلام سعيدة.",
            
            // Polite Phrases Examples
            "Please, I want to speak with you.": "من فضلك، أريد أن أتحدث معك.",
            "Thank you for your help.": "شكراً لمساعدتك.",
            "You're welcome, you can always ask.": "على الرحب والسعة، يمكنك السؤال دائماً.",
            "Sorry, I made a mistake.": "آسف، لقد ارتكبت خطأ.",
            "Excuse me, I want to leave.": "المعذرة، أريد أن أغادر.",
            "No problem, I can help you.": "لا مشكلة، يمكنني مساعدتك.",
            
            // Introductions Examples
            "What's your name?": "ما اسمك؟",
            "My name is Bano.": "اسمي بانو.",
            "Nice to meet you.": "تشرفنا.",
            "Where are you from? I am from Afrin.": "من أين أنت؟ أنا من عفرين.",
            "I'm from Syria.": "أنا من سوريا.",
            
            // Basic Questions Examples
            "How are you, my friend?": "كيف حالك، يا صديقي؟",
            "I'm fine, thanks for asking.": "أنا بخير، شكراً لسؤالك.",
            "I'm fine. And you?": "أنا بخير. وأنت؟",
            "Do you speak Kurdish or Turkish?": "هل تتحدث الكردية أم التركية؟",
            "I know a little Kurdish.": "أعرف القليل من الكردية.",
            "Sorry, I don't understand this.": "آسف، لا أفهم هذا.",
            
            // Yes/No Examples
            "Yes, I will come.": "نعم، سآتي.",
            "No, I can't.": "لا، لا أستطيع.",
            "Maybe I'll join.": "ربما سأنضم.",
            "OK, let's start.": "حسناً، لنبدأ.",
            "I don't know where he is.": "لا أعرف أين هو."
        ]
        return arabicExamples[englishExample] ?? englishExample
    }
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Progress indicator
                    VStack(spacing: 8) {
                        HStack {
                            ForEach(0..<words.count, id: \.self) { index in
                                Circle()
                                    .fill(index <= currentWordIndex ? Color.orange : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        
                        Text("\(currentWordIndex + 1) of \(words.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 10)
                    
                    // Main content
                    VStack(spacing: 30) {
                        // Interactive Flip Card
                        VStack(spacing: 20) {
                            FlipCard(
                                word: currentWord,
                                isFlipped: $showTranslation,
                                isFavorite: favoritesManager.isWordFavorited(kurdish: currentWord.kurdish, category: categoryId),
                                audioManager: audioManager,
                                onFavoriteToggle: {
                                    favoritesManager.toggleFavorite(
                                        kurdish: currentWord.kurdish,
                                        english: currentWord.english,
                                        arabic: currentWord.arabic,
                                        kurdishExample: currentWord.kurdishExample,
                                        englishExample: currentWord.englishExample,
                                        arabicExample: currentWord.arabicExample,
                                        imageName: currentWord.imageName,
                                        category: categoryId,
                                        subcategory: title
                                    )
                                },
                                onSpeakerTap: {
                                    let kurdishWord = currentWord.kurdish
                                    print("🔊 Playing pronunciation for: \(kurdishWord)")
                                    audioManager.speakKurdishWord(kurdishWord)
                                }
                            )
                            .frame(width: 280, height: 380)
                            .offset(dragOffset)
                            .scaleEffect(isDragging ? 0.95 : 1.0)
                            .opacity(isDragging ? 0.8 : 1.0)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    showTranslation.toggle()
                                }
                            }
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragOffset = value.translation
                                        isDragging = true
                                    }
                                    .onEnded { value in
                                        let swipeThreshold: CGFloat = 100
                                        let horizontalMovement = value.translation.width
                                        
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            dragOffset = .zero
                                            isDragging = false
                                        }
                                        
                                        // Swipe right - previous word
                                        if horizontalMovement > swipeThreshold && currentWordIndex > 0 {
                                            HapticManager.shared.softImpact()
                                            withAnimation(.easeInOut) {
                                                currentWordIndex -= 1
                                                showTranslation = false
                                            }
                                        }
                                        // Swipe left - next word
                                        else if horizontalMovement < -swipeThreshold && currentWordIndex < words.count - 1 {
                                            HapticManager.shared.softImpact()
                                            withAnimation(.easeInOut) {
                                                currentWordIndex += 1
                                                showTranslation = false
                                            }
                                        }
                                        // Complete lesson on last card swipe left
                                        else if horizontalMovement < -swipeThreshold && currentWordIndex == words.count - 1 {
                                            HapticManager.shared.mediumImpact()
                                            progressManager.markVocabularyAsViewed(categoryId: categoryId, subtopicId: subtopicId)
                                            StreakManager.shared.recordActivity()
                                            dismiss()
                                        }
                                    }
                            )
                            
                            // Swipe indicator hints
                            HStack(spacing: 40) {
                                if currentWordIndex > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.left")
                                            .font(.caption)
                                            .foregroundColor(.orange.opacity(0.6))
                                        Text("Swipe right")
                                            .font(.caption)
                                            .foregroundColor(.orange.opacity(0.6))
                                    }
                                } else {
                                    Color.clear.frame(height: 20)
                                }
                                
                                Spacer()
                                
                                if currentWordIndex < words.count - 1 {
                                    HStack(spacing: 4) {
                                        Text("Swipe left")
                                            .font(.caption)
                                            .foregroundColor(.orange.opacity(0.6))
                                        Image(systemName: "chevron.left")
                                            .font(.caption)
                                            .foregroundColor(.orange.opacity(0.6))
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Text("Swipe left to complete")
                                            .font(.caption)
                                            .foregroundColor(.green.opacity(0.8))
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .foregroundColor(.green.opacity(0.8))
                                    }
                                }
                            }
                            .padding(.horizontal, 40)
                        }
                        .animation(.easeInOut, value: currentWordIndex)
                        .onChange(of: currentWordIndex) { _, newIndex in
                            // Auto-play audio when word changes if enabled in settings
                            if SettingsManager.shared.autoPlayWordAudio {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // Small delay for smooth animation
                                    let kurdishWord = words[newIndex].0
                                    print("🔊 Auto-playing word: \(kurdishWord)")
                                    audioManager.speakKurdishWord(kurdishWord)
                                }
                            }
                        }
                        .onAppear {
            StreakManager.shared.startLearningSession()
                            // Auto-play first word when lesson loads if enabled in settings
                            if SettingsManager.shared.autoPlayWordAudio {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Small delay for view to settle
                                    let kurdishWord = words[currentWordIndex].0
                                    print("🔊 Auto-playing initial word: \(kurdishWord)")
                                    audioManager.speakKurdishWord(kurdishWord)
                                }
                            }
        }
        .onDisappear {
            StreakManager.shared.endLearningSession()
                        }
                        
                        // Navigation buttons
                        HStack(spacing: 20) {
                            if currentWordIndex > 0 {
                                Button("Previous") {
                                    HapticManager.shared.lightImpact()
                                    withAnimation(.easeInOut) {
                                        currentWordIndex -= 1
                                        showTranslation = false
                                    }
                                }
                                .soundButtonStyle(.normal)
                                .font(.headline)
                                .foregroundColor(.orange)
                                .frame(minWidth: 120, minHeight: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange, lineWidth: 2)
                                        .fill(Color.clear)
                                )
                            }
                            
                            Spacer()
                            
                            Button(currentWordIndex < words.count - 1 ? "Next" : "Complete") {
                                HapticManager.shared.lightImpact()
                                withAnimation(.easeInOut) {
                                    if currentWordIndex < words.count - 1 {
                                        currentWordIndex += 1
                                        showTranslation = false
                                    } else {
                                        progressManager.markVocabularyAsViewed(categoryId: categoryId, subtopicId: subtopicId)
                                        StreakManager.shared.recordActivity()
                                        dismiss()
                                    }
                                }
                            }
                            .soundButtonStyle(currentWordIndex < words.count - 1 ? .normal : .action)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(minWidth: 120, minHeight: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange)
                            )
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                    }
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color.orange.opacity(0.02)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthenticationManager())
} 