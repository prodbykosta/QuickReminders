//
//  NativeIOSAppView.swift
//  QuickReminders - iOS
//
//  Clean, native Apple design matching STUDY_FLASHCARDS style
//
#if os(iOS)
import SwiftUI
import EventKit
import Foundation

struct NativeIOSAppView: View {
    @StateObject private var colorTheme = SharedColorThemeManager()
    @StateObject private var animationManager = AnimationManager()
    @StateObject private var reminderManager: SharedReminderManager
    
    init() {
        let theme = SharedColorThemeManager()
        _colorTheme = StateObject(wrappedValue: theme)
        _reminderManager = StateObject(wrappedValue: SharedReminderManager(colorTheme: theme))
    }
    
    var body: some View {
        TabView {
            // Main Reminders Tab
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
            
            // Create Reminder Tab
            NavigationView {
                CreateReminderView(
                    reminderManager: reminderManager,
                    colorTheme: colorTheme,
                    animationManager: animationManager
                )
            }
            .tabItem {
                Image(systemName: "plus.circle")
                Text("Create")
            }
            
            // Settings Tab
            NavigationView {
                NativeSettingsView(
                    colorTheme: colorTheme,
                    reminderManager: reminderManager
                )
            }
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
        }
        .accentColor(colorTheme.primaryColor)
    }
}

// MARK: - Reminders List View

struct RemindersListView: View {
    @ObservedObject var reminderManager: SharedReminderManager
    @ObservedObject var colorTheme: SharedColorThemeManager
    @ObservedObject var animationManager: AnimationManager
    
    @State private var reminders: [EKReminder] = []
    @State private var searchText = ""
    @State private var showingPermissionAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            if !reminderManager.hasAccess {
                PermissionRequiredView(reminderManager: reminderManager)
            } else if reminders.isEmpty {
                EmptyRemindersView()
            } else {
                List {
                    ForEach(Array(groupedReminders.keys.sorted()), id: \.self) { listName in
                        // STATIC GROUP HEADER (not sticky)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(Color(cgColor: (groupedReminders[listName]?.first?.calendar?.cgColor ?? CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0))))
                                    .frame(width: 12, height: 12)
                                
                                Text(listName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                
                                Text("(\(groupedReminders[listName]?.count ?? 0))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        
                        // REMINDERS IN THIS GROUP
                        ForEach(groupedReminders[listName] ?? [], id: \.calendarItemIdentifier) { reminder in
                            ReminderRowView(
                                reminder: reminder,
                                colorTheme: colorTheme,
                                onComplete: { toggleReminder(reminder) },
                                onDelete: { deleteReminder(reminder) }
                            )
                            .listRowBackground(Color(UIColor.systemBackground))
                        }
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search reminders...")
            }
        }
        .navigationTitle("All Reminders")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Refresh") {
                    loadReminders()
                }
                .font(.body.weight(.medium))
                .foregroundColor(colorTheme.boltColor)
            }
        }
        .onAppear {
            loadReminders()
        }
        .refreshable {
            loadReminders()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Auto-refresh when app becomes active
            loadReminders()
        }
        .onChange(of: reminderManager.hasAccess) { _, hasAccess in
            // Load reminders when permissions are granted
            if hasAccess {
                loadReminders()
            }
        }
    }
    
    private var filteredReminders: [EKReminder] {
        if searchText.isEmpty {
            return reminders
        } else {
            return reminders.filter { reminder in
                reminder.title?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
    
    // Group reminders by list/calendar name
    private var groupedReminders: [String: [EKReminder]] {
        Dictionary(grouping: filteredReminders) { reminder in
            reminder.calendar?.title ?? "Unknown List"
        }
    }
    
    private func loadReminders() {
        // Force refresh the available lists first
        Task {
            await reminderManager.reloadReminderLists()
            
            // Then load ALL reminders
            reminderManager.getAllReminders { fetchedReminders in
                DispatchQueue.main.async {
                    // Show ALL reminders (not completed)
                    self.reminders = fetchedReminders.filter { !$0.isCompleted }
                }
            }
        }
    }
    
    private func toggleReminder(_ reminder: EKReminder) {
        reminder.isCompleted = !reminder.isCompleted
        try? reminderManager.eventStore.save(reminder, commit: true)
        loadReminders()
    }
    
    private func deleteReminder(_ reminder: EKReminder) {
        reminderManager.deleteReminder(reminder) { success, error in
            if success {
                loadReminders()
            }
        }
    }
}

// MARK: - Create Reminder View

struct CreateReminderView: View {
    @ObservedObject var reminderManager: SharedReminderManager
    @ObservedObject var colorTheme: SharedColorThemeManager
    @ObservedObject var animationManager: AnimationManager
    
    @State private var reminderText = ""
    @State private var isProcessing = false
    @FocusState private var isTextFieldFocused: Bool
    
    // Quick suggestions matching STUDY_FLASHCARDS style
    private let quickSuggestions = [
        "Call mom tomorrow",
        "Meeting Monday 10am",
        "Gym session 6pm",
        "Pay bills Friday"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header section
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [colorTheme.primaryColor, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Create Reminder")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.primary)
                    
                    Text("Type naturally - I'll understand when and what you want to remember")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // Input section
                VStack(spacing: 16) {
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
                    
                    // Create button
                    Button(action: createReminder) {
                        HStack {
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
                }
                .padding(.horizontal, 20)
                
                // Quick suggestions
                if reminderText.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Ideas")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
            }
        }
        .navigationTitle("Create")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Clear") {
                    reminderText = ""
                }
                .font(.body.weight(.medium))
                .foregroundColor(colorTheme.primaryColor)
                .disabled(reminderText.isEmpty)
            }
        }
    }
    
    private func createReminder() {
        guard !reminderText.isEmpty, !isProcessing else { return }
        
        isProcessing = true
        
        Task {
            do {
                try await reminderManager.createReminder(from: reminderText)
                
                await MainActor.run {
                    reminderText = ""
                    isProcessing = false
                    isTextFieldFocused = false
                    
                    // Show success feedback
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    
                    // Show error feedback
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.error)
                }
            }
        }
    }
}

// MARK: - Settings View

struct NativeSettingsView: View {
    @ObservedObject var colorTheme: SharedColorThemeManager
    @ObservedObject var reminderManager: SharedReminderManager
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundColor(colorTheme.primaryColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("QuickReminders")
                            .font(.headline.weight(.bold))
                        Text("Smart reminder creation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            Section("Appearance") {
                Picker("Theme", selection: $colorTheme.appearanceTheme) {
                    ForEach(AppearanceTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                
                ColorPicker("Accent Color", selection: $colorTheme.primaryColor)
            }
            
            Section("Reminders") {
                Picker("Default List", selection: Binding<String>(
                    get: { reminderManager.selectedList?.title ?? "Default" },
                    set: { _ in }
                )) {
                    ForEach(reminderManager.availableLists, id: \.calendarIdentifier) { list in
                        Text(list.title).tag(list.title)
                    }
                }
                
                Toggle("Smart Time Detection", isOn: $colorTheme.timePeriodsEnabled)
                
                Picker("Date Format", selection: $colorTheme.dateFormat) {
                    ForEach(DateFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
            }
            
            Section("Keyboard Extension") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enable QuickReminders Keyboard")
                        .font(.headline)
                    
                    Text("Go to Settings > General > Keyboard > Keyboards > Add New Keyboard... > QuickReminders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Open Settings") {
                        if let settingsUrl = URL(string: "prefs:root=General&path=Keyboard/KEYBOARDS") {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(colorTheme.primaryColor)
                }
                .padding(.vertical, 4)
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Supporting Views

struct ReminderRowView: View {
    let reminder: EKReminder
    @ObservedObject var colorTheme: SharedColorThemeManager
    let onComplete: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onComplete) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(reminder.isCompleted ? colorTheme.successColor : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title ?? "Untitled")
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                    .strikethrough(reminder.isCompleted)
                
                if let dueDate = reminder.dueDateComponents?.date {
                    Text(dueDate, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Show recurring indicator under the time (like native Reminders)
                if let recurrenceRules = reminder.recurrenceRules, !recurrenceRules.isEmpty,
                   let rule = recurrenceRules.first {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(recurrenceFrequencyText(from: rule))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

struct EmptyRemindersView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Reminders")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
            
            Text("Create your first reminder using the Create tab or the keyboard extension")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PermissionRequiredView: View {
    @ObservedObject var reminderManager: SharedReminderManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.circle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Permission Required")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
            
            Text("QuickReminders needs access to your reminders to create and manage them.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Grant Permission") {
                reminderManager.requestPermissionManually()
            }
            .font(.body.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.blue)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Helper Functions

private func recurrenceFrequencyText(from rule: EKRecurrenceRule) -> String {
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
