//
//  FastReminderApp.swift
//  FastReminder
//
//  Created by Martin Kostelka on 03.10.2025.
//

import SwiftUI
import CoreData

@main
struct FastReminderApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
