//
//  PreferencesView.swift
//  QuickReminders
//
//  Created by QuickReminders on 04.10.2025.
//

import SwiftUI
import EventKit

enum SettingsPage: String, CaseIterable {
    case general = "General"
    case hotkey = "Hotkey"
    case colors = "Colors"
    case lists = "Lists"
    case help = "Help"
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .hotkey: return "keyboard"
        case .colors: return "paintpalette"
        case .lists: return "list.bullet.rectangle"
        case .help: return "questionmark.circle"
        }
    }
}

struct PreferencesView: View {
    @ObservedObject var reminderManager: ReminderManager
    @ObservedObject var hotKeyManager: HotKeyManager
    @ObservedObject var colorTheme: ColorThemeManager
    @ObservedObject var speechManager: SpeechManager
    @State private var selectedPage: SettingsPage? = .general
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SettingsPage.allCases, id: \.self, selection: $selectedPage) { page in
                NavigationLink(value: page) {
                    Label(page.rawValue, systemImage: page.icon)
                }
            }
            .navigationTitle("Settings")
        } detail: {
            // Detail content
            destinationView(for: selectedPage ?? .general)
        }
        .frame(minWidth: 700, minHeight: 500)
        .onReceive(NotificationCenter.default.publisher(for: PreferencesWindow.preferencesWindowWillCloseNotification)) { _ in
            // Save all settings when window closes (like Snap does)
            saveSettings()
        }
    }
    
    @ViewBuilder
    private func destinationView(for page: SettingsPage) -> some View {
        switch page {
        case .general:
            GeneralSettingsView(reminderManager: reminderManager, colorTheme: colorTheme, speechManager: speechManager, hotKeyManager: hotKeyManager)
        case .hotkey:
            HotkeySettingsView(hotKeyManager: hotKeyManager)
        case .colors:
            ColorSettingsView(colorTheme: colorTheme)
        case .lists:
            ListSettingsView(reminderManager: reminderManager, colorTheme: colorTheme)
        case .help:
            HelpSettingsView(colorTheme: colorTheme)
        }
    }
    
    private func saveSettings() {
        // Save color theme
        colorTheme.saveColors()
        
        // Save selected list if any
        if let selectedList = reminderManager.selectedList {
            UserDefaults.standard.set(selectedList.calendarIdentifier, forKey: "SelectedListIdentifier")
        }
        
        // All settings saved
    }
}