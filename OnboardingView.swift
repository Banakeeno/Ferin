//
//  OnboardingView.swift
//  Ferin
//
//  Created by Bankin ALO on 31.05.25.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showGoalSelection = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Header Section
                VStack(spacing: 24) {
                    // Top spacing for safe area
                    Spacer()
                        .frame(height: 20)
                    
                    // Debug indicator - only show in debug builds when skip auth is enabled
                    #if DEBUG
                    if DebugManager.shared.skipAuthentication {
                        HStack {
                            Image(systemName: "ladybug.fill")
                                .foregroundColor(.orange)
                            Text("DEBUG MODE: Authentication Skipped")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.bottom, 16)
                    }
                    #endif
                    
                    // Progress indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                    
                    // App Icon
                    Image(systemName: "book.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.orange)
                    
                    // Welcome Message
                    VStack(spacing: 16) {
                        Text("Let's Get Started")
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 8) {
                            Text("👋 Welcome to Ferîn!")
                                .font(.title2.bold())
                                .foregroundColor(.primary)
                            
                            Text("We're happy you're here. Let's set up your Ferîn journey.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
                
                // Content Section
                VStack(spacing: 24) {
                    // Quick Setup Options
                    VStack(spacing: 16) {
                        Text("Quick Setup")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            SetupOptionCard(
                                icon: "target",
                                title: "Choose your goals",
                                subtitle: "What do you want to achieve?",
                                isCompleted: false
                            )
                            
                            SetupOptionCard(
                                icon: "person.circle",
                                title: "Choose your level",
                                subtitle: "Beginner • Intermediate • Advanced",
                                isCompleted: false
                            )
                            
                            SetupOptionCard(
                                icon: "speaker.wave.2",
                                title: "Set learning preferences",
                                subtitle: "Audio, visual, or mixed learning",
                                isCompleted: false
                            )
                            
                            SetupOptionCard(
                                icon: "clock",
                                title: "Daily goal",
                                subtitle: "How much time do you want to spend?",
                                isCompleted: false
                            )
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // Continue Button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showGoalSelection = true
                            }
                        }) {
                            Text("Continue Setup")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                        
                        // Skip Button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showGoalSelection = true
                            }
                        }) {
                            Text("Skip for now")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
        }
        .safeAreaInset(edge: .top) {
            // Invisible spacer to account for debug controls in debug builds
            #if DEBUG
            Color.clear.frame(height: 20)
            #endif
        }
        .fullScreenCover(isPresented: $showGoalSelection) {
            GoalSelectionView()
                .environmentObject(authManager)
        }
    }
    
    private func getUserName() -> String {
        guard let user = authManager.user else { return "Friend" }
        
        // Try to get name from display name first
        if let displayName = user.displayName, !displayName.isEmpty {
            return displayName.components(separatedBy: " ").first ?? "Friend"
        }
        
        // Fallback to email username
        if let email = user.email {
            let username = email.components(separatedBy: "@").first ?? "Friend"
            return username.capitalized
        }
        
        return "Friend"
    }
}

struct SetupOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 24, height: 24)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "chevron.right")
                .font(.title3)
                .foregroundColor(isCompleted ? .green : .secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthenticationManager())
} 