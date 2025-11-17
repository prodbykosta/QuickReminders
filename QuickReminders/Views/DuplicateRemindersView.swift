//
//  DuplicateRemindersView.swift
//  QuickReminders
//
//  Created by Kosta on 10.10.2025.
//

import SwiftUI
import EventKit

#if os(macOS)

struct DuplicateRemindersView: View {
    let reminders: [EKReminder]
    let onSelect: (EKReminder) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            Text("We found multiple reminders. Please select one:")
                .font(.headline)
                .padding()

            List(reminders, id: \.self) { reminder in
                Button(action: { onSelect(reminder) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reminder.title)
                        
                        // Show recurring indicator under the title (like native Reminders)
                        if let recurrenceRules = reminder.recurrenceRules, !recurrenceRules.isEmpty,
                           let rule = recurrenceRules.first {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text(duplicatesRecurrenceText(from: rule))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Button("Cancel", action: onDismiss)
                .padding()
        }
        .frame(width: 400, height: 300)
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Helper Functions

private func duplicatesRecurrenceText(from rule: EKRecurrenceRule) -> String {
    let interval = rule.interval
    
    switch rule.frequency {
    case .daily:
        if interval == 1 {
            return "Daily"
        } else {
            return "Every \(interval) days"
        }
    case .weekly:
        if interval == 1 {
            return "Weekly"
        } else {
            return "Every \(interval) weeks"
        }
    case .monthly:
        if interval == 1 {
            return "Monthly"
        } else {
            return "Every \(interval) months"
        }
    case .yearly:
        if interval == 1 {
            return "Yearly"
        } else {
            return "Every \(interval) years"
        }
    @unknown default:
        return "Repeats"
    }
}

#endif
