//
//  QuickRemindersiOSApp.swift
//  QuickReminders iOS
//
//  Main iOS app entry point
//

import SwiftUI

#if os(iOS)
// This file should not be @main when UniversalApp is present
// Removed @main - using UniversalApp.swift instead
struct QuickRemindersiOSApp: App {
    @StateObject private var colorTheme: SharedColorThemeManager
    @StateObject private var reminderManager: SharedReminderManager
    @StateObject private var animationManager = AnimationManager()
    
    init() {
        let theme = SharedColorThemeManager()
        _colorTheme = StateObject(wrappedValue: theme)
        _reminderManager = StateObject(wrappedValue: SharedReminderManager(colorTheme: theme))
    }
    
    var body: some Scene {
        WindowGroup {
            PerfectIOSAppView()
        }
    }
    

}
#endif
