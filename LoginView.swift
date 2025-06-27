//
//  LoginView.swift
//  Ferin
//
//  Created by Bankin ALO on 31.05.25.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthenticationManager()
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = true
    @State private var showingPasswordReset = false
    @State private var resetEmail = ""
    @State private var showingSuccessAlert = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    VStack(spacing: 20) {
                        Spacer()
                        
                        // App Logo/Icon
                        Image(systemName: "book.circle.fill")
                            .font(.system(size: 100))
                            .foregroundColor(.orange)
                        
                        // Welcome Text
                        VStack(spacing: 12) {
                            Text("Welcome to Ferin")
                                .font(.largeTitle.bold())
                                .foregroundColor(.primary)
                            
                            Text("Learn Kurdish your way —\nthrough words, voice, and music.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        
                        Spacer()
                    }
                    .frame(height: geometry.size.height * 0.45)
                    
                    // Form Section
                    VStack(spacing: 24) {
                        // Title
                        Text(isSignUp ? "Sign up and start your journey" : "Welcome back")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            TextField("you@example.com", text: $email)
                                .textFieldStyle(ModernTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        
                        // Password Field (only show when not in initial signup mode)
                        if !isSignUp || !password.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                SecureField("Enter your password", text: $password)
                                    .textFieldStyle(ModernTextFieldStyle())
                            }
                        }
                        
                        // Error Message
                        if !authManager.errorMessage.isEmpty {
                            Text(authManager.errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal)
                        }
                        
                        // Continue Button
                        Button {
                            if isSignUp && password.isEmpty {
                                // First step of signup - just show password field
                                password = " " // Trigger password field to appear
                            } else {
                                Task {
                                    if isSignUp {
                                        await authManager.signUp(email: email, password: password)
                                    } else {
                                        await authManager.signIn(email: email, password: password)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Text("Continue")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                        .disabled(authManager.isLoading || email.isEmpty)
                        
                        // OR Divider
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray.opacity(0.3))
                            
                            Text("or")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                            
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray.opacity(0.3))
                        }
                        .padding(.vertical, 8)
                        
                        // Social Sign In Buttons
                        VStack(spacing: 12) {
                            // Google Sign In
                            Button {
                                Task {
                                    await authManager.signInWithGoogle()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "globe")
                                        .foregroundColor(.primary)
                                    
                                    Text("Sign up with Google")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.clear)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(authManager.isLoading)
                            
                            // Apple Sign In
                            Button {
                                // TODO: Implement Apple Sign In
                            } label: {
                                HStack {
                                    Image(systemName: "applelogo")
                                        .foregroundColor(.primary)
                                    
                                    Text("Sign up with Apple")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.clear)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(authManager.isLoading)
                        }
                        
                        // Terms and Privacy Policy
                        Text("By joining, I agree to Ferin's **Terms** and **Privacy Policy**.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        // Toggle Sign Up/In
                        HStack {
                            Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button(isSignUp ? "Log in" : "Sign up") {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isSignUp.toggle()
                                    password = "" // Reset password field
                                    authManager.errorMessage = ""
                                }
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.orange)
                        }
                        .padding(.top)
                    }
                    .padding(.horizontal, 30)
                    .frame(minHeight: geometry.size.height * 0.55)
                }
            }
        }
        .sheet(isPresented: $showingPasswordReset) {
            PasswordResetView(authManager: authManager, resetEmail: $resetEmail, showingSuccessAlert: $showingSuccessAlert)
        }
        .alert("Password Reset Sent", isPresented: $showingSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("If an account with that email exists, we've sent a password reset link.")
        }
    }
}

// Modern Text Field Style
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

// Password Reset View
struct PasswordResetView: View {
    @ObservedObject var authManager: AuthenticationManager
    @Binding var resetEmail: String
    @Binding var showingSuccessAlert: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Reset Password")
                    .font(.title.bold())
                    .padding(.top)
                
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.headline)
                    
                    TextField("Enter your email", text: $resetEmail)
                        .textFieldStyle(ModernTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                .padding(.horizontal)
                
                if !authManager.errorMessage.isEmpty {
                    Text(authManager.errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    Task {
                        await authManager.resetPassword(email: resetEmail)
                        if authManager.errorMessage.isEmpty {
                            showingSuccessAlert = true
                            dismiss()
                        }
                    }
                }) {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Text("Send Reset Link")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .cornerRadius(12)
                }
                .disabled(authManager.isLoading || resetEmail.isEmpty)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView()
} 