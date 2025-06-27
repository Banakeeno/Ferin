//
//  DebugManager.swift
//  Ferin
//
//  Created by Bankin ALO on 31.05.25.
//

import Foundation
import SwiftUI

@MainActor
class DebugManager: ObservableObject {
    @Published var skipAuthentication: Bool = false {
        didSet {
            UserDefaults.standard.set(skipAuthentication, forKey: "skipAuthentication")
        }
    }
    
    static let shared = DebugManager()
    
    private init() {
        // Load debug settings from UserDefaults
        self.skipAuthentication = UserDefaults.standard.bool(forKey: "skipAuthentication")
    }
    
    func toggleSkipAuthentication() {
        skipAuthentication.toggle()
    }
    
    func resetDebugSettings() {
        skipAuthentication = false
        UserDefaults.standard.removeObject(forKey: "skipAuthentication")
    }
}

// MARK: - Debug View for easy toggling during development
struct DebugControlsView: View {
    @StateObject private var debugManager = DebugManager.shared
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "ladybug.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("Debug")
                    .font(.caption.bold())
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Toggle("Skip Auth", isOn: $debugManager.skipAuthentication)
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                        .scaleEffect(0.8)
                }
                
                Button("Reset") {
                    debugManager.resetDebugSettings()
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    DebugControlsView()
} 
 