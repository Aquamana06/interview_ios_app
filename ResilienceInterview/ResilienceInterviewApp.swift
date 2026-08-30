//
//  ResilienceInterviewApp.swift
//  ResilienceInterview
//
//  Created by mana uchida on 2026/08/30.
//

import SwiftUI

@main
struct ResilienceInterviewApp: App {
    @StateObject private var app = AppViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if app.isLoggedIn {
                    HomeView(app: app)
                } else {
                    LoginView(app: app)
                }
            }
        }
    }
}
