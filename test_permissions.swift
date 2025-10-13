#!/usr/bin/env swift

import Foundation
import EventKit

print("Testing EventKit permissions...")

let eventStore = EKEventStore()

print("Current authorization status: \(EKEventStore.authorizationStatus(for: .reminder).rawValue)")

if #available(macOS 14.0, *) {
    eventStore.requestFullAccessToReminders { granted, error in
        print("Permission result: granted=\(granted), error=\(String(describing: error))")
        if granted {
            print("✅ SUCCESS: Permission granted!")
        } else {
            print("❌ FAILED: Permission denied")
            if let error = error {
                print("Error details: \(error)")
            }
        }
        exit(0)
    }
} else {
    eventStore.requestAccess(to: .reminder) { granted, error in
        print("Permission result: granted=\(granted), error=\(String(describing: error))")
        if granted {
            print("✅ SUCCESS: Permission granted!")
        } else {
            print("❌ FAILED: Permission denied")
            if let error = error {
                print("Error details: \(error)")
            }
        }
        exit(0)
    }
}

// Wait for async callback
RunLoop.current.run()