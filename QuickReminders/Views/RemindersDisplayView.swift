//
//  RemindersListView.swift
//  QuickReminders
//
//  Created by Kosta on 10.10.2025.
//

import SwiftUI
import EventKit

#if os(macOS)

struct RemindersDisplayView: View {
    let reminders: [EKReminder]
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            Text("Reminders")
                .font(.headline)
                .padding()

            List(reminders, id: \.self) { reminder in
                Text(reminder.title)
            }

            Button("Close", action: onDismiss)
                .padding()
        }
        .frame(width: 400, height: 500)
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}

#endif
