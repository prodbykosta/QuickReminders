//
//  PreferencesWindow.swift
//  QuickReminders
//
//  Created by QuickReminders on 04.10.2025.
//

#if os(macOS)
import AppKit
import Foundation

class PreferencesWindow: NSWindow {
    private let notificationCenter = NotificationCenter.default
    
    static let preferencesWindowWillCloseNotification = Notification.Name("PreferencesWindowWillClose")
    
    override func close() {
        // Send notification before closing (like Snap does)
        notificationCenter.post(name: PreferencesWindow.preferencesWindowWillCloseNotification, object: nil)
        super.close()
    }
    
    override func performClose(_ sender: Any?) {
        // Send notification when user clicks close button
        notificationCenter.post(name: PreferencesWindow.preferencesWindowWillCloseNotification, object: nil)
        super.performClose(sender)
    }
    
    func closeWindow() {
        // Safe close method
        super.close()
    }
}#endif
