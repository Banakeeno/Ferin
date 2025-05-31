//
//  FerinApp.swift
//  Ferin
//
//  Created by Bankin ALO on 29.05.25.
//

import SwiftUI
import FirebaseCore

@main
struct FerinApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}