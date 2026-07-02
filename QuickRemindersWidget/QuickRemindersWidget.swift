//
//  QuickRemindersWidget.swift
//  QuickRemindersWidget
//
//  Control Center widget for quick reminder creation (iOS 18+ only)
//

#if os(iOS)
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Control Widget for Control Center
// Opens QuickReminders app with one tap from Control Center
@available(iOS 18.0, *)
@available(iOSApplicationExtension 18.0, *)
struct QuickReminderControlWidget: ControlWidget {
    static let kind: String = "com.martinkostelka.QuickReminders.ControlWidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind
        ) {
            // One tap to open QuickReminders - fast access from anywhere!
            ControlWidgetButton(action: OpenQuickRemindersIntent()) {
                Label("Quick Reminder", systemImage: "bolt.fill")
            }
        }
        .displayName("Quick Reminder")
        .description("Open QuickReminders app")
    }
}
#endif
