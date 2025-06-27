//
//  GoalSelectionView.swift
//  Ferin
//
//  Created by Bankin ALO on 31.05.25.
//

import SwiftUI

struct GoalSelectionView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedGoals: Set<LearningGoal> = []
    @State private var showMainApp = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header Section
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Progress indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                    
                    // Title
                    VStack(spacing: 16) {
                        Text("What's your goal?")
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                        
                        Text("Choose what you want to achieve with Ferîn. You can select multiple goals.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    
                    Spacer()
                }
                .frame(height: geometry.size.height * 0.4)
                
                // Content Section
                VStack(spacing: 24) {
                    // Goal Options
                    VStack(spacing: 16) {
                        GoalOptionCard(
                            goal: .speakWithFamily,
                            isSelected: selectedGoals.contains(.speakWithFamily)
                        ) {
                            toggleGoal(.speakWithFamily)
                        }
                        
                        GoalOptionCard(
                            goal: .understandSongs,
                            isSelected: selectedGoals.contains(.understandSongs)
                        ) {
                            toggleGoal(.understandSongs)
                        }
                        
                        GoalOptionCard(
                            goal: .readingWriting,
                            isSelected: selectedGoals.contains(.readingWriting)
                        ) {
                            toggleGoal(.readingWriting)
                        }
                        
                        GoalOptionCard(
                            goal: .dailyWords,
                            isSelected: selectedGoals.contains(.dailyWords)
                        ) {
                            toggleGoal(.dailyWords)
                        }
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // Continue Button
                        Button {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showMainApp = true
                            }
                        } label: {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(selectedGoals.isEmpty ? Color.gray : Color.orange)
                                .cornerRadius(12)
                        }
                        .disabled(selectedGoals.isEmpty)
                        
                        // Back Button
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Back")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .frame(height: geometry.size.height * 0.6)
            }
        }
        .fullScreenCover(isPresented: $showMainApp) {
            AuthenticatedView()
                .environmentObject(authManager)
        }
    }
    
    private func toggleGoal(_ goal: LearningGoal) {
        if selectedGoals.contains(goal) {
            selectedGoals.remove(goal)
        } else {
            selectedGoals.insert(goal)
        }
    }
}

enum LearningGoal: String, CaseIterable {
    case speakWithFamily = "speak_family"
    case understandSongs = "understand_songs"
    case readingWriting = "reading_writing"
    case dailyWords = "daily_words"
    
    var title: String {
        switch self {
        case .speakWithFamily:
            return "I want to speak Kurdish with my family"
        case .understandSongs:
            return "I want to understand Kurdish songs"
        case .readingWriting:
            return "I want to improve my reading and writing"
        case .dailyWords:
            return "I want to learn basic words for daily use"
        }
    }
    
    var icon: String {
        switch self {
        case .speakWithFamily:
            return "person.2.fill"
        case .understandSongs:
            return "music.note"
        case .readingWriting:
            return "book.pages"
        case .dailyWords:
            return "text.bubble"
        }
    }
}

struct GoalOptionCard: View {
    let goal: LearningGoal
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: goal.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .orange)
                    .frame(width: 24, height: 24)
                
                // Content
                Text(goal.title)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(isSelected ? Color.orange : Color.gray.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.gray.opacity(0.2), lineWidth: 2)
            )
        }
        .soundButtonStyle(.normal)
    }
}

extension LearningGoal: Hashable {}

#Preview {
    GoalSelectionView()
        .environmentObject(AuthenticationManager())
} 