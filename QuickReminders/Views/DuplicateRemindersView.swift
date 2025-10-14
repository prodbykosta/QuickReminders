//
//  DuplicateRemindersView.swift
//  QuickReminders
//
//  Created by Kosta on 10.10.2025.
//

import SwiftUI
import EventKit

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
                    Text(reminder.title)
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
