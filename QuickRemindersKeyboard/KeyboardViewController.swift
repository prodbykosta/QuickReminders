//
//  KeyboardViewController.swift
//  QuickReminders Keyboard
//
//  Beautiful custom keyboard extension for global access to QuickReminders
//

#if os(iOS)
import UIKit
import SwiftUI
import EventKit
import Speech
import AVFoundation
import AudioToolbox

// Simple functional keyboard for testing
struct TestKeyboardView: View {
    let onKeyTap: (String) -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Text("QuickReminders Keyboard")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
            
            VStack(spacing: 8) {
                // Top row
                HStack(spacing: 6) {
                    ForEach(["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"], id: \.self) { letter in
                        TestKeyButton(text: letter, onTap: onKeyTap)
                    }
                }
                
                // Middle row
                HStack(spacing: 6) {
                    ForEach(["A", "S", "D", "F", "G", "H", "J", "K", "L"], id: \.self) { letter in
                        TestKeyButton(text: letter, onTap: onKeyTap)
                    }
                }
                
                // Bottom row
                HStack(spacing: 6) {
                    ForEach(["Z", "X", "C", "V", "B", "N", "M"], id: \.self) { letter in
                        TestKeyButton(text: letter, onTap: onKeyTap)
                    }
                }
                
                // Space and Return
                HStack(spacing: 6) {
                    Button("Space") {
                        onKeyTap(" ")
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    
                    Button("Return") {
                        onKeyTap("\n")
                    }
                    .frame(width: 80, height: 40)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
            .padding()
        }
        .frame(height: 250)
        .background(Color.black.opacity(0.8))
    }
}

struct TestKeyButton: View {
    let text: String
    let onTap: (String) -> Void
    
    var body: some View {
        Button(text) {
            onTap(text.lowercased())
        }
        .frame(width: 30, height: 40)
        .background(Color.white)
        .foregroundColor(.black)
        .cornerRadius(6)
    }
}

struct SimpleKeyButton: View {
    let text: String
    let displayText: String
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            Text(displayText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isPressed ? Color.gray.opacity(0.4) : Color.white)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            // Quick visual feedback
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }
    }
}


// Working keyboard with entry field
struct WorkingKeyboardView: View {
    let onTextInput: (String) -> Void
    let onProcess: (String) -> Void
    let onNextKeyboard: (() -> Void)?
    
    @State private var inputText = ""
    @State private var keyboardMode = 0 // 0=letters, 1=numbers, 2=symbols
    @State private var showKeyboard = false
    @State private var currentView: ViewMode = .entry
    @State private var isShiftPressed = false
    @State private var isCapsLocked = false
    @State private var foundReminders: [EKReminder] = []
    @State private var duplicateReminders: [EKReminder] = []
    @State private var isLoadingReminders = false
    @State private var isSearchingDuplicates = false
    @State private var listCommand = ""
    @State private var removeCommand = ""
    @State private var moveCommand = ""
    @State private var moveTargetDate: Date?
    @State private var moveTargetReminder: SharedParsedReminder?
    @State private var selectedTab: TabType = .create
    @State private var updateFeedback = ""
    @State private var showingListPicker = false
    @FocusState private var isFieldFocused: Bool
    
    // Add reminder manager for actual EventKit access
    @StateObject private var reminderManager: SharedReminderManager
    @StateObject private var colorTheme: SharedColorThemeManager
    
    init(onTextInput: @escaping (String) -> Void, onProcess: @escaping (String) -> Void, onNextKeyboard: (() -> Void)? = nil, colorTheme: SharedColorThemeManager? = nil, reminderManager: SharedReminderManager? = nil) {
        self.onTextInput = onTextInput
        self.onProcess = onProcess
        self.onNextKeyboard = onNextKeyboard
        
        if let theme = colorTheme, let manager = reminderManager {
            // Use provided instances
            self._colorTheme = StateObject(wrappedValue: theme)
            self._reminderManager = StateObject(wrappedValue: manager)
        } else {
            // Create new instances (fallback)
            let theme = SharedColorThemeManager()
            self._colorTheme = StateObject(wrappedValue: theme)
            self._reminderManager = StateObject(wrappedValue: SharedReminderManager(colorTheme: theme))
        }
    }
    
    enum ViewMode {
        case entry
        case keyboard
        case list
        case remove
        case move
    }
    
    enum TabType: String, CaseIterable {
        case create = "Create"
        case today = "Today"
        case reminders = "Reminders"
        
        var icon: String {
            switch self {
            case .create: return "plus.circle"
            case .today: return "calendar"
            case .reminders: return "checklist"
            }
        }
    }
    
    // Dynamic quick actions based on available reminder lists
    @State private var quickActions: [String] = [
        "list",
        "move", 
        "remove"
    ]
    
    // Fixed consistent height for all views - perfect size
    private var keyboardHeight: CGFloat {
        return 330  // Perfect fixed height with proper room
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if selectedTab == .create {
                // Header section - only visible on Create tab
                headerSection
            }
            
            // Main content area - changes based on tab and keyboard state
            mainContentArea
            
            // Bottom tabs - always visible
            bottomTabsSection
        }
        .frame(height: keyboardHeight)
        .background(
            LinearGradient(
                colors: [
                    colorTheme.primaryColor.opacity(0.1),
                    colorTheme.successColor.opacity(0.05),
                    Color(UIColor.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .animation(.easeInOut(duration: 0.3), value: showKeyboard)
        .animation(.easeInOut(duration: 0.3), value: currentView)
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
        .sheet(isPresented: $showingListPicker) {
            KeyboardListPickerView(
                reminderManager: reminderManager,
                colorTheme: colorTheme,
                isPresented: $showingListPicker
            )
        }
        .onAppear {
            // Request permissions and reload lists to ensure keyboard has access
            reminderManager.requestPermissionManually()
            Task {
                await reminderManager.reloadReminderLists()
                // Update quick actions after lists are loaded
                DispatchQueue.main.async {
                    self.updateQuickActions()
                }
            }
        }
    }
    
    // MARK: - New Layout Sections
    
    var headerSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    showingListPicker = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(colorTheme.primaryColor)
                        
                        Text(colorTheme.selectedListName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                if showKeyboard {
                    Button("Done") {
                        hideKeyboard()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colorTheme.primaryColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Text input field - only show when Create tab is selected
            HStack {
                TextField("What would you like to remember?", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isFieldFocused ? colorTheme.primaryColor : Color(UIColor.separator), lineWidth: isFieldFocused ? 2 : 1)
                            )
                    )
                    .focused($isFieldFocused)
                    .onChange(of: isFieldFocused) { _, focused in
                        if focused {
                            showKeyboard = true
                            currentView = .keyboard
                        }
                    }
                
                Button(action: {
                    if !inputText.isEmpty {
                        // Check for commands when sending - EXACT same logic as send button
                        let command = inputText.lowercased()
                        let listKeywords = colorTheme.shortcutsEnabled ? ["ls", "list"] : ["list"]
                        if listKeywords.contains(where: { command.hasPrefix($0) }) {
                            currentView = .list
                            // Store the full command for date filtering
                            listCommand = inputText
                            inputText = ""
                            // Unfocus text field when showing list
                            isFieldFocused = false
                        } else if command.hasPrefix("rm ") || command.hasPrefix("remove ") {
                            currentView = .remove
                            // Store the full command for searching
                            removeCommand = inputText
                            inputText = ""
                            // Unfocus text field when showing remove
                            isFieldFocused = false
                        } else if command.hasPrefix("mv ") || command.hasPrefix("move ") {
                            currentView = .move
                            // Store the full command for moving
                            moveCommand = inputText
                            inputText = ""
                            // Unfocus text field when showing move
                            isFieldFocused = false
                        } else {
                            // Regular reminder - process but keep keyboard visible
                            onProcess(inputText)
                            inputText = ""
                            // Keep keyboard visible and maintain focus - DON'T switch to Apple keyboard
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.isFieldFocused = true
                                self.showKeyboard = true
                                self.currentView = .keyboard
                            }
                        }
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(colorTheme.primaryColor)
                }
            }
            .padding(.horizontal, 16)
            .onTapGesture {
                showKeyboard = true
                currentView = .keyboard
                isFieldFocused = true
                
                // Clear any commands when returning to keyboard
                listCommand = ""
                removeCommand = ""
                moveCommand = ""
                foundReminders = []
                duplicateReminders = []
                moveTargetDate = nil
                moveTargetReminder = nil
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isFieldFocused = true
                }
            }
            .opacity(selectedTab == .create ? 1 : 0)
        }
        .padding(.bottom, 0)
    }
    
    var mainContentArea: some View {
        VStack(spacing: 0) {
            if selectedTab == .create {
                if showKeyboard {
                    switch currentView {
                    case .entry:
                        EmptyView()
                    case .keyboard:
                        keyboardSection
                    case .list:
                        listSection
                    case .remove:
                        removeSection
                    case .move:
                        moveSection
                    }
                } else {
                    // Quick Actions - shown when keyboard is hidden
                    quickActionsSection
                }
            } else if selectedTab == .today {
                todaySection
            } else if selectedTab == .reminders {
                remindersSection
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    var bottomTabsSection: some View {
        HStack(spacing: 0) {
            ForEach(TabType.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                    // Hide keyboard when switching tabs
                    if tab != .create {
                        showKeyboard = false
                        isFieldFocused = false
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedTab == tab ? colorTheme.primaryColor : .gray)
                        
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(selectedTab == tab ? colorTheme.primaryColor : .gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(
            Rectangle()
                .fill(Color(UIColor.separator))
                .frame(height: 0.5),
            alignment: .top
        )
    }
    
    var todaySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("📅 Today's Reminders")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button("Refresh") {
                    loadTodayReminders()
                }
                .font(.system(size: 12))
                .foregroundColor(colorTheme.primaryColor)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Auto-load today's reminders
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(foundReminders, id: \.calendarItemIdentifier) { reminder in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(cgColor: reminder.calendar?.cgColor ?? CGColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)))
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reminder.title ?? "Untitled")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                if let dueDate = reminder.dueDateComponents?.date {
                                    Text(formatDate(dueDate))
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }
                                
                                // Show recurring indicator under the time (like native Reminders)
                                if let recurrenceRules = reminder.recurrenceRules, !recurrenceRules.isEmpty,
                                   let rule = recurrenceRules.first {
                                    HStack(spacing: 2) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 8))
                                            .foregroundColor(.gray)
                                        
                                        Text(keyboardControllerRecurrenceText(from: rule))
                                            .font(.system(size: 8))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                        .contextMenu {
                            Button(action: {
                                completeReminder(reminder)
                            }) {
                                Text("Complete")
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Button(action: {
                                deleteReminder(reminder)
                            }) {
                                Text("Remove")
                                Image(systemName: "trash.fill")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: .infinity) // Use infinity to fill space
        }
        .frame(height: 280)
        .onAppear {
            // Load today's reminders
            loadTodayReminders()
        }
    }
    
    var remindersSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("📝 All Reminders")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button("Refresh") {
                    loadReminders()
                }
                .font(.system(size: 12))
                .foregroundColor(colorTheme.primaryColor)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(foundReminders, id: \.calendarItemIdentifier) { reminder in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(cgColor: reminder.calendar?.cgColor ?? CGColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)))
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reminder.title ?? "Untitled")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                if let dueDate = reminder.dueDateComponents?.date {
                                    Text(formatDate(dueDate))
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }
                                
                                // Show recurring indicator under the time (like native Reminders)
                                if let recurrenceRules = reminder.recurrenceRules, !recurrenceRules.isEmpty,
                                   let rule = recurrenceRules.first {
                                    HStack(spacing: 2) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 8))
                                            .foregroundColor(.gray)
                                        
                                        Text(keyboardControllerRecurrenceText(from: rule))
                                            .font(.system(size: 8))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                        .contextMenu {
                            Button(action: {
                                completeReminder(reminder)
                            }) {
                                Text("Complete")
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Button(action: {
                                deleteReminder(reminder)
                            }) {
                                Text("Remove")
                                Image(systemName: "trash.fill")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxHeight: .infinity) // Use infinity to fill space
        }
        .frame(height: 280)
        .onAppear {
            loadReminders()
        }
    }
    
    var keyboardSection: some View {
        VStack(spacing: 6) {
            if keyboardMode == 0 {
                // Letters keyboard
                letterRows
            } else if keyboardMode == 1 {
                // Numbers keyboard
                numberRows
            } else {
                // Symbols keyboard
                symbolRows
            }
            
            // Bottom row with space and controls - compact like iPhone
            HStack(spacing: 2) {
                // Next keyboard button (globe icon) - for switching keyboards
                Button(action: {
                    playKeySound()
                    // This should trigger the keyboard switch
                    if let keyboardController = onNextKeyboard {
                        keyboardController()
                    }
                }) {
                    Image(systemName: "globe")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 50, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.3))
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
                
                // Mode switch
                Button(action: {
                    playKeySound()
                    if keyboardMode == 0 {
                        keyboardMode = 1 // letters to numbers
                    } else {
                        keyboardMode = 0 // numbers/symbols back to letters
                    }
                }) {
                    Text(keyboardMode == 0 ? "123" : "ABC")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 55, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.3))
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
                
                // Space bar - much wider like iPhone
                Button(action: {
                    playKeySound()
                    appendText(" ")
                }) {
                    Text("space")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
                
                // Return key - works as send button
                Button(action: {
                    playKeySound()
                    // Send the reminder instead of adding newline
                    if !inputText.isEmpty {
                        let command = inputText.lowercased()
                        let listKeywords = colorTheme.shortcutsEnabled ? ["ls", "list"] : ["list"]
                        if listKeywords.contains(where: { command.hasPrefix($0) }) {
                            currentView = .list
                            // Store the full command for date filtering
                            listCommand = inputText
                            inputText = ""
                            // Unfocus text field when showing list
                            isFieldFocused = false
                        } else if command.hasPrefix("rm ") || command.hasPrefix("remove ") {
                            currentView = .remove
                            // Store the full command for searching
                            removeCommand = inputText
                            inputText = ""
                            // Unfocus text field when showing remove
                            isFieldFocused = false
                        } else if command.hasPrefix("mv ") || command.hasPrefix("move ") {
                            currentView = .move
                            // Store the full command for moving
                            moveCommand = inputText
                            inputText = ""
                            // Unfocus text field when showing move
                            isFieldFocused = false
                        } else {
                            // Regular reminder - process but keep keyboard visible
                            onProcess(inputText)
                            inputText = ""
                            // Keep keyboard visible and maintain focus - DON'T switch to Apple keyboard
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.isFieldFocused = true
                                self.showKeyboard = true
                                self.currentView = .keyboard
                            }
                        }
                    }
                }) {
                    Text("send")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 60, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.blue)
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
            }
            .padding(.horizontal, 3)
        }
        .padding(.vertical, 8)
                .frame(height: 200)  // Bigger sections for 320pt keyboard
    }
    
    var listSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text(getListSectionTitle())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button("Refresh") {
                    loadReminders()
                }
                .font(.system(size: 12))
                .foregroundColor(colorTheme.primaryColor)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            if isLoadingReminders {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading reminders...")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding()
            } else if foundReminders.isEmpty {
                VStack(spacing: 4) {
                    Text("No reminders found")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Text("Create some reminders first, then use 'ls'")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(foundReminders.prefix(10), id: \.calendarItemIdentifier) { reminder in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(cgColor: reminder.calendar?.cgColor ?? CGColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)))
                                    .frame(width: 8, height: 8)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reminder.title ?? "Untitled")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    if let dueDate = reminder.dueDateComponents?.date {
                                        Text(formatDate(dueDate))
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(maxHeight: 140)
            }
        }
                .frame(height: 200)  // Bigger sections for 320pt keyboard
        .onAppear {
            // Load reminders immediately for smoother experience
            loadReminders()
        }
        .onChange(of: listCommand) { _, _ in
            // Auto-load when listCommand changes
            if !listCommand.isEmpty {
                loadReminders()
            }
        }
    }
    
    var removeSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("🗑️ Remove Reminders")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button("Search") {
                    searchForRemoval()
                }
                .font(.system(size: 12))
                .foregroundColor(.red)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            if isSearchingDuplicates {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching for reminders...")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding()
            } else if duplicateReminders.isEmpty {
                VStack(spacing: 8) {
                    Text("Enter: rm \"reminder name\"")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                    Text("Then use Send to find and remove")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(duplicateReminders.prefix(10), id: \.calendarItemIdentifier) { reminder in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(cgColor: reminder.calendar?.cgColor ?? CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)))
                                    .frame(width: 8, height: 8)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reminder.title ?? "Untitled")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    if let dueDate = reminder.dueDateComponents?.date {
                                        Text(formatDate(dueDate))
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Spacer()
                                
                                Button("Remove") {
                                    deleteReminder(reminder)
                                    // Close section after removing
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        self.currentView = .keyboard
                                        self.removeCommand = ""
                                        self.duplicateReminders = []
                                    }
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .cornerRadius(4)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(maxHeight: 140)
            }
        }
                .frame(height: 200)  // Bigger sections for 320pt keyboard
        .onAppear {
            if !removeCommand.isEmpty {
                searchForRemoval()
            }
        }
        .onChange(of: removeCommand) { _, _ in
            // Auto-search when removeCommand changes
            if !removeCommand.isEmpty {
                searchForRemoval()
            }
        }
    }
    
    var moveSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("📅 Move Reminders")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button("Search") {
                    searchForMove()
                }
                .font(.system(size: 12))
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            if isSearchingDuplicates {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching for reminders...")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding()
            } else if duplicateReminders.isEmpty {
                VStack(spacing: 8) {
                    Text("Enter: mv \"reminder\" to friday")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    Text("Then use Send to find and move")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .padding()
            } else {
                VStack(spacing: 8) {
                    if let targetReminder = moveTargetReminder {
                        VStack(spacing: 4) {
                            if let dueDate = targetReminder.dueDate {
                                Text("Moving to: \(formatDate(dueDate))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            
                            if targetReminder.isRecurring {
                                HStack(spacing: 4) {
                                    Image(systemName: "repeat")
                                        .font(.system(size: 10))
                                        .foregroundColor(.orange)
                                    Text(getRecurrenceDescription(targetReminder))
                                        .font(.system(size: 10))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(duplicateReminders.prefix(10), id: \.calendarItemIdentifier) { reminder in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(cgColor: reminder.calendar?.cgColor ?? CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0)))
                                        .frame(width: 8, height: 8)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(reminder.title ?? "Untitled")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        if let dueDate = reminder.dueDateComponents?.date {
                                            Text("Current: \(formatDate(dueDate))")
                                                .font(.system(size: 10))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Move") {
                                        moveReminder(reminder)
                                        // Close section after moving
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            self.currentView = .keyboard
                                            self.moveCommand = ""
                                            self.duplicateReminders = []
                                            self.moveTargetDate = nil
                                            self.moveTargetReminder = nil
                                        }
                                    }
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(maxHeight: 160)
                }
            }
        }
        .onAppear {
            if !moveCommand.isEmpty {
                searchForMove()
            }
        }
        .onChange(of: moveCommand) { _, _ in
            // Auto-search when moveCommand changes
            if !moveCommand.isEmpty {
                searchForMove()
            }
        }
    }
    
    var quickActionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button("Refresh") {
                    Task {
                        await reminderManager.reloadReminderLists()
                        DispatchQueue.main.async {
                            self.updateQuickActions()
                        }
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(colorTheme.primaryColor)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24) // Increased from 16 to 24 to lower it
            
            if !quickActions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(quickActions, id: \.self) { action in
                            Button(action: {
                                inputText = action
                                showKeyboard = true
                                currentView = .keyboard
                                isFieldFocused = true
                            }) {
                                Text(action)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(UIColor.secondarySystemBackground))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(colorTheme.primaryColor.opacity(0.4), lineWidth: 1.5)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
            
            Spacer()
            }
        }
                .frame(height: 200)  // Bigger sections for 320pt keyboard
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
    }
    
    // Commands are now detected only when sending, not while typing
    
    func hideKeyboard() {
        showKeyboard = false
        currentView = .entry
        isFieldFocused = false
    }
    
    var letterRows: some View {
        VStack(spacing: 6) {
            // Top row - 10 keys
            HStack(spacing: 3) {
                ForEach(["Q","W","E","R","T","Y","U","I","O","P"], id: \.self) { key in
                    standardKeyButton(key)
                }
            }
            
            // Middle row - 9 keys with spacing
            HStack(spacing: 3) {
                Spacer().frame(width: 18) // Half key width
                ForEach(["A","S","D","F","G","H","J","K","L"], id: \.self) { key in
                    standardKeyButton(key)
                }
                Spacer().frame(width: 18) // Half key width
            }
            
            // Bottom row - shift + 7 keys + backspace
            HStack(spacing: 3) {
                // Shift key
                Button(action: {
                    playKeySound()
                    handleShiftPress()
                }) {
                    Image(systemName: getShiftIcon())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(getShiftColor())
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
                
                ForEach(["Z","X","C","V","B","N","M"], id: \.self) { key in
                    standardKeyButton(key)
                }
                
                // Backspace key
                Button(action: {
                    playKeySound()
                    if !inputText.isEmpty {
                        inputText.removeLast()
                    }
                }) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.3))
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
            }
        }
        .padding(.horizontal, 3)
    }
    
    var numberRows: some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(["1","2","3","4","5","6","7","8","9","0"], id: \.self) { key in
                    standardKeyButton(key)
                }
            }
            HStack(spacing: 3) {
                Spacer().frame(width: 18)
                ForEach(["-","/",":",";","(",")","$","&","@"], id: \.self) { key in
                    standardKeyButton(key)
                }
                Spacer().frame(width: 18)
            }
            HStack(spacing: 3) {
                Button(action: {
                    playKeySound()
                    keyboardMode = 2 // Switch to symbols mode
                }) {
                    Text("#+=")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.3))
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
                
                ForEach([".",",","?","!","'","\""], id: \.self) { key in
                    standardKeyButton(key)
                }
                
                Button(action: {
                    playKeySound()
                    if !inputText.isEmpty {
                        inputText.removeLast()
                    }
                }) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.3))
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
            }
        }
        .padding(.horizontal, 3)
    }
    
    var symbolRows: some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="], id: \.self) { key in
                    standardKeyButton(key)
                }
            }
            HStack(spacing: 3) {
                Spacer().frame(width: 18)
                ForEach(["_", "\\", "|", "~", "<", ">", "€", "£", "¥"], id: \.self) { key in
                    standardKeyButton(key)
                }
                Spacer().frame(width: 18)
            }
            HStack(spacing: 3) {
                Button(action: {
                    playKeySound()
                    keyboardMode = 1 // Go back to numbers
                }) {
                    Text("123")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.3))
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
                
                ForEach(["§", "©", "®", "™", "✓", "°"], id: \.self) { key in
                    standardKeyButton(key)
                }
                
                Button(action: {
                    playKeySound()
                    if !inputText.isEmpty {
                        inputText.removeLast()
                    }
                }) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.gray.opacity(0.3))
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
            }
        }
        .padding(.horizontal, 3)
    }
    
    func standardKeyButton(_ text: String) -> some View {
        SimpleKeyButton(
            text: text,
            displayText: getDisplayText(text),
            onTap: {
                playKeySound()
                let finalText = shouldUseUppercase() ? text.uppercased() : text.lowercased()
                appendText(finalText)
                
                // Auto-disable shift after typing (unless caps lock)
                if isShiftPressed && !isCapsLocked {
                    isShiftPressed = false
                }
            }
        )
        .frame(maxWidth: .infinity) // Fill available space like iPhone
    }
    
    func getDisplayText(_ text: String) -> String {
        // Show lowercase by default, uppercase only when shift/caps is active
        if isShiftPressed || isCapsLocked {
            return text.uppercased()
        } else {
            return text.lowercased() // Show lowercase by default
        }
    }
    
    func appendText(_ text: String) {
        inputText += text
        onTextInput(text)
    }
    
    func shouldUseUppercase() -> Bool {
        return isShiftPressed || isCapsLocked
    }
    
    func handleShiftPress() {
        playKeySound()
        if isShiftPressed {
            // If already pressed, toggle caps lock
            isCapsLocked.toggle()
            isShiftPressed = isCapsLocked
        } else {
            // First press - enable shift
            isShiftPressed = true
            isCapsLocked = false
        }
    }
    
    func getShiftIcon() -> String {
        if isCapsLocked {
            return "capslock.fill"
        } else if isShiftPressed {
            return "shift.fill"
        } else {
            return "shift"
        }
    }
    
    func getShiftColor() -> Color {
        if isCapsLocked {
            return Color.blue.opacity(0.3)
        } else if isShiftPressed {
            return Color.gray.opacity(0.5)
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    func playKeySound() {
        // Play iOS keyboard click sound
        AudioServicesPlaySystemSound(1104) // Keyboard click sound
    }
    
    // Helper functions for reminder management
    func loadReminders() {
        isLoadingReminders = true
        foundReminders = []
        
        // Parse the date/time filter from the command
        let dateFilter = parseDateFromCommand(listCommand)
        let listNameFilter = parseListNameFromCommand(listCommand)
        
        // If we have a list name filter, search in specific list
        if let listName = listNameFilter {
            let targetList = reminderManager.availableLists.first { list in
                list.title.lowercased().contains(listName.lowercased())
            }
            
            if let list = targetList {
                let predicate = reminderManager.eventStore.predicateForReminders(in: [list])
                reminderManager.eventStore.fetchReminders(matching: predicate) { reminders in
                    DispatchQueue.main.async {
                        self.foundReminders = Array((reminders ?? []))
                        self.isLoadingReminders = false
                    }
                }
                return
            }
        }
        
        reminderManager.getAllReminders { allReminders in
            DispatchQueue.main.async {
                var filteredReminders = allReminders
                
                // Apply date filtering if specified
                if let targetDate = dateFilter {
                    filteredReminders = allReminders.filter { reminder in
                        guard let dueDate = reminder.dueDateComponents?.date else {
                            return false // Only show reminders with due dates for date-specific queries
                        }
                        return Calendar.current.isDate(dueDate, inSameDayAs: targetDate)
                    }
                } else if !self.listCommand.isEmpty && (self.listCommand.lowercased().contains("week") || self.listCommand.lowercased().contains("month")) {
                    // Handle week/month filters
                    filteredReminders = self.filterRemindersForPeriod(allReminders, command: self.listCommand)
                }
                
                self.foundReminders = Array(filteredReminders)
                self.isLoadingReminders = false
            }
        }
    }
    
    func loadTodayReminders() {
        isLoadingReminders = true
        foundReminders = []
        
        reminderManager.getAllReminders { allReminders in
            DispatchQueue.main.async {
                let today = Date()
                let todayReminders = allReminders.filter { reminder in
                    guard let dueDate = reminder.dueDateComponents?.date else {
                        return false
                    }
                    return Calendar.current.isDate(dueDate, inSameDayAs: today)
                }
                
                self.foundReminders = Array(todayReminders.prefix(10))
                self.isLoadingReminders = false
            }
        }
    }
    
    func updateQuickActions() {
        // Start with base commands
        var actions = ["list", "move", "remove"]
        
        // Add "list [ListName]" for each available list
        for list in reminderManager.availableLists {
            let listName = list.title
            actions.append("list \(listName)")
        }
        
        // Update the quick actions
        DispatchQueue.main.async {
            self.quickActions = actions
        }
    }
    
    func searchForRemoval() {
        isSearchingDuplicates = true
        duplicateReminders = []
        
        if removeCommand.isEmpty {
            isSearchingDuplicates = false
            return
        }
        
        // Extract search term from command
        let searchTerm = removeCommand.lowercased()
            .replacingOccurrences(of: "^(rm|remove)\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if searchTerm.isEmpty {
            isSearchingDuplicates = false
            return
        }
        
        
        reminderManager.findReminder(withTitle: searchTerm) { reminders in
            DispatchQueue.main.async {
                if reminders.count == 1 {
                    // Only one reminder found - delete it automatically
                    let reminder = reminders[0]
                    self.reminderManager.deleteReminder(reminder) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                self.updateFeedback = "✅ Deleted: \(reminder.title ?? "Unknown")"
                                self.removeCommand = ""
                                self.currentView = .entry
                                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                            } else {
                                self.updateFeedback = "❌ Failed to delete reminder"
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                self.updateFeedback = ""
                            }
                        }
                    }
                } else if reminders.count > 1 {
                    // Multiple reminders found - show selection list
                    self.duplicateReminders = Array(reminders.prefix(15)) // Show up to 15 matches
                } else {
                    // No reminders found
                    self.duplicateReminders = []
                    self.updateFeedback = "❌ No reminders found matching '\(searchTerm)'"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.updateFeedback = ""
                    }
                }
                self.isSearchingDuplicates = false
            }
        }
    }
    
    func searchForMove() {
        isSearchingDuplicates = true
        duplicateReminders = []
        
        if moveCommand.isEmpty {
            isSearchingDuplicates = false
            return
        }
        
        // Parse the move command to extract reminder name and target date
        let (searchTerm, targetDate) = parseMoveCommand(moveCommand)
        moveTargetDate = targetDate
        
        if searchTerm.isEmpty {
            isSearchingDuplicates = false
            return
        }
        
        
        reminderManager.findReminder(withTitle: searchTerm) { reminders in
            DispatchQueue.main.async {
                self.duplicateReminders = Array(reminders.prefix(15)) // Show up to 15 matches
                self.isSearchingDuplicates = false
                
            }
        }
    }
    
    func deleteReminder(_ reminder: EKReminder) {
        reminderManager.deleteReminder(reminder) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Remove from local arrays after successful deletion
                    self.foundReminders.removeAll { $0.calendarItemIdentifier == reminder.calendarItemIdentifier }
                    self.duplicateReminders.removeAll { $0.calendarItemIdentifier == reminder.calendarItemIdentifier }
                } else {
                }
            }
        }
    }
    
    func completeReminder(_ reminder: EKReminder) {
        reminderManager.completeReminder(reminder) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Remove from local arrays after successful completion (completed reminders typically don't show in active lists)
                    self.foundReminders.removeAll { $0.calendarItemIdentifier == reminder.calendarItemIdentifier }
                    self.duplicateReminders.removeAll { $0.calendarItemIdentifier == reminder.calendarItemIdentifier }
                } else {
                }
            }
        }
    }
    
    func moveReminder(_ reminder: EKReminder) {
        guard let targetReminder = moveTargetReminder else {
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
            }
        } else {
            // Remove any existing recurrence if not recurring
            reminder.recurrenceRules = nil
        }
        
        // Save the updated reminder
        do {
            try reminderManager.eventStore.save(reminder, commit: true)
        } catch {
        }
    }
    
    func keepReminder(_ keeper: EKReminder) {
        // Remove all other duplicates except the one we want to keep
        let toRemove = duplicateReminders.filter { $0.calendarItemIdentifier != keeper.calendarItemIdentifier }
        
        for reminder in toRemove {
            deleteReminder(reminder)
        }
        
        // Clear input and go back to typing
        inputText = ""
        currentView = .keyboard
    }
    
    func parseMoveCommand(_ command: String) -> (searchTerm: String, targetDate: Date?) {
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
            let parsedTarget = reminderManager.nlParser.parseReminderText("reminder \(targetString)")
            
            // Store the full parsed reminder for later use
            moveTargetReminder = parsedTarget
            
            return (searchTerm, parsedTarget.dueDate)
        }
        
        // Fallback: just extract the reminder name without "to" part
        let searchTerm = lowercaseCommand
            .replacingOccurrences(of: "^(mv|move)\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (searchTerm, nil)
    }
    
    func parseDateFromTarget(_ target: String) -> Date? {
        let today = Date()
        let calendar = Calendar.current
        
        if target.contains("today") {
            return today
        } else if target.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: today)
        } else if target.contains("monday") {
            return getNextWeekday(2, from: today)
        } else if target.contains("tuesday") {
            return getNextWeekday(3, from: today)
        } else if target.contains("wednesday") {
            return getNextWeekday(4, from: today)
        } else if target.contains("thursday") {
            return getNextWeekday(5, from: today)
        } else if target.contains("friday") {
            return getNextWeekday(6, from: today)
        } else if target.contains("saturday") {
            return getNextWeekday(7, from: today)
        } else if target.contains("sunday") {
            return getNextWeekday(1, from: today)
        }
        
        return nil
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func keyboardControllerRecurrenceText(from rule: EKRecurrenceRule) -> String {
        let interval = rule.interval
        
        switch rule.frequency {
        case .daily:
            return interval == 1 ? "Daily" : "\(interval)d"
        case .weekly:
            return interval == 1 ? "Weekly" : "\(interval)w"
        case .monthly:
            return interval == 1 ? "Monthly" : "\(interval)m"
        case .yearly:
            return interval == 1 ? "Yearly" : "\(interval)y"
        @unknown default:
            return "Repeats"
        }
    }
    
    func getRecurrenceDescription(_ reminder: SharedParsedReminder) -> String {
        guard reminder.isRecurring,
              let frequency = reminder.recurrenceFrequency,
              let interval = reminder.recurrenceInterval else {
            return ""
        }
        
        let intervalText = interval == 1 ? "" : "\(interval) "
        
        switch frequency {
        case .daily:
            return interval == 1 ? "Daily" : "Every \(intervalText)days"
        case .weekly:
            return interval == 1 ? "Weekly" : "Every \(intervalText)weeks"
        case .monthly:
            return interval == 1 ? "Monthly" : "Every \(intervalText)months"
        case .yearly:
            return interval == 1 ? "Yearly" : "Every \(intervalText)years"
        @unknown default:
            return "Recurring"
        }
    }
    
    func parseDateFromCommand(_ command: String) -> Date? {
        let lowercaseCommand = command.lowercased()
        let today = Date()
        let calendar = Calendar.current
        
        // Remove "ls" or "list" from the beginning
        var cleanCommand = lowercaseCommand
            .replacingOccurrences(of: "^(ls|list)\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle shortcuts if enabled
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
        
        // Handle specific date keywords
        if cleanCommand.isEmpty {
            return nil // Show all reminders if no filter specified
        } else if cleanCommand.contains("today") {
            return today
        } else if cleanCommand.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: today)
        } else if cleanCommand.contains("yesterday") {
            return calendar.date(byAdding: .day, value: -1, to: today)
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
    
    func parseListNameFromCommand(_ command: String) -> String? {
        let cleanCommand = command.lowercased()
            .replacingOccurrences(of: "^(ls|list)\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it's a date/time keyword that we should ignore
        let dateKeywords = ["today", "tomorrow", "yesterday", "this week", "this month", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        
        for keyword in dateKeywords {
            if cleanCommand.contains(keyword) {
                return nil // It's a date filter, not a list name
            }
        }
        
        // If it's not empty and not a date keyword, treat it as a list name
        return cleanCommand.isEmpty ? nil : cleanCommand
    }
    
    func filterRemindersForPeriod(_ reminders: [EKReminder], command: String) -> [EKReminder] {
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
        } else if lowercaseCommand.contains("next week") {
            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: today),
                  let weekInterval = calendar.dateInterval(of: .weekOfYear, for: nextWeek) else { return [] }
            
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return weekInterval.contains(dueDate)
            }
        } else if lowercaseCommand.contains("this month") {
            let startOfMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
            let endOfMonth = calendar.dateInterval(of: .month, for: today)?.end ?? today
            
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return dueDate >= startOfMonth && dueDate <= endOfMonth
            }
        } else if lowercaseCommand.contains("next month") {
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: today),
                  let monthInterval = calendar.dateInterval(of: .month, for: nextMonth) else { return [] }
            
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return monthInterval.contains(dueDate)
            }
        }
        
        return reminders
    }
    
    func getNextWeekday(_ targetWeekday: Int, from date: Date) -> Date? {
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: date)
        
        var daysToAdd = targetWeekday - today
        if daysToAdd <= 0 {
            daysToAdd += 7 // Next week if it's already passed this week
        }
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: date)
    }
    
    func getListSectionTitle() -> String {
        if listCommand.isEmpty {
            return "📋 All Reminders"
        }
        
        let cleanCommand = listCommand.lowercased()
            .replacingOccurrences(of: "^(ls|list)\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanCommand.isEmpty {
            return "📋 All Reminders"
        } else if cleanCommand.contains("today") {
            return "📋 Today's Reminders"
        } else if cleanCommand.contains("tomorrow") {
            return "📋 Tomorrow's Reminders"
        } else if cleanCommand.contains("this week") {
            return "📋 This Week's Reminders"
        } else if cleanCommand.contains("this month") {
            return "📋 This Month's Reminders"
        } else if cleanCommand.contains("monday") {
            return "📋 Monday's Reminders"
        } else if cleanCommand.contains("tuesday") {
            return "📋 Tuesday's Reminders"
        } else if cleanCommand.contains("wednesday") {
            return "📋 Wednesday's Reminders"
        } else if cleanCommand.contains("thursday") {
            return "📋 Thursday's Reminders"
        } else if cleanCommand.contains("friday") {
            return "📋 Friday's Reminders"
        } else if cleanCommand.contains("saturday") {
            return "📋 Saturday's Reminders"
        } else if cleanCommand.contains("sunday") {
            return "📋 Sunday's Reminders"
        } else {
            return "📋 Filtered Reminders"
        }
    }
}

class KeyboardViewController: UIInputViewController {
    
    // MARK: - Properties
    private var hostingController: UIHostingController<WorkingKeyboardView>?
    private var reminderManager: SharedReminderManager?
    private var colorTheme: SharedColorThemeManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboard()
        
        // CRITICAL: Add the system next keyboard button
        setupNextKeyboardButton()
    }
    
    // MARK: - Input Mode Switch Support
    override var needsInputModeSwitchKey: Bool {
        return true // This ensures the globe button appears for switching keyboards
    }
    
    private func setupNextKeyboardButton() {
        // Only show the globe button on iPad - iPhone handles this automatically
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        
        // Create the system next keyboard button
        let nextKeyboardButton = UIButton(type: .system)
        nextKeyboardButton.setTitle("🌐", for: .normal)
        nextKeyboardButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeChange), for: .touchUpInside)
        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Add it to the view
        view.addSubview(nextKeyboardButton)
        
        // Position it in bottom left corner
        NSLayoutConstraint.activate([
            nextKeyboardButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            nextKeyboardButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            nextKeyboardButton.widthAnchor.constraint(equalToConstant: 40),
            nextKeyboardButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        nextKeyboardButton.backgroundColor = UIColor.systemGray5
        nextKeyboardButton.layer.cornerRadius = 8
    }
    
    @objc private func handleInputModeChange() {
        advanceToNextInputMode()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    private func setupKeyboard() {
        // Initialize managers
        let theme = SharedColorThemeManager()
        colorTheme = theme
        reminderManager = SharedReminderManager(colorTheme: theme)
        
        // Create a working keyboard with entry field - pass shared managers
        let keyboardView = WorkingKeyboardView(
            onTextInput: { text in
                // Don't insert into textDocumentProxy - only use internal field
            },
            onProcess: { [weak self] text in
                self?.processReminder(text)
            },
            onNextKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            },
            colorTheme: theme,
            reminderManager: reminderManager
        )
        
        // Create hosting controller
        hostingController = UIHostingController(rootView: keyboardView)
        
        guard let hostingController = hostingController else { 
            return 
        }
        
        // Add as child view controller
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        // Setup constraints for full keyboard extension
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.heightAnchor.constraint(equalToConstant: 330) // Fixed height with more room
        ])
        
        hostingController.view.backgroundColor = UIColor.clear
        view.backgroundColor = UIColor.clear
    }
    
    private func processReminder(_ text: String) {
        guard let reminderManager = reminderManager else { 
            return 
        }
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        Task {
            do {
                try await reminderManager.createReminder(from: text)
                
                await MainActor.run {
                    // Success haptic feedback
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)
                    
                    // Success feedback - DON'T auto-dismiss, stay in our keyboard
                }
            } catch {
                await MainActor.run {
                    // Error haptic feedback
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                }
            }
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        // Update hosting controller frame
        hostingController?.view.frame = view.bounds
    }
    
    override func textWillChange(_ textInput: UITextInput?) {
        // Called when the text will change
        super.textWillChange(textInput)
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
        // Called when the text has changed
        super.textDidChange(textInput)
    }
    
    private func dismissKeyboardExtension() {
        advanceToNextInputMode()
    }
}

// MARK: - Keyboard List Picker View

struct KeyboardListPickerView: View {
    @ObservedObject var reminderManager: SharedReminderManager
    @ObservedObject var colorTheme: SharedColorThemeManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                ForEach(reminderManager.availableLists, id: \.calendarIdentifier) { list in
                    Button(action: {
                        reminderManager.setSelectedList(list)
                        colorTheme.updateColorsForRemindersList(list)
                        isPresented = false
                    }) {
                        HStack {
                            Circle()
                                .fill(Color(cgColor: list.cgColor))
                                .frame(width: 20, height: 20)
                            
                            Text(list.title)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if list.calendarIdentifier == reminderManager.selectedList?.calendarIdentifier {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Choose List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#endif
