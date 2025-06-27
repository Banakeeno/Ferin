//
//  VocabularyLessonView.swift
//  Ferin
//
//  Created by Bankin ALO on 31.05.25.
//

import SwiftUI
import FirebaseFirestore

// MARK: - Lesson Data Model
struct VocabularyLesson: Codable, Identifiable {
    var id: String
    let kurdishWord: String
    let englishWord: String
    let arabicWord: String
    let kurdishExample: String
    let englishExample: String
    let arabicExample: String
    let imageUrl: String
    let type: String
    let createdAt: Date?
    
    init(id: String, kurdishWord: String, englishWord: String, arabicWord: String, kurdishExample: String, 
         englishExample: String, arabicExample: String, imageUrl: String, type: String) {
        self.id = id
        self.kurdishWord = kurdishWord
        self.englishWord = englishWord
        self.arabicWord = arabicWord
        self.kurdishExample = kurdishExample
        self.englishExample = englishExample
        self.arabicExample = arabicExample
        self.imageUrl = imageUrl
        self.type = type
        self.createdAt = Date()
    }
    
    // Convenience methods for learning language support
    func translation(for learningLanguage: LearningLanguageManager.LearningLanguage) -> String {
        switch learningLanguage {
        case .english: return englishWord
        case .arabic: return arabicWord
        }
    }
    
    func example(for learningLanguage: LearningLanguageManager.LearningLanguage) -> String {
        switch learningLanguage {
        case .english: return englishExample
        case .arabic: return arabicExample
        }
    }
}

// MARK: - Lesson Manager
@MainActor
class VocabularyLessonManager: ObservableObject {
    @Published var lessons: [VocabularyLesson] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let db = Firestore.firestore()
    
    func fetchLessons(categoryId: String, subcategoryId: String) async {
        isLoading = true
        errorMessage = ""
        
        do {
            let snapshot = try await db.collection("categories")
                .document(categoryId)
                .collection("subcategories")
                .document(subcategoryId)
                .collection("lessons")
                .order(by: "kurdishWord")
                .getDocuments()
            
            let fetchedLessons = snapshot.documents.compactMap { document -> VocabularyLesson? in
                do {
                    let data = document.data()
                    let decoder = Firestore.Decoder()
                    return try decoder.decode(VocabularyLesson.self, from: data)
                } catch {
                    print("Error decoding lesson: \(error)")
                    return nil
                }
            }
            
            self.lessons = fetchedLessons
            
            if lessons.isEmpty {
                errorMessage = "Lessons not available. Please check your connection or setup."
            }
            
        } catch {
            errorMessage = "Failed to fetch lessons: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

// MARK: - Main Vocabulary Lesson View
struct VocabularyLessonView: View {
    let categoryId: String
    let subcategoryId: String
    let subcategoryTitle: String
    
    @StateObject private var lessonManager = VocabularyLessonManager()
    @EnvironmentObject var learningLanguageManager: LearningLanguageManager
    @State private var currentLessonIndex = 0
    @State private var selectedAnswer: String? = nil
    @State private var showFeedback = false
    @State private var isCorrect = false
    @State private var quizOptions: [String] = []
    @State private var showCompletion = false
    @Environment(\.dismiss) private var dismiss
    
    private let englishDistractors = [
        "Father", "Mother", "Sister", "Brother", "Uncle", "Aunt", "Son", "Daughter",
        "Grandfather", "Grandmother", "Cousin", "Nephew", "Niece", "Partner", "Spouse",
        "Friend", "Teacher", "Student", "Doctor", "Child", "Parent", "Relative"
    ]
    
    private let arabicDistractors = [
        "الأب", "الأم", "الأخت", "الأخ", "العم", "العمة", "الابن", "الابنة",
        "الجد", "الجدة", "ابن العم", "ابن الأخ", "بنت الأخت", "الشريك", "الزوج",
        "الصديق", "المعلم", "الطالب", "الطبيب", "الطفل", "الوالد", "القريب"
    ]
    
    var currentLesson: VocabularyLesson? {
        guard currentLessonIndex < lessonManager.lessons.count else { return nil }
        return lessonManager.lessons[currentLessonIndex]
    }
    
    var body: some View {
        NavigationView {
            Group {
                if lessonManager.isLoading {
                    loadingView
                } else if !lessonManager.errorMessage.isEmpty {
                    errorView
                } else if let lesson = currentLesson {
                    lessonContentView(lesson: lesson)
                } else if showCompletion {
                    completionView
                }
            }
            .navigationTitle(subcategoryTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !lessonManager.lessons.isEmpty {
                        Text("\(currentLessonIndex + 1) / \(lessonManager.lessons.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .task {
            await lessonManager.fetchLessons(categoryId: categoryId, subcategoryId: subcategoryId)
            generateQuizOptions()
        }
        .onAppear {
            StreakManager.shared.startLearningSession()
        }
        .onDisappear {
            StreakManager.shared.endLearningSession()
        }
    }
    
    // MARK: - Lesson Content View
    private func lessonContentView(lesson: VocabularyLesson) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 30) {
                // Header Section
                VStack(spacing: 16) {
                    // Kurdish Word
                    Text(lesson.kurdishWord)
                        .font(.largeTitle.bold())
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                    
                    // Kurdish Example
                    Text(lesson.kurdishExample)
                        .font(.title3)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                // Image Section
                VStack(spacing: 16) {
                    AsyncImage(url: URL(string: lesson.imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                    Text("Image not available")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            )
                    }
                    .frame(maxHeight: 200)
                    .cornerRadius(16)
                    
                    // Listen Button (Placeholder)
                    Button(action: {
                        // TODO: Add audio functionality
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.wave.2")
                            Text("Listen")
                        }
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(true) // Disabled for now
                }
                
                // Quiz Section
                VStack(spacing: 20) {
                    Text(learningLanguageManager.currentLearningLanguage == .english ? 
                         "What does this mean in English?" : 
                         "ماذا يعني هذا بالعربية؟")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Quiz Options
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(quizOptions, id: \.self) { option in
                            QuizOptionButton(
                                text: option,
                                isSelected: selectedAnswer == option,
                                isCorrect: showFeedback ? option == lesson.translation(for: learningLanguageManager.currentLearningLanguage) : nil,
                                action: {
                                    if !showFeedback {
                                        selectedAnswer = option
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Check Answer / Next Button
                VStack(spacing: 16) {
                    if !showFeedback {
                        Button {
                            checkAnswer(lesson: lesson)
                        } label: {
                            Text("Check Answer")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedAnswer != nil ? Color.orange : Color.gray)
                        .cornerRadius(12)
                        }
                        .disabled(selectedAnswer == nil)
                    } else {
                        // Feedback
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isCorrect ? .green : .red)
                                Text(isCorrect ? "Correct!" : "Incorrect")
                                    .font(.headline)
                                    .foregroundColor(isCorrect ? .green : .red)
                            }
                            
                            if !isCorrect {
                                Text("Correct answer: \(lesson.translation(for: learningLanguageManager.currentLearningLanguage))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(lesson.example(for: learningLanguageManager.currentLearningLanguage))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .italic()
                        }
                        
                        // Next Button
                        Button {
                            nextLesson()
                        } label: {
                            Text(currentLessonIndex < lessonManager.lessons.count - 1 ? "Next Lesson" : "Complete")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Color.clear.frame(height: 20)
            }
        }
    }
    
    // MARK: - Supporting Views
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading lessons...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text(lessonManager.errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                Task {
                    await lessonManager.fetchLessons(categoryId: categoryId, subcategoryId: subcategoryId)
                    generateQuizOptions()
                }
            } label: {
                Text("Try Again")
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.orange)
            .cornerRadius(12)
            }
        }
        .padding()
    }
    
    private var completionView: some View {
        VStack(spacing: 30) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            VStack(spacing: 16) {
                Text("Congratulations!")
                    .font(.largeTitle.bold())
                
                Text("You've completed all \(lessonManager.lessons.count) family member lessons!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                dismiss()
            } label: {
                Text("Back to Categories")
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    private func generateQuizOptions() {
        guard let lesson = currentLesson else { return }
        
        let correctAnswer = lesson.translation(for: learningLanguageManager.currentLearningLanguage)
        var options = [correctAnswer]
        
        // Use different distractors based on learning language
        let currentDistractors = learningLanguageManager.currentLearningLanguage == .english ? 
            englishDistractors : arabicDistractors
        
        var availableDistractors = currentDistractors.filter { $0 != correctAnswer }
        
        while options.count < 4 && !availableDistractors.isEmpty {
            if let randomDistractor = availableDistractors.randomElement() {
                options.append(randomDistractor)
                availableDistractors.removeAll { $0 == randomDistractor }
            }
        }
        
        quizOptions = options.shuffled()
    }
    
    private func checkAnswer(lesson: VocabularyLesson) {
        isCorrect = selectedAnswer == lesson.translation(for: learningLanguageManager.currentLearningLanguage)
        showFeedback = true
    }
    
    private func nextLesson() {
        if currentLessonIndex < lessonManager.lessons.count - 1 {
            currentLessonIndex += 1
            selectedAnswer = nil
            showFeedback = false
            generateQuizOptions()
        } else {
            showCompletion = true
        }
    }
}

// MARK: - Quiz Option Button
struct QuizOptionButton: View {
    let text: String
    let isSelected: Bool
    let isCorrect: Bool?
    let action: () -> Void
    
    var backgroundColor: Color {
        if let isCorrect = isCorrect {
            if isCorrect {
                return .green.opacity(0.2)
            } else if isSelected {
                return .red.opacity(0.2)
            }
        } else if isSelected {
            return .orange.opacity(0.2)
        }
        return Color.gray.opacity(0.05)
    }
    
    var borderColor: Color {
        if let isCorrect = isCorrect {
            if isCorrect {
                return .green
            } else if isSelected {
                return .red
            }
        } else if isSelected {
            return .orange
        }
        return Color.gray.opacity(0.2)
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(borderColor, lineWidth: isSelected || isCorrect != nil ? 2 : 1)
                        )
                )
        }
        .soundButtonStyle(.normal)
    }
}

#Preview {
    VocabularyLessonView(
        categoryId: "people_relationships",
        subcategoryId: "family_members",
        subcategoryTitle: "Family Members"
    )
} 