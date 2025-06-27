//
//  StepByStepOnboardingView.swift
//  Ferin
//
//  Created by Bankin ALO on 31.05.25.
//

import SwiftUI

// MARK: - Onboarding Data Models
struct OnboardingQuestion {
    let id: Int
    let title: String
    let options: [OnboardingOption]
}

struct OnboardingOption {
    let id: String
    let title: String
    let icon: String?
}

// MARK: - User Responses
class OnboardingResponses: ObservableObject {
    @Published var motivation: String? = nil
    @Published var level: String? = nil
    @Published var learningStyle: String? = nil
    @Published var dailyGoal: String? = nil
    
    func reset() {
        motivation = nil
        level = nil
        learningStyle = nil
        dailyGoal = nil
    }
}

// MARK: - Main Onboarding View
struct StepByStepOnboardingView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var responses = OnboardingResponses()
    @State private var currentStep: Int = 0
    @State private var isCompleted = false
    
    private let questions = [
        OnboardingQuestion(
            id: 0,
            title: "What brings you to Kurdish?",
            options: [
                OnboardingOption(id: "travel", title: "Learn for travel", icon: "airplane"),
                OnboardingOption(id: "family", title: "Connect with family", icon: "person.2"),
                OnboardingOption(id: "work", title: "For work", icon: "briefcase"),
                OnboardingOption(id: "fun", title: "Just for fun", icon: "heart")
            ]
        ),
        OnboardingQuestion(
            id: 1,
            title: "What's your Kurdish level?",
            options: [
                OnboardingOption(id: "beginner", title: "Complete beginner", icon: "1.circle"),
                OnboardingOption(id: "some_words", title: "I know some words", icon: "2.circle"),
                OnboardingOption(id: "intermediate", title: "I can have conversations", icon: "3.circle"),
                OnboardingOption(id: "advanced", title: "I'm pretty fluent", icon: "4.circle")
            ]
        ),
        OnboardingQuestion(
            id: 2,
            title: "How do you learn best?",
            options: [
                OnboardingOption(id: "visual", title: "Visual (reading, flashcards)", icon: "eye"),
                OnboardingOption(id: "audio", title: "Audio (listening, speaking)", icon: "speaker.wave.2"),
                OnboardingOption(id: "mixed", title: "Mix of both", icon: "square.grid.2x2"),
                OnboardingOption(id: "interactive", title: "Interactive exercises", icon: "gamecontroller")
            ]
        ),
        OnboardingQuestion(
            id: 3,
            title: "Daily learning goal?",
            options: [
                OnboardingOption(id: "5min", title: "5 minutes", icon: "clock"),
                OnboardingOption(id: "10min", title: "10 minutes", icon: "clock"),
                OnboardingOption(id: "20min", title: "20 minutes", icon: "clock"),
                OnboardingOption(id: "30min", title: "30+ minutes", icon: "clock")
            ]
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top Section with Progress and Close
                VStack(spacing: 20) {
                    // Header with close button
                    HStack {
                        Spacer()
                        Button(action: {
                            // Handle close action
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Progress Indicator
                    ProgressIndicator(currentStep: currentStep, totalSteps: questions.count)
                }
                
                Spacer()
                
                // Question Content
                if currentStep < questions.count {
                    QuestionView(
                        question: questions[currentStep],
                        selectedAnswer: getSelectedAnswer(for: currentStep),
                        onSelectionChanged: { answerId in
                            setAnswer(for: currentStep, answerId: answerId)
                        }
                    )
                }
                
                Spacer()
                
                // Continue Button
                VStack(spacing: 20) {
                    Button(action: {
                        handleContinue()
                    }) {
                        Text(currentStep == questions.count - 1 ? "Get Started" : "Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(canContinue() ? Color.orange : Color.gray.opacity(0.5))
                            )
                    }
                    .disabled(!canContinue())
                    .padding(.horizontal, 20)
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 20)
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $isCompleted) {
            MainLearningView()
                .environmentObject(authManager)
        }
    }
    
    // MARK: - Helper Methods
    private func getSelectedAnswer(for step: Int) -> String? {
        switch step {
        case 0: return responses.motivation
        case 1: return responses.level
        case 2: return responses.learningStyle
        case 3: return responses.dailyGoal
        default: return nil
        }
    }
    
    private func setAnswer(for step: Int, answerId: String) {
        switch step {
        case 0: responses.motivation = answerId
        case 1: responses.level = answerId
        case 2: responses.learningStyle = answerId
        case 3: responses.dailyGoal = answerId
        default: break
        }
    }
    
    private func canContinue() -> Bool {
        return getSelectedAnswer(for: currentStep) != nil
    }
    
    private func handleContinue() {
        if currentStep < questions.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
        } else {
            // Onboarding completed
            isCompleted = true
        }
    }
}

// MARK: - Progress Indicator Component
struct ProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .scaleEffect(step == currentStep ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
    }
}

// MARK: - Question View Component
struct QuestionView: View {
    let question: OnboardingQuestion
    let selectedAnswer: String?
    let onSelectionChanged: (String) -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            // Question Title
            Text(question.title)
                .font(.largeTitle.bold())
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // Answer Options
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(question.options, id: \.id) { option in
                    AnswerButton(
                        option: option,
                        isSelected: selectedAnswer == option.id,
                        action: {
                            onSelectionChanged(option.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Answer Button Component
struct AnswerButton: View {
    let option: OnboardingOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let icon = option.icon {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .orange : .secondary)
                }
                
                Text(option.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(isSelected ? .orange : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange.opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.orange : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .soundButtonStyle(.normal)
    }
}

// MARK: - Placeholder Main Learning View
struct MainLearningView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        MainTabView()
            .environmentObject(authManager)
    }
}

#Preview {
    StepByStepOnboardingView()
        .environmentObject(AuthenticationManager())
} 