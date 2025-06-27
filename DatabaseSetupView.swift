//
//  DatabaseSetupView.swift
//  Ferin
//
//  Created by Bankin ALO on 31.05.25.
//

import SwiftUI

struct DatabaseSetupView: View {
    @StateObject private var vocabularyManager = FirestoreVocabularyManager()
    @State private var isLoading = false
    @State private var setupComplete = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "externaldrive.fill.badge.plus")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                VStack(spacing: 16) {
                    Text("Database Setup")
                        .font(.largeTitle.bold())
                    
                    Text("Set up your Firestore database with categories, subcategories, and vocabulary")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    if !setupComplete {
                        Button(action: {
                            Task {
                                await setupDatabase()
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                }
                                Text(isLoading ? "Setting up..." : "Setup Database")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)
                    } else {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Database setup complete!")
                                    .foregroundColor(.green)
                            }
                            .font(.headline)
                            
                            Button("Setup Again") {
                                setupComplete = false
                                errorMessage = ""
                            }
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        }
                    }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func setupDatabase() async {
        isLoading = true
        errorMessage = ""
        
        do {
            try await vocabularyManager.setupCompleteDatabase()
            setupComplete = true
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

#Preview {
    DatabaseSetupView()
} 