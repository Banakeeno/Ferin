//
//  MainAppView.swift
//  Ferin
//
//  Created by Bankin ALO on 31.05.25.
//

import SwiftUI

struct MainAppView: View {
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some View {
        Group {
            if authManager.user != nil {
                // User is signed in, show main app content
                AuthenticatedView()
                    .environmentObject(authManager)
            } else {
                // User is not signed in, show login
                LoginView()
            }
        }
    }
}

struct AuthenticatedView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("Welcome!")
                        .font(.title.bold())
                    
                    Text("You're successfully signed in to Ferin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // User Info
                if let user = authManager.user {
                    VStack(spacing: 10) {
                        Text("User Information")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Email:")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(user.email ?? "N/A")
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("UID:")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(user.uid)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            
                            HStack {
                                Text("Provider:")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(user.providerData.first?.providerID ?? "Unknown")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                // Sign Out Button
                Button(action: {
                    authManager.signOut()
                }) {
                    Text("Sign Out")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Ferin")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    MainAppView()
}