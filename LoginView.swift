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
    @State private var isSignUp = false
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
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        // Welcome Text
                        VStack(spacing: 8) {
                            Text("Welcome to Ferin")
                                .font(.title.bold())
                                .foregroundColor(.primary)
                            
                            Text(isSignUp ? "Create your account" : "Sign in to continue")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .frame(height: geometry.size.height * 0.4)
                    
                    // Form Section
                    VStack(spacing: 20) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Enter your email", text: $email)
                                .textFieldStyle(CustomTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Error Message
                        if !authManager.errorMessage.isEmpty {
                            Text(authManager.errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal)
                        }
                        
                        // Sign In/Up Button
                        Button(action: {
                            Task {
                                if isSignUp {
                                    await authManager.signUp(email: email, password: password)
                                } else {
                                    await authManager.signIn(email: email, password: password)
                                }
                            }
                        }) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                        
                        // Forgot Password
                        if !isSignUp {
                            Button("Forgot Password?") {
                                showingPasswordReset = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray.opacity(0.3))
                            
                            Text("OR")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray.opacity(0.3))
                        }
                        .padding(.vertical)
                        
                        // Google Sign In
                        Button(action: {
                            Task {
                                await authManager.signInWithGoogle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.primary)
                                
                                Text("Continue with Google")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .disabled(authManager.isLoading)
                        
                        // Toggle Sign Up/In
                        HStack {
                            Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button(isSignUp ? "Sign In" : "Sign Up") {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isSignUp.toggle()
                                    authManager.errorMessage = ""
                                }
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                        }
                        .padding(.top)
                    }
                    .padding(.horizontal, 30)
                    .frame(minHeight: geometry.size.height * 0.6)
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

// Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
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
                        .textFieldStyle(CustomTextFieldStyle())
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
                    .padding()
                    .background(Color.blue)
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