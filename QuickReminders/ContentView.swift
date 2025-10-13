//
//  ContentView.swift
//  QuickReminders
//
//  Created by Martin Kostelka on 03.10.2025.
//

import SwiftUI
import EventKit

struct ContentView: View {
    @EnvironmentObject var reminderManager: ReminderManager
    @EnvironmentObject var hotKeyManager: HotKeyManager  
    @EnvironmentObject var floatingWindowManager: FloatingWindowManager
    @EnvironmentObject var colorTheme: ColorThemeManager
    @State private var reminderText = ""
    @State private var statusMessage = ""
    @State private var isSuccess = false
    @State private var showingSettings = false
    @FocusState private var isTextFieldFocused: Bool
    
    private let nlParser = NLParser()
    
    var body: some View {
        VStack(spacing: 0) {
            // Beautiful Header with Gradient
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fast Remind")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Natural language reminders")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { 
                        // Settings button clicked
                        showingSettings = true 
                    }) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                
                // Current hotkey display
                HStack {
                    Image(systemName: "keyboard")
                        .foregroundColor(.secondary)
                    Text("Hotkey: \(hotKeyManager.currentHotKey)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(NSColor.quaternaryLabelColor)),
                alignment: .bottom
            )
            
            // Main Content Area
            VStack(spacing: 24) {
                // List Selection Card
                if !reminderManager.availableLists.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundColor(.blue)
                            Text("Reminder List")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        Picker("List", selection: $reminderManager.selectedList) {
                            ForEach(reminderManager.availableLists, id: \.calendarIdentifier) { list in
                                Text(list.title).tag(list as EKCalendar?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(NSColor.quaternaryLabelColor), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                }
                
                // Beautiful Input Card
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "plus.message")
                                .foregroundColor(.green)
                            Text("Create or Manage")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        Text(exampleText)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    TextField("Enter your command...", text: $reminderText)
                        .font(.system(size: 18, weight: .medium))
                        .padding(16)
                        .background(Color(NSColor.quaternaryLabelColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            createReminder()
                        }
                    
                    Button(action: {
                        // Execute button clicked
                        createReminder()
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Execute")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: reminderText.isEmpty || !reminderManager.hasAccess ? [.gray] : [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(reminderText.isEmpty || !reminderManager.hasAccess)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(NSColor.quaternaryLabelColor), lineWidth: 1)
                )
                .padding(.horizontal, 24)
            }
            .padding(.top, 32)
            
            // Status Messages
            if !statusMessage.isEmpty {
                HStack {
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(isSuccess ? .green : .red)
                    Text(statusMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSuccess ? .green : .red)
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
                .animation(.spring(response: 0.5), value: statusMessage)
            }
            
            // Permission Warning Card
            if !reminderManager.hasAccess {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.orange)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reminders Access Required")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Grant access to create and manage reminders")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    Button(action: {
                        // Grant Access button clicked
                        // Current access state checked
                        reminderManager.requestPermissionManually()
                        
                        // Check status periodically for a few seconds
                        for i in 1...5 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i)) {
                                // Access check performed
                                reminderManager.checkAccessStatus()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "key")
                            Text("Grant Access")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.orange, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 24)
            }
            
            Spacer()
        }
        .background(
            LinearGradient(
                colors: [.clear, .blue.opacity(0.05), .purple.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
        .sheet(isPresented: $showingSettings) {
            PreferencesView(
                reminderManager: reminderManager,
                hotKeyManager: hotKeyManager,
                colorTheme: colorTheme
            )
            .frame(minWidth: 700, minHeight: 500)
        }
    }
    
    private var exampleText: String {
        if colorTheme.shortcutsEnabled {
            return "Try: \"Call mom tomorrow at 3pm\", \"rm call mom\", or \"mv lunch to friday\""
        } else {
            return "Try: \"Call mom tomorrow at 3pm\", \"remove call mom\", or \"move lunch to friday\""
        }
    }
    
    private func createReminder() {
        guard !reminderText.isEmpty else { return }
        
        let text = reminderText.lowercased()
        
        // Check for delete commands
        let deleteKeywords = colorTheme.shortcutsEnabled ? 
            ["delete", "remove", "rm"] : 
            ["delete", "remove"]
        
        if deleteKeywords.contains(where: { text.starts(with: $0) }) {
            handleDeleteCommand(text)
            return
        }
        
        // Check for move/reschedule commands
        let moveKeywords = colorTheme.shortcutsEnabled ?
            ["move", "reschedule", "mv"] :
            ["move", "reschedule"]
        
        if moveKeywords.contains(where: { text.contains($0) }) {
            handleMoveCommand(text)
            return
        }
        
        // Regular reminder creation
        nlParser.colorTheme = colorTheme
        let parsedReminder = nlParser.parseReminderText(reminderText)
        
        // Check validation
        if !parsedReminder.isValid {
            statusMessage = "❌ \(parsedReminder.errorMessage ?? "Invalid reminder format")"
            isSuccess = false
            return
        }
        
        statusMessage = "Creating reminder..."
        isSuccess = false
        
        reminderManager.createReminder(
            title: parsedReminder.title,
            notes: nil,
            dueDate: parsedReminder.dueDate
        ) { success, error in
            DispatchQueue.main.async {
                if success {
                    statusMessage = "✅ Reminder created successfully!"
                    isSuccess = true
                    reminderText = ""
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        statusMessage = ""
                    }
                } else {
                    statusMessage = "❌ Failed to create reminder: \(error?.localizedDescription ?? "Unknown error")"
                    isSuccess = false
                }
            }
        }
    }
    
    private func handleDeleteCommand(_ text: String) {
        // Extract reminder title from "delete X", "remove X", or "rm X"
        let words = text.components(separatedBy: " ")
        guard words.count > 1 else {
            statusMessage = "❌ Please specify what to delete"
            isSuccess = false
            return
        }
        
        let titleToDelete = words.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        // Attempting to delete reminder
        
        statusMessage = "Searching for reminder..."
        isSuccess = false
        
        reminderManager.findReminder(withTitle: titleToDelete) { reminders in
            DispatchQueue.main.async {
                if let reminderToDelete = reminders.first {
                    // Found reminder to delete
                    self.reminderManager.deleteReminder(reminderToDelete) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                self.statusMessage = "✅ Reminder deleted successfully!"
                                self.isSuccess = true
                                self.reminderText = ""
                            } else {
                                self.statusMessage = "❌ Failed to delete reminder: \(error?.localizedDescription ?? "Unknown error")"
                                self.isSuccess = false
                                // Delete error
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                self.statusMessage = ""
                            }
                        }
                    }
                } else {
                    self.statusMessage = "❌ Reminder '\(titleToDelete)' not found. Available: \(reminders.map { $0.title ?? "Untitled" }.joined(separator: ", "))"
                    self.isSuccess = false
                    // No matching reminders found
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        self.statusMessage = ""
                    }
                }
            }
        }
    }
    
    private func handleMoveCommand(_ text: String) {
        // Parse "move X to Y", "reschedule X to Y", or "mv X to Y"
        let words = text.components(separatedBy: " ")
        
        // Find "to" keyword to split the command
        guard let toIndex = words.firstIndex(of: "to"), toIndex > 1 else {
            statusMessage = "❌ Use format: 'move [reminder] to [date/time]'"
            isSuccess = false
            return
        }
        
        // Extract reminder title (everything between "move"/"reschedule" and "to")
        let titleWords = Array(words[1..<toIndex])
        let titleToMove = titleWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract new date/time (everything after "to")
        let dateWords = Array(words[(toIndex + 1)...])
        let newDateText = dateWords.joined(separator: " ")
        
        // Attempting to move reminder
        
        // Parse the new date
        nlParser.colorTheme = colorTheme
        guard let newDate = nlParser.parseReminderText("dummy " + newDateText).dueDate else {
            statusMessage = "❌ Could not parse new date/time '\(newDateText)'"
            isSuccess = false
            // Failed to parse date
            return
        }
        
        // Parsed new date
        statusMessage = "Searching for reminder..."
        isSuccess = false
        
        reminderManager.findReminder(withTitle: titleToMove) { reminders in
            DispatchQueue.main.async {
                if let reminderToMove = reminders.first {
                    // Found reminder to move
                    self.reminderManager.updateReminderDate(reminderToMove, newDate: newDate) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                self.statusMessage = "✅ Reminder moved successfully!"
                                self.isSuccess = true
                                self.reminderText = ""
                                // Successfully moved reminder
                            } else {
                                self.statusMessage = "❌ Failed to move reminder: \(error?.localizedDescription ?? "Unknown error")"
                                self.isSuccess = false
                                // Move error occurred
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                self.statusMessage = ""
                            }
                        }
                    }
                } else {
                    self.statusMessage = "❌ Reminder '\(titleToMove)' not found. Available: \(reminders.map { $0.title ?? "Untitled" }.joined(separator: ", "))"
                    self.isSuccess = false
                    // No matching reminders found
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        self.statusMessage = ""
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ReminderManager())
        .environmentObject(HotKeyManager())
        .environmentObject(FloatingWindowManager())
}
