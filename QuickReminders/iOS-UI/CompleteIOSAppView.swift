//
//  CompleteIOSAppView.swift
//  QuickReminders - iOS
//
//  Complete iOS app with animations, voice support, and full settings
//
#if os(iOS)
import SwiftUI
import EventKit
import Speech
import AVFoundation
import Foundation

struct CompleteIOSAppView: View {
    @StateObject private var colorTheme = SharedColorThemeManager()
    @StateObject private var reminderManager: SharedReminderManager
    @StateObject private var animationManager = AnimationManager()
    @StateObject private var speechManager = SharedSpeechManager()
    
    init() {
        let theme = SharedColorThemeManager()
        _colorTheme = StateObject(wrappedValue: theme)
        _reminderManager = StateObject(wrappedValue: SharedReminderManager(colorTheme: theme))
    }
    
    var body: some View {
        ZStack {
            // Full screen app with animation background
            TabView {
                // Create Reminder Tab with animations - FIRST TAB
                NavigationView {
                    EnhancedCreateReminderView(
                        reminderManager: reminderManager,
                        colorTheme: colorTheme,
                        animationManager: animationManager,
                        speechManager: speechManager
                    )
                }
                .tabItem {
                    Image(systemName: "plus.circle")
                    Text("Create")
                }
                
                // Main Reminders Tab - SECOND TAB
                NavigationView {
                    RemindersListView(
                        reminderManager: reminderManager,
                        colorTheme: colorTheme,
                        animationManager: animationManager
                    )
                }
                .tabItem {
                    Image(systemName: "checklist")
                    Text("Reminders")
                }
                
                // Complete Settings Tab - THIRD TAB
                NavigationView {
                    CompleteSettingsView(
                        colorTheme: colorTheme,
                        reminderManager: reminderManager,
                        speechManager: speechManager
                    )
                }
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
            }
            .accentColor(colorTheme.primaryColor)
            
            // BEAUTIFUL FULL-SCREEN ANIMATION OVERLAY
            if animationManager.currentStatus != .hidden {
                FullScreenAnimationOverlay(
                    status: animationManager.currentStatus,
                    colorTheme: colorTheme
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animationManager.currentStatus)
                .zIndex(999)
            }
        }
        .preferredColorScheme(colorScheme)
        .ignoresSafeArea(.all, edges: .all) // FULL SCREEN
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Refresh reminder lists when app becomes active (handles new lists created outside app)
            Task {
                await reminderManager.reloadReminderLists()
            }
        }
    }
    
    private var colorScheme: ColorScheme? {
        switch colorTheme.appearanceTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
}

// MARK: - Enhanced Create Reminder View with Voice and Animations

struct EnhancedCreateReminderView: View {
    @ObservedObject var reminderManager: SharedReminderManager
    @ObservedObject var colorTheme: SharedColorThemeManager
    @ObservedObject var animationManager: AnimationManager
    @ObservedObject var speechManager: SharedSpeechManager
    
    @State private var reminderText = ""
    @State private var isProcessing = false
    @State private var isListening = false
    @FocusState private var isTextFieldFocused: Bool
    
    private let quickSuggestions = [
        "Call mom tomorrow",
        "Meting Monday 10am",
        "Gym session 6pm",
        "Pay bills Friday",
        "Doctor appointment next week"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // SHOW ONLY PERMISSION WARNING IF NO ACCESS
                if !reminderManager.hasAccess {
                    VStack(spacing: 20) {
                        Image(systemName: "lock.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)

                        Text("Reminders Access Required")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.primary)

                        Text("QuickReminders needs access to your reminders to create and manage them.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button("Open iPhone Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.blue)
                        .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.top, 40)

                    Spacer()
                } else {
                    // MAIN CONTENT - ONLY SHOW WHEN PERMISSIONS ARE GRANTED

                // Header section
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [colorTheme.primaryColor, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isProcessing ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isProcessing)

                    Text("Create Reminder")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.primary)

                    Text("Type naturally or use voice - I'll understand when and what you want to remember")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, !reminderManager.hasAccess ? 0 : 40)
                
                // Input section with voice
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        // Text input
                        TextField("What would you like to remember?", text: $reminderText, axis: .vertical)
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .lineLimit(3...6)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                createReminder()
                            }
                        
                        // Voice button
                        Button(action: toggleVoiceRecognition) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: isListening ? 
                                            [.red, .orange] : 
                                            [colorTheme.primaryColor, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 50, height: 50)
                                    .shadow(color: (isListening ? Color.red : colorTheme.primaryColor).opacity(0.4), radius: 8, x: 0, y: 4)
                                
                                if isListening {
                                    // Animated listening indicator
                                    ForEach(0..<3, id: \.self) { index in
                                        Circle()
                                            .stroke(.white.opacity(0.3), lineWidth: 2)
                                            .frame(width: 60 + CGFloat(index * 20))
                                            .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 3 + Double(index)) * 0.1)
                                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: UUID())
                                    }
                                }
                                
                                Image(systemName: isListening ? "waveform" : "mic.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .scaleEffect(isListening ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isListening)
                    }
                    .padding(.horizontal, 20)
                    
                    // Create button
                    Button(action: createReminder) {
                        HStack(spacing: 12) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            
                            Text(isProcessing ? "Creating..." : "Create Reminder")
                                .font(.body.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: reminderText.isEmpty ? [.gray] : [colorTheme.primaryColor, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: reminderText.isEmpty ? .clear : colorTheme.primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(reminderText.isEmpty || isProcessing)
                    .animation(.easeInOut(duration: 0.2), value: reminderText.isEmpty)
                    .padding(.horizontal, 20)
                }
                
                // Quick suggestions
                if reminderText.isEmpty && !isListening {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Ideas")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(quickSuggestions, id: \.self) { suggestion in
                                Button(action: {
                                    reminderText = suggestion
                                    isTextFieldFocused = true
                                }) {
                                    Text(suggestion)
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(8)
                                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.3), value: reminderText.isEmpty)
                }

                Spacer()
                } // End of else block - main content only when permissions granted
            }
        }
        .navigationTitle("Create")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    reminderText = ""
                    speechManager.stopListening()
                }
                .font(.body.weight(.medium))
                .foregroundColor(colorTheme.primaryColor)
                .disabled(reminderText.isEmpty)
            }
        }
        .onReceive(speechManager.$transcription) { transcription in
            reminderText = transcription
        }
        .onReceive(speechManager.$isListening) { listening in
            isListening = listening
        }
    }
    
    private func toggleVoiceRecognition() {
        if isListening {
            speechManager.stopListening()
        } else {
            speechManager.startListening(
                onUpdate: { transcript in
                    reminderText = transcript
                },
                completion: { finalTranscript in
                    reminderText = finalTranscript
                }
            )
        }
    }
    
    private func createReminder() {
        guard !reminderText.isEmpty, !isProcessing else { return }
        
        isProcessing = true
        
        let inputCommand = reminderText.lowercased()
        
        // Check for move commands (mv, move)
        if inputCommand.hasPrefix("mv ") || inputCommand.hasPrefix("move ") {
            handleMoveCommand(reminderText)
            return
        }
        
        // Check for remove commands (rm, remove, delete)
        if inputCommand.hasPrefix("rm ") || inputCommand.hasPrefix("remove ") || inputCommand.hasPrefix("delete ") {
            handleRemoveCommand(reminderText)
            return
        }
        
        // Check for list commands (ls, list)
        if inputCommand.hasPrefix("ls") || inputCommand.hasPrefix("list") {
            handleListCommand(reminderText)
            return
        }
        
        // Default: Create reminder
        // Show beautiful animation
        animationManager.showProcessing("Creating your reminder...")
        
        Task {
            do {
                try await reminderManager.createReminder(from: reminderText)
                
                await MainActor.run {
                    reminderText = ""
                    isProcessing = false
                    isTextFieldFocused = false
                    
                    // Success animation
                    animationManager.showSuccess("✨ Reminder created!")
                    
                    // Haptic feedback (with error handling)
                    if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }
                    
                    // Auto-hide animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        animationManager.hide()
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    
                    // Error animation
                    animationManager.showError("Failed to create reminder")
                    
                    // Error haptic feedback (with error handling)
                    if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil {
                        let notification = UINotificationFeedbackGenerator()
                        notification.notificationOccurred(.error)
                    }
                    
                    // Auto-hide error
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        animationManager.hide()
                    }
                }
            }
        }
    }
    
    // MARK: - Command Handlers
    
    private func handleMoveCommand(_ command: String) {
        animationManager.showProcessing("Finding reminders to move...")
        
        let (searchTerm, targetReminder) = parseMoveCommand(command)
        
        if searchTerm.isEmpty {
            isProcessing = false
            animationManager.showError("Please specify what to move")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.animationManager.hide()
            }
            return
        }
        
        reminderManager.findReminder(withTitle: searchTerm) { reminders in
            DispatchQueue.main.async {
                if reminders.isEmpty {
                    self.isProcessing = false
                    self.animationManager.showError("No reminders found matching '\(searchTerm)'")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.animationManager.hide()
                    }
                } else if reminders.count == 1 {
                    // Single match - move it directly
                    self.moveReminder(reminders[0], targetReminder: targetReminder)
                } else {
                    // Multiple matches - show selection (for now, move the first one)
                    self.moveReminder(reminders[0], targetReminder: targetReminder)
                }
            }
        }
    }
    
    private func handleRemoveCommand(_ command: String) {
        animationManager.showProcessing("Finding reminders to remove...")
        
        let searchTerm = parseRemoveCommand(command)
        
        if searchTerm.isEmpty {
            isProcessing = false
            animationManager.showError("Please specify what to remove")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.animationManager.hide()
            }
            return
        }
        
        reminderManager.findReminder(withTitle: searchTerm) { reminders in
            DispatchQueue.main.async {
                if reminders.isEmpty {
                    self.isProcessing = false
                    self.animationManager.showError("No reminders found matching '\(searchTerm)'")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.animationManager.hide()
                    }
                } else if reminders.count == 1 {
                    // Single match - remove it directly
                    self.deleteReminder(reminders[0])
                } else {
                    // Multiple matches - remove the first one for now
                    self.deleteReminder(reminders[0])
                }
            }
        }
    }
    
    private func handleListCommand(_ command: String) {
        animationManager.showProcessing("Loading reminders...")

        // Check if using Google provider
        if colorTheme.selectedProvider == "Google (Tasks + Calendar)" && GoogleAuthManager.shared.isSignedIn {
            Task {
                do {
                    let allReminders = try await reminderManager.getAllGoogleReminders()
                    let dateFilter = self.parseDateFromCommand(command)
                    var filteredReminders = allReminders

                    if let targetDate = dateFilter {
                        filteredReminders = allReminders.filter { reminder in
                            guard let dueDate = reminder.dueDate else { return false }
                            return Calendar.current.isDate(dueDate, inSameDayAs: targetDate)
                        }
                    }

                    await MainActor.run {
                        self.isProcessing = false
                        self.reminderText = ""
                        self.showListResult(titles: filteredReminders.map { $0.title }, dates: filteredReminders.map { $0.dueDate })
                    }
                } catch {
                    await MainActor.run {
                        self.isProcessing = false
                        self.reminderText = ""
                        self.animationManager.showError("Failed to load Google reminders")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { self.animationManager.hide() }
                    }
                }
            }
        } else {
            reminderManager.getAllReminders { allReminders in
                DispatchQueue.main.async {
                    let dateFilter = self.parseDateFromCommand(command)
                    var filteredReminders = allReminders

                    if let targetDate = dateFilter {
                        filteredReminders = allReminders.filter { reminder in
                            guard let dueDate = reminder.dueDateComponents?.date else { return false }
                            return Calendar.current.isDate(dueDate, inSameDayAs: targetDate)
                        }
                    } else if command.lowercased().contains("week") || command.lowercased().contains("month") {
                        filteredReminders = self.filterRemindersForPeriod(allReminders, command: command)
                    }

                    self.isProcessing = false
                    self.reminderText = ""
                    self.showListResult(
                        titles: filteredReminders.compactMap { $0.title },
                        dates: filteredReminders.map { $0.dueDateComponents?.date }
                    )
                }
            }
        }
    }

    private func showListResult(titles: [String], dates: [Date?]) {
        let count = titles.count

        if count == 0 {
            animationManager.showError("No reminders found")
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none

            let topReminders = titles.prefix(3).enumerated().map { index, title -> String in
                let shortTitle = title.count > 25 ? String(title.prefix(25)) + "..." : title
                if index < dates.count, let date = dates[index] {
                    return "\(shortTitle) (\(formatter.string(from: date)))"
                }
                return shortTitle
            }

            let listSummary = topReminders.joined(separator: " • ")
            let displayMessage = count <= 3 ?
                "📋 \(count) reminder\(count == 1 ? "" : "s"): \(listSummary)" :
                "📋 \(count) reminders: \(listSummary) + \(count - 3) more"

            animationManager.showSuccess(displayMessage)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.animationManager.hide()
        }
    }
    
    // MARK: - Command Parsing (copied from keyboard version)
    
    private func parseMoveCommand(_ command: String) -> (searchTerm: String, targetReminder: SharedParsedReminder?) {
        let lowercaseCommand = command.lowercased()
        
        // Extract the search term and target from "mv reminderName to targetDateTimeRecurrence"
        let pattern = "^(mv|move)\\s+(.+?)\\s+to\\s+(.+)$"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: lowercaseCommand, options: [], range: NSRange(location: 0, length: lowercaseCommand.count)) {
            
            let searchRange = Range(match.range(at: 2), in: lowercaseCommand)!
            let targetRange = Range(match.range(at: 3), in: lowercaseCommand)!
            
            let searchTerm = String(lowercaseCommand[searchRange])
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let targetString = String(lowercaseCommand[targetRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Use SharedNLParser to parse the complex target date/time/recurrence
            let fullTestString = "reminder \(targetString)"
            let parsedTarget = reminderManager.nlParser.parseReminderText(fullTestString)
            
            return (searchTerm, parsedTarget)
        }
        
        // Fallback: just extract the reminder name without "to" part
        let searchTerm = lowercaseCommand
            .replacingOccurrences(of: "^(mv|move)\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (searchTerm, nil)
    }
    
    private func parseRemoveCommand(_ command: String) -> String {
        let lowercaseCommand = command.lowercased()
        
        return lowercaseCommand
            .replacingOccurrences(of: "^(rm|remove|delete)\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func moveReminder(_ reminder: EKReminder, targetReminder: SharedParsedReminder?) {
        guard let targetReminder = targetReminder else {
            isProcessing = false
            animationManager.showError("No target date specified")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.animationManager.hide()
            }
            return
        }
        
        // Update the reminder's due date
        if let dueDate = targetReminder.dueDate {
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = dateComponents
        }
        
        // Handle recurrence
        if targetReminder.isRecurring {
            if let frequency = targetReminder.recurrenceFrequency,
               let interval = targetReminder.recurrenceInterval {
                
                let recurrenceRule = EKRecurrenceRule(
                    recurrenceWith: frequency,
                    interval: interval,
                    end: targetReminder.recurrenceEndDate.map { EKRecurrenceEnd(end: $0) }
                )
                reminder.recurrenceRules = [recurrenceRule]
            } else {
            }
        } else {
            // Remove any existing recurrence if not recurring
            reminder.recurrenceRules = nil
        }
        
        // Save the updated reminder
        do {
            try reminderManager.eventStore.save(reminder, commit: true)
            
            isProcessing = false
            reminderText = ""
            animationManager.showSuccess("✨ Reminder moved!")
            
            // Haptic feedback
            if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.animationManager.hide()
            }
        } catch {
            isProcessing = false
            animationManager.showError("Failed to move reminder")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.animationManager.hide()
            }
        }
    }
    
    private func deleteReminder(_ reminder: EKReminder) {
        reminderManager.deleteReminder(reminder) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isProcessing = false
                    self.reminderText = ""
                    self.animationManager.showSuccess("✨ Reminder deleted!")
                    
                    // Haptic feedback
                    if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.animationManager.hide()
                    }
                } else {
                    self.isProcessing = false
                    self.animationManager.showError("Failed to delete reminder")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.animationManager.hide()
                    }
                }
            }
        }
    }
    
    // MARK: - List Command Helper Functions (copied from keyboard)
    
    private func parseDateFromCommand(_ command: String) -> Date? {
        let today = Date()
        let calendar = Calendar.current
        let lowercaseCommand = command.lowercased()
        
        // Remove "ls" or "list" prefix like keyboard does
        var cleanCommand = lowercaseCommand
            .replacingOccurrences(of: "^(ls|list)\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle shortcuts if enabled (same as keyboard)
        if colorTheme.shortcutsEnabled {
            cleanCommand = cleanCommand.replacingOccurrences(of: "tm", with: "tomorrow")
            cleanCommand = cleanCommand.replacingOccurrences(of: "td", with: "today")
            cleanCommand = cleanCommand.replacingOccurrences(of: "mon", with: "monday")
            cleanCommand = cleanCommand.replacingOccurrences(of: "tue", with: "tuesday")
            cleanCommand = cleanCommand.replacingOccurrences(of: "wed", with: "wednesday")
            cleanCommand = cleanCommand.replacingOccurrences(of: "thu", with: "thursday")
            cleanCommand = cleanCommand.replacingOccurrences(of: "fri", with: "friday")
            cleanCommand = cleanCommand.replacingOccurrences(of: "sat", with: "saturday")
            cleanCommand = cleanCommand.replacingOccurrences(of: "sun", with: "sunday")
        }
        
        if cleanCommand.contains("today") {
            return today
        } else if cleanCommand.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: today)
        } else if cleanCommand.contains("monday") {
            return getNextWeekday(2, from: today) // Monday = 2
        } else if cleanCommand.contains("tuesday") {
            return getNextWeekday(3, from: today) // Tuesday = 3
        } else if cleanCommand.contains("wednesday") {
            return getNextWeekday(4, from: today) // Wednesday = 4
        } else if cleanCommand.contains("thursday") {
            return getNextWeekday(5, from: today) // Thursday = 5
        } else if cleanCommand.contains("friday") {
            return getNextWeekday(6, from: today) // Friday = 6
        } else if cleanCommand.contains("saturday") {
            return getNextWeekday(7, from: today) // Saturday = 7
        } else if cleanCommand.contains("sunday") {
            return getNextWeekday(1, from: today) // Sunday = 1
        }
        
        return nil
    }
    
    private func getNextWeekday(_ targetWeekday: Int, from date: Date) -> Date? {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        
        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7 // Get next occurrence if today or already passed
        }
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: date)
    }
    
    private func filterRemindersForPeriod(_ reminders: [EKReminder], command: String) -> [EKReminder] {
        let calendar = Calendar.current
        let today = Date()
        let lowercaseCommand = command.lowercased()
        
        if lowercaseCommand.contains("this week") {
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? today
            
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return dueDate >= startOfWeek && dueDate <= endOfWeek
            }
        } else if lowercaseCommand.contains("this month") {
            let startOfMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
            let endOfMonth = calendar.dateInterval(of: .month, for: today)?.end ?? today
            
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return dueDate >= startOfMonth && dueDate <= endOfMonth
            }
        }
        
        return reminders
    }
}

// MARK: - Complete Settings View

struct CompleteSettingsView: View {
    @ObservedObject var colorTheme: SharedColorThemeManager
    @ObservedObject var reminderManager: SharedReminderManager
    @ObservedObject var speechManager: SharedSpeechManager
    @State private var showingResetConfirmation = false
    
    private func selectList(_ list: EKCalendar) {
        reminderManager.selectedList = list
        
        // Update the color theme to match the selected list
        colorTheme.updateColorsForRemindersList(list)
        
        // Save the selected list to UserDefaults for persistence
        UserDefaults.standard.set(list.calendarIdentifier, forKey: "SelectedListIdentifier")
    }
    
    var body: some View {
        Form {
            // App Section
            Section {
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundColor(colorTheme.primaryColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("QuickReminders")
                            .font(.headline.weight(.bold))
                        Text("Smart reminder creation for iOS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            // Reminder Service Provider Selection
            Section("Reminder Service") {
                Picker("Provider", selection: $colorTheme.selectedProvider) {
                    Text("Apple Reminders").tag("Apple Reminders")
                    Text("Google (Tasks + Calendar)").tag("Google (Tasks + Calendar)")
                }
                .pickerStyle(.menu)

                if colorTheme.selectedProvider == "Apple Reminders" {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Active")
                                .font(.subheadline)
                            Spacer()
                        }

                        Text("✓ Full features")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("✓ Works offline")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("✓ Siri integration")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Google Provider Selected
                    if GoogleAuthManager.shared.isSignedIn {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Connected: \(GoogleAuthManager.shared.userEmail ?? "")")
                                    .font(.subheadline)
                                Spacer()
                            }

                            Button("Sign Out") {
                                GoogleAuthManager.shared.signOut()
                            }
                            .font(.caption)
                            .foregroundColor(.red)

                            Divider()

                            Text("Default Lists/Calendars:")
                                .font(.caption)
                                .fontWeight(.semibold)

                            // Google Tasks List Picker
                            if !reminderManager.googleLists.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Default Task List")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Picker("", selection: Binding(
                                        get: { reminderManager.selectedGoogleListId ?? "" },
                                        set: { reminderManager.setSelectedGoogleList(listId: $0) }
                                    )) {
                                        ForEach(reminderManager.googleLists, id: \.id) { list in
                                            Text(list.name).tag(list.id)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }

                            // Google Calendar Picker
                            if !reminderManager.googleCalendars.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Default Calendar")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Picker("", selection: Binding(
                                        get: { reminderManager.selectedGoogleCalendarId ?? "" },
                                        set: { reminderManager.setSelectedGoogleCalendar(calendarId: $0) }
                                    )) {
                                        ForEach(reminderManager.googleCalendars, id: \.id) { calendar in
                                            Text(calendar.name).tag(calendar.id)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }

                            // Google Calendar Completion Mode Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Calendar Event Completion")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Picker("", selection: $colorTheme.googleCalendarCompletionMode) {
                                    ForEach(GoogleCalendarCompletionMode.allCases, id: \.self) { mode in
                                        Text(mode.displayName).tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)

                                Text(colorTheme.googleCalendarCompletionMode.description)
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .italic()
                                    .padding(.top, 2)
                            }

                            Divider()

                            Text("Smart Routing:")
                                .font(.caption)
                                .fontWeight(.semibold)

                            Text("• ⚡ Bolt → Manually select list/calendar")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("• Task list + recurring → Default Calendar")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("• Task list + has time → Default Calendar")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("• Calendar + no date → Default Task List")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("• Otherwise → Manual selection respected")
                                .font(.caption2)
                                .foregroundColor(.blue)

                            Text("⚠️ Limitations:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                                .padding(.top, 4)

                            Text("• Google Tasks only stores dates (no times)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• Requires internet connection")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• No location-based reminders")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sign in with your Google account to sync reminders with Google Tasks and Google Calendar.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: {
                                // Get root view controller to present sign-in
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let rootViewController = windowScene.windows.first?.rootViewController {
                                    GoogleAuthManager.shared.signIn(presentingViewController: rootViewController)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                    Text("Sign in with Google")
                                }
                                .font(.body.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Text("Hybrid Storage:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.top, 4)

                            Text("• Simple tasks → Google Tasks")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("• Recurring tasks → Google Calendar")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Appearance Section
            Section("Appearance") {
                Picker("Theme", selection: $colorTheme.appearanceTheme) {
                    ForEach(AppearanceTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.menu)  // Fix scrolling issue
                
                Toggle("Smooth Animations", isOn: $colorTheme.animationsEnabled)
                
                VStack(alignment: .leading, spacing: 8) {
                    ColorPicker("Accent Color", selection: $colorTheme.primaryColor)
                }
                
                ColorPicker("Success Color", selection: $colorTheme.successColor)
                ColorPicker("Error Color", selection: $colorTheme.errorColor)
            }
            
            // Reminders & Lists Section
            Section("Reminder Lists") {
                if !reminderManager.availableLists.isEmpty {
                    // Current default list with color
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default List")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if let selectedList = reminderManager.selectedList {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(cgColor: selectedList.cgColor))
                                    .frame(width: 20, height: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selectedList.title)
                                        .font(.system(size: 16, weight: .medium))
                                    Text("All new reminders go here")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(colorTheme.successColor)
                                    .font(.system(size: 18))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(cgColor: selectedList.cgColor).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(cgColor: selectedList.cgColor).opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    
                    // Available lists to choose from
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available Lists (\(reminderManager.availableLists.count))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Tap any list to set as default")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(reminderManager.availableLists, id: \.calendarIdentifier) { list in
                            Button(action: { selectList(list) }) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color(cgColor: list.cgColor))
                                        .frame(width: 16, height: 16)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(list.title)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        if list == reminderManager.selectedList {
                                            Text("Currently selected")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if list == reminderManager.selectedList {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(colorTheme.successColor)
                                            .font(.system(size: 14))
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    list == reminderManager.selectedList ? 
                                    Color(cgColor: list.cgColor).opacity(0.08) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(
                                            list == reminderManager.selectedList ? 
                                            Color(cgColor: list.cgColor).opacity(0.2) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("No Reminder Lists Available")
                            .font(.headline)
                        
                        Text("Make sure you have granted Reminders access and have at least one list in the Reminders app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Refresh Lists") {
                            Task {
                                await reminderManager.reloadReminderLists()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }

            // Siri Integration Section
            Section("Siri Integration") {
                Toggle("Enable Siri Integration", isOn: $colorTheme.siriIntegrationEnabled)

                if colorTheme.siriIntegrationEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Siri Default List")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Choose which list Siri creates reminders in")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !reminderManager.availableLists.isEmpty {
                            ForEach(reminderManager.availableLists, id: \.calendarIdentifier) { list in
                                Button(action: {
                                    colorTheme.siriDefaultList = list.calendarIdentifier
                                }) {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color(cgColor: list.cgColor))
                                            .frame(width: 16, height: 16)

                                        Text(list.title)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.primary)

                                        Spacer()

                                        if colorTheme.siriDefaultList == list.calendarIdentifier {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 14))
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        colorTheme.siriDefaultList == list.calendarIdentifier ?
                                        Color(cgColor: list.cgColor).opacity(0.08) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 6)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(
                                                colorTheme.siriDefaultList == list.calendarIdentifier ?
                                                Color(cgColor: list.cgColor).opacity(0.2) : Color.clear,
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Text("No lists available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to use:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Text("Say 'Hey Siri, Create a reminder using QuickReminders', 'Move a reminder using QuickReminders', or 'Remove a reminder using QuickReminders'")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .italic()
                    }
                    .padding(.top, 8)
                }
            }

            // Quick Ideas Section
            Section("Quick Ideas") {
                NavigationLink("Customize Quick Ideas") {
                    QuickIdeasSettingsView(colorTheme: colorTheme)
                }
                
                HStack {
                    Text("Current Ideas")
                    Spacer()
                    Text("\(colorTheme.customQuickIdeas.isEmpty ? 5 : colorTheme.customQuickIdeas.count)")
                        .foregroundColor(.secondary)
                }
            }
            
            // Voice Recognition Section (iOS specific - no hotkeys!)
            Section("Voice Recognition") {
                Toggle("Enable Voice Commands", isOn: $colorTheme.voiceActivationEnabled)

                // Microphone Permission
                HStack {
                    Image(systemName: speechManager.hasMicrophonePermission() ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(speechManager.hasMicrophonePermission() ? .green : .red)

                    Text(speechManager.hasMicrophonePermission() ? "Microphone Access Granted" : "Microphone Access Required")
                        .font(.subheadline)

                    Spacer()

                    if !speechManager.hasMicrophonePermission() {
                        Button("Open iPhone Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundColor(.white)
                    }
                }

                // Speech Recognition Permission
                HStack {
                    Image(systemName: speechManager.hasSpeechRecognitionPermission() ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(speechManager.hasSpeechRecognitionPermission() ? .green : .red)

                    Text(speechManager.hasSpeechRecognitionPermission() ? "Speech Recognition Access Granted" : "Speech Recognition Access Required")
                        .font(.subheadline)

                    Spacer()

                    if !speechManager.hasSpeechRecognitionPermission() {
                        Button("Open iPhone Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundColor(.white)
                    }
                }
                
                if colorTheme.voiceActivationEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Voice Trigger Words")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("Say these words at the end of your reminder to automatically send it:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Example: 'Buy groceries tomorrow SEND' - will automatically create the reminder")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .italic()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(colorTheme.voiceTriggerWords, id: \.self) { word in
                                HStack {
                                    Text("• \(word)")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        colorTheme.removeTriggerWord(word)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                            }
                        }
                        
                        HStack {
                            TextField("Add custom word", text: $colorTheme.customVoiceTriggerWord)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Add") {
                                colorTheme.addCustomTriggerWord()
                            }
                            .disabled(colorTheme.customVoiceTriggerWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Button("Reset to Defaults") {
                            colorTheme.resetToDefaultTriggerWords()
                        }
                        .foregroundColor(.red)
                        .buttonStyle(.bordered)
                    }
                }
            }

            // AI Mode Section
            Section("AI Mode") {
                Toggle("Enable AI Mode", isOn: $colorTheme.aiModeEnabled)

                if colorTheme.aiModeEnabled {
                    Text("AI Mode understands input in any language. The task title stays in your language — only dates, times, and commands are translated.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Provider", selection: $colorTheme.aiProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch colorTheme.aiProvider {
                    case .gemini:
                        VStack(alignment: .leading, spacing: 6) {
                            SecureField("Gemini API Key", text: $colorTheme.geminiApiKey)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            TextField("Model (default: gemini-2.5-flash)", text: $colorTheme.geminiModel)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            Link("Get your free key at aistudio.google.com →", destination: URL(string: "https://aistudio.google.com/apikey")!)
                                .font(.caption)
                        }
                    case .groq:
                        VStack(alignment: .leading, spacing: 6) {
                            SecureField("Groq API Key", text: $colorTheme.groqApiKey)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            TextField("Model (default: llama-3.1-8b-instant)", text: $colorTheme.groqModel)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            Link("Get your free key at console.groq.com →", destination: URL(string: "https://console.groq.com/keys")!)
                                .font(.caption)
                            Text("14,400 requests/day free — no credit card required")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    case .custom:
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Base URL (e.g. http://localhost:11434)", text: $colorTheme.customApiUrl)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)

                            TextField("Model (e.g. llama3.1:8b)", text: $colorTheme.customApiModel)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                            SecureField("Secret Token (Cloudflare WAF)", text: $colorTheme.customApiKey)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                            Text("Run AI on your own computer or server using Ollama or LM Studio.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Link("View setup guide →", destination: URL(string: "https://quickreminders.app/setup")!)
                                .font(.caption)
                        }
                    }

                    Toggle("Auto-Approve", isOn: $colorTheme.aiAutoApprove)
                    Text("Skip the preview and create the reminder immediately after AI transforms the text.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Voice Language", selection: $colorTheme.aiVoiceLocale) {
                        ForEach(AIVoiceLanguage.all, id: \.locale) { lang in
                            Text(lang.displayName).tag(lang.locale)
                        }
                    }
                    Text("Language used for voice recognition when AI Mode is on.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        TextField(AIVoiceLanguage.placeholder(for: colorTheme.aiVoiceLocale), text: $colorTheme.aiVoiceTriggerWord)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Text("Say this word at the end of your voice reminder to auto-send. Works alongside your existing trigger words.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Input Features Section
            Section("Input Features") {
                Toggle("Show Notes Field", isOn: $colorTheme.enableNotesField)
                Text("Enable an expandable notes field during reminder creation")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Variable Toggle Mode", isOn: $colorTheme.enableVariableToggle)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Long press highlighted words to toggle parsing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Example: Press \"tomorrow\" to keep it as literal text instead of parsing as date")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }

                NavigationLink(destination: SavedLocationsView()) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.green)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Manage Saved Locations")
                                .font(.body)
                                .foregroundColor(.primary)

                            Text("Add locations for quick access in reminders")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }
            }

            // Language Processing Section
            Section("Language Processing") {
                Toggle("Enable Shortcuts", isOn: $colorTheme.shortcutsEnabled)
                
                if colorTheme.shortcutsEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available shortcuts:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("mv, rm, ls, tm, td, mon, tue, wed, thu, fri, sat, sun")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                    }
                }

                Toggle("Search Selected List Only", isOn: $colorTheme.searchInSelectedListOnly)
                
                if !colorTheme.searchInSelectedListOnly {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("When disabled, move/remove commands search across ALL lists.")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("When enabled, commands only search the currently selected list.")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Toggle("Smart Time Detection", isOn: $colorTheme.timePeriodsEnabled)
                
                if colorTheme.timePeriodsEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Natural Language Time Periods")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Customize default times for natural language periods like 'morning', 'afternoon', etc.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 12) {
                            // Morning Time with DatePicker
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "sun.max")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 16))
                                    Text("Morning:")
                                        .font(.system(size: 15, weight: .medium))
                                        .frame(width: 80, alignment: .leading)
                                }
                                
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: {
                                            let formatter = DateFormatter()
                                            formatter.dateFormat = "h:mm a"
                                            return formatter.date(from: colorTheme.morningTime) ?? Date()
                                        },
                                        set: { newDate in
                                            let formatter = DateFormatter()
                                            formatter.dateFormat = "h:mm a"
                                            colorTheme.morningTime = formatter.string(from: newDate)
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .frame(width: 100)
                                
                                Spacer()
                            }
                            
                            // Afternoon Time with DatePicker
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "sun.and.horizon")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 16))
                                    Text("Afternoon:")
                                        .font(.system(size: 15, weight: .medium))
                                        .frame(width: 80, alignment: .leading)
                                }
                                
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: {
                                            let formatter = DateFormatter()
                                            formatter.dateFormat = "h:mm a"
                                            return formatter.date(from: colorTheme.afternoonTime) ?? Date()
                                        },
                                        set: { newDate in
                                            let formatter = DateFormatter()
                                            formatter.dateFormat = "h:mm a"
                                            colorTheme.afternoonTime = formatter.string(from: newDate)
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .frame(width: 100)
                                
                                Spacer()
                            }
                            
                            // Evening Time with DatePicker
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "sunset")
                                        .foregroundColor(.purple)
                                        .font(.system(size: 16))
                                    Text("Evening:")
                                        .font(.system(size: 15, weight: .medium))
                                        .frame(width: 80, alignment: .leading)
                                }
                                
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: {
                                            let formatter = DateFormatter()
                                            formatter.dateFormat = "h:mm a"
                                            return formatter.date(from: colorTheme.eveningTime) ?? Date()
                                        },
                                        set: { newDate in
                                            let formatter = DateFormatter()
                                            formatter.dateFormat = "h:mm a"
                                            colorTheme.eveningTime = formatter.string(from: newDate)
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .frame(width: 100)
                                
                                Spacer()
                            }
                            
                            // Night Time with DatePicker
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "moon.stars")
                                        .foregroundColor(.indigo)
                                        .font(.system(size: 16))
                                    Text("Night:")
                                        .font(.system(size: 15, weight: .medium))
                                        .frame(width: 80, alignment: .leading)
                                }
                                
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: {
                                            let formatter = DateFormatter()
                                            formatter.dateFormat = "h:mm a"
                                            return formatter.date(from: colorTheme.nightTime) ?? Date()
                                        },
                                        set: { newDate in
                                            let formatter = DateFormatter()
                                            formatter.dateFormat = "h:mm a"
                                            colorTheme.nightTime = formatter.string(from: newDate)
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .frame(width: 100)
                                
                                Spacer()
                            }
                            
                            // Noon Time with DatePicker
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "sun.max.fill")
                                        .foregroundColor(.yellow)
                                        .font(.system(size: 16))
                                    Text("Noon:")
                                        .font(.system(size: 15, weight: .medium))
                                        .frame(width: 80, alignment: .leading)
                                }
                                
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: {
                                            let formatter = DateFormatter()
                                            formatter.dateFormat = "h:mm a"
                                            return formatter.date(from: colorTheme.noonTime) ?? Date()
                                        },
                                        set: { newDate in
                                            let formatter = DateFormatter()
                                            formatter.dateFormat = "h:mm a"
                                            colorTheme.noonTime = formatter.string(from: newDate)
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .frame(width: 100)
                                
                                Spacer()
                            }
                        }
                        
                        Text("Examples: 'dinner tomorrow evening' → 6:00 PM, 'meeting monday morning' → uses Morning time")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .italic()
                            .padding(.top, 8)
                    }
                }
                
                Toggle("Syntax Highlighting", isOn: $colorTheme.colorHelpersEnabled)
                
                if colorTheme.colorHelpersEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Color Legend:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("Commands")
                                    .foregroundColor(.blue)
                                    .font(.caption2)
                                Text("- mv, rm, ls")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Dates")
                                    .foregroundColor(.yellow)
                                    .font(.caption2)
                                Text("- tm, td, mon, tue, wed, thu, fri, sat, sun")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Times")
                                    .foregroundColor(.red)
                                    .font(.caption2)
                                Text("- 9am, 3:45pm, morning, evening")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Connectors")
                                    .foregroundColor(.purple)
                                    .font(.caption2)
                                Text("- at, on, to, from, by")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            // Behavior Settings Section
            Section("Behavior Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default AM/PM for ambiguous times")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("When you create a reminder with a time like '5:46' (without AM/PM), this setting determines whether it defaults to morning or evening.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Button(action: { colorTheme.defaultAmPm = "AM" }) {
                            HStack(spacing: 8) {
                                Image(systemName: "sun.max")
                                    .font(.system(size: 16))
                                Text("AM")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(colorTheme.defaultAmPm == "AM" ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                colorTheme.defaultAmPm == "AM" ? 
                                colorTheme.primaryColor : Color(UIColor.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { colorTheme.defaultAmPm = "PM" }) {
                            HStack(spacing: 8) {
                                Image(systemName: "moon")
                                    .font(.system(size: 16))
                                Text("PM")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(colorTheme.defaultAmPm == "PM" ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                colorTheme.defaultAmPm == "PM" ? 
                                colorTheme.primaryColor : Color(UIColor.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    
                    Text("Example: 'remind me at 5:46' will create a reminder for 5:46 \(colorTheme.defaultAmPm)")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                
                
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Date Input Format")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Choose how you want to enter dates like '10/26'. This helps prevent confusion between month/day and day/month formats.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Button(action: { 
                            colorTheme.dateFormat = .mmdd 
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Image(systemName: "flag.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                    Text("MM/DD")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                Text("US Format")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(colorTheme.dateFormat == .mmdd ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                colorTheme.dateFormat == .mmdd ? 
                                colorTheme.primaryColor : Color(UIColor.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { 
                            colorTheme.dateFormat = .ddmm 
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                    Text("DD/MM")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                Text("International")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(colorTheme.dateFormat == .ddmm ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                colorTheme.dateFormat == .ddmm ? 
                                colorTheme.primaryColor : Color(UIColor.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    
                    Text(colorTheme.dateFormat.description)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                }
            }
            
            // Keyboard Extension Section
            Section("Keyboard Extension") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enable QuickReminders Keyboard")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Go to iPhone Settings")
                        Text("2. General → Keyboard → Keyboards")
                        Text("3. Add New Keyboard...")
                        Text("4. Select 'QuickReminders'")
                        Text("5. Enable 'Allow Full Access'")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Button("Open iPhone Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(colorTheme.primaryColor)
                }
                .padding(.vertical, 8)
            }
            
            // About Section
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.3.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Developer")
                    Spacer()
                    Text("Martin Kostelka")
                        .foregroundColor(.secondary)
                }
            }
            
            // Developer Contact Section
            Section("Developer") {
                // Email Link
                Link(destination: URL(string: "mailto:contact@prodbykosta.com")!) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("contact@prodbykosta.com")
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
                
                // Instagram Link
                Link(destination: URL(string: "https://instagram.com/prodbykosta")!) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.purple)
                            .frame(width: 20)
                        Text("@prodbykosta")
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
                
                // LinkedIn Link
                Link(destination: URL(string: "https://www.linkedin.com/in/prodbykosta/")!) {
                    HStack {
                        Image(systemName: "person.crop.square.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("LinkedIn Profile")
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
            }
            
            // Settings Section
            Section("Settings") {
                Button(action: {
                    showingResetConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle")
                            .foregroundColor(.red)
                        Text("Reset All Settings")
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.interactively)
        .onReceive(speechManager.$isAvailable) { isAvailable in
            // Auto-enable voice commands when microphone permission is granted
            if isAvailable && speechManager.hasPermissions() && !colorTheme.voiceActivationEnabled {
                colorTheme.voiceActivationEnabled = true
            }
        }
        .alert("Reset All Settings", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                colorTheme.resetAllSettings()
            }
        } message: {
            Text("This will reset all settings to their default values including themes, colors, shortcuts, voice settings, and time preferences. This action cannot be undone.")
        }
    }
}

// MARK: - Full Screen Animation Overlay

struct FullScreenAnimationOverlay: View {
    let status: AnimationStatus
    @ObservedObject var colorTheme: SharedColorThemeManager
    
    var body: some View {
        ZStack {
            // BEAUTIFUL GRADIENT BACKGROUND covering entire screen
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            animationStatusColor.opacity(0.8),
                            animationStatusColor.opacity(0.4),
                            animationStatusColor.opacity(0.2),
                            Color.black.opacity(0.3)
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 400
                    )
                )
                .ignoresSafeArea(.all)
                .animation(.easeInOut(duration: 1.0), value: status)
            
            // FLOATING PARTICLES
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                animationStatusColor.opacity(0.6),
                                animationStatusColor.opacity(0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 20
                        )
                    )
                    .frame(width: CGFloat.random(in: 20...40))
                    .offset(
                        x: CGFloat.random(in: -200...200),
                        y: CGFloat.random(in: -300...300)
                    )
                    .scaleEffect(
                        1.0 + sin(Date().timeIntervalSince1970 * Double.random(in: 1...3) + Double(index)) * 0.5
                    )
                    .animation(
                        .easeInOut(duration: Double.random(in: 2...4))
                            .repeatForever(autoreverses: true),
                        value: UUID()
                    )
            }
            
            // CENTER ANIMATION
            VStack(spacing: 32) {
                // Main animation icon
                ZStack {
                    // Pulsing background circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    animationStatusColor.opacity(0.3),
                                    animationStatusColor.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 100
                            )
                        )
                        .frame(width: 150, height: 150)
                        .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 2) * 0.2)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: UUID())
                    
                    // Status icon
                    Group {
                        switch status {
                        case .processing:
                            ZStack {
                                ProgressView()
                                    .scaleEffect(2.0)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                
                                // Orbiting particles
                                ForEach(0..<8, id: \.self) { index in
                                    Circle()
                                        .fill(.white.opacity(0.8))
                                        .frame(width: 8, height: 8)
                                        .offset(y: -40)
                                        .rotationEffect(.degrees(Double(index) * 45))
                                        .rotationEffect(.degrees(Date().timeIntervalSince1970 * 120))
                                        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: UUID())
                                }
                            }
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 80, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.5), radius: 20, x: 0, y: 10)
                                .scaleEffect(1.0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.4), value: status)
                        case .error:
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 80, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.5), radius: 20, x: 0, y: 10)
                                .scaleEffect(1.0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.4), value: status)
                        case .hidden:
                            EmptyView()
                        }
                    }
                }
                
                // Status message
                VStack(spacing: 12) {
                    if case .processing(let message) = status {
                        Text(message)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Using AI to understand your reminder...")
                            .font(.body.weight(.medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    } else if case .success(let message) = status {
                        Text(message)
                            .font(.title.weight(.bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 4)
                    } else if case .error(let message) = status {
                        Text(message)
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
    
    private var animationStatusColor: Color {
        switch status {
        case .processing:
            return colorTheme.primaryColor
        case .success:
            return colorTheme.successColor
        case .error:
            return colorTheme.errorColor
        case .hidden:
            return .clear
        }
    }
}

// MARK: - Quick Ideas Settings View

struct QuickIdeasSettingsView: View {
    @ObservedObject var colorTheme: SharedColorThemeManager
    @State private var newIdea = ""
    @Environment(\.dismiss) private var dismiss
    
    private let defaultIdeas = [
        "Call mom tomorrow",
        "Meeting Monday 10am",
        "Gym session 6pm",
        "Pay bills Friday"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Customize the quick reminder suggestions that appear in the create screen.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Add New Idea") {
                    HStack {
                        TextField("Enter a reminder idea...", text: $newIdea)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Add") {
                            colorTheme.addQuickIdea(newIdea)
                            newIdea = ""
                        }
                        .disabled(newIdea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                
                Section("Your Custom Ideas") {
                    if colorTheme.customQuickIdeas.isEmpty {
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.orange)
                            Text("No custom ideas yet. Add some above!")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(colorTheme.customQuickIdeas, id: \.self) { idea in
                            HStack {
                                Text(idea)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button {
                                    colorTheme.removeQuickIdea(idea)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Button("Reset to Defaults") {
                            colorTheme.resetQuickIdeasToDefault()
                        }
                        .foregroundColor(.orange)
                    }
                }
                
                Section("Default Ideas") {
                    ForEach(defaultIdeas, id: \.self) { idea in
                        HStack {
                            Text(idea)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if colorTheme.customQuickIdeas.contains(idea) {
                                Text("Added")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(4)
                            } else {
                                Button("Add") {
                                    colorTheme.addQuickIdea(idea)
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Quick Ideas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
#endif
