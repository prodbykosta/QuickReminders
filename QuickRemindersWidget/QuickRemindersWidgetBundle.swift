//
//  QuickRemindersWidgetBundle.swift
//  QuickRemindersWidget
//
//  Created by Martin Kostelka on 09.12.2025.
//

import WidgetKit
import SwiftUI

@main
@available(iOS 18.0, *)
@available(iOSApplicationExtension 18.0, *)
struct QuickRemindersWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Control Widget for Control Center
        QuickReminderControlWidget()
    }
}
