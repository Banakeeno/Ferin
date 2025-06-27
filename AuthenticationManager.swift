//
//  AuthenticationManager.swift
//  Ferin
//
//  Created by Bankin ALO on 31.05.25.
//

import Foundation
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        self.user = Auth.auth().currentUser
        
        // Listen for authentication state changes and store the handle
        self.authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user = user
            }
        }
    }
    
    deinit {
        // Remove the listener when the object is deallocated
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Email/Password Authentication
    
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = ""
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.user = result.user
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = ""
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.user = result.user
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() async {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase client ID not found"
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Could not find root view controller"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Failed to get ID token from Google"
                isLoading = false
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                         accessToken: result.user.accessToken.tokenString)
            
            let authResult = try await Auth.auth().signIn(with: credential)
            self.user = authResult.user
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            self.user = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = ""
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
} 