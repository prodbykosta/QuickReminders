//
//  UniversalApp.swift
//  QuickReminders
//
//  Universal app entry point for both iOS and macOS (following OpenSpoken pattern)
//

import SwiftUI

#if os(macOS)
import AppKit
import Combine
import EventKit
import Speech
import AVFoundation
#else
import UIKit
import GoogleSignIn
#endif

@main
struct QuickRemindersUniversalApp: App {
    
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #else
    @StateObject private var colorTheme: SharedColorThemeManager
    @StateObject private var reminderManager: SharedReminderManager
    @StateObject private var animationManager = AnimationManager()

    init() {
        let theme = SharedColorThemeManager()
        let remManager = SharedReminderManager(colorTheme: theme)

        _colorTheme = StateObject(wrappedValue: theme)
        _reminderManager = StateObject(wrappedValue: remManager)

        // Configure Google Sign-In
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
        }
    }
    #endif
    
    var body: some Scene {
        #if os(macOS)
        // macOS: Only show Settings - main interaction is through global hotkey
        Settings {
            PreferencesView(
                reminderManager: appDelegate.reminderManager,
                hotKeyManager: appDelegate.hotKeyManager,
                colorTheme: appDelegate.colorTheme,
                speechManager: appDelegate.speechManager
            )
            .frame(minWidth: 700, minHeight: 500)
        }
        #else
        // iOS: Show main app interface
        WindowGroup {
            PerfectIOSAppView()
                .environmentObject(colorTheme)
                .environmentObject(reminderManager)
                .environmentObject(animationManager)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        #endif
    }
    
    #if !os(macOS)
    private var colorScheme: ColorScheme? {
        // Default to system appearance
        return nil
    }
    #endif
}
