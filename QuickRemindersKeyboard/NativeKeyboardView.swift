//
//  NativeKeyboardView.swift
//  QuickReminders Keyboard
//
//  Clean, native Apple keyboard design for QuickReminders
//

#if os(iOS)
import UIKit
import SwiftUI
import EventKit
import Combine
import AVFoundation
import Speech

// MARK: - Animation Support

enum AnimationStatus: Equatable {
    case hidden
    case processing(String)
    case success(String)
    case error(String)
}

class AnimationManager: ObservableObject {
    @Published var currentStatus: AnimationStatus = .hidden
    
    func showProcessing(_ message: String) {
        currentStatus = .processing(message)
    }
    
    func showSuccess(_ message: String) {
        currentStatus = .success(message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.hideAnimation()
        }
    }
    
    func showError(_ message: String) {
        currentStatus = .error(message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.hideAnimation()
        }
    }
    
    func hideAnimation() {
        currentStatus = .hidden
    }
}

// MARK: - Keyboard Page Types

enum KeyboardPage: CaseIterable {
    case typing
    case duplicates
    case list
    
    var title: String {
        switch self {
        case .typing: return "Type"
        case .duplicates: return "Duplicates"
        case .list: return "Reminders"
        }
    }
}

// MARK: - Enhanced SwiftUI Keyboard View with Command Detection

struct NativeKeyboardView: View {
    @ObservedObject var colorTheme: SharedColorThemeManager
    @StateObject private var speechManager = SharedSpeechManager()
    @StateObject private var animationManager = AnimationManager()
    @StateObject private var reminderManager: SharedReminderManager
    
    let onTextChange: (String) -> Void
    let onDismiss: () -> Void
    let onProcessReminder: (String) -> Void
    
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var isListening = false
    @State private var currentPage: KeyboardPage = .typing
    @State private var isUppercase = false
    @State private var keyboardMode: KeyboardMode = .letters
    
    enum KeyboardMode {
        case letters
        case numbers
        case symbols
    }
    @State private var foundReminders: [EKReminder] = []
    @State private var duplicateReminders: [EKReminder] = []
    @FocusState private var isTextFieldFocused: Bool
    
    // Keyboard layouts
    private let numbersRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private let topRow = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
    private let middleRow = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
    private let bottomRow = ["z", "x", "c", "v", "b", "n", "m"]
    
    // Numbers keyboard layout
    private let numbersTopRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private let numbersMiddleRow = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
    private let numbersBottomRow = [".", ",", "?", "!", "'", "\"", "-", "_", "(", ")"]
    
    // Symbols keyboard layout
    private let symbolsTopRow = ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]
    private let symbolsMiddleRow = ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"]
    private let symbolsBottomRow = [".", ",", "?", "!", "'", "\"", "-", "_", "(", ")"]
    
    init(colorTheme: SharedColorThemeManager, onTextChange: @escaping (String) -> Void, onDismiss: @escaping () -> Void, onProcessReminder: @escaping (String) -> Void) {
        self.colorTheme = colorTheme
        self.onTextChange = onTextChange
        self.onDismiss = onDismiss
        self.onProcessReminder = onProcessReminder
        self._reminderManager = StateObject(wrappedValue: SharedReminderManager(colorTheme: colorTheme))
    }
    
    private var quickSuggestions: [String] {
        let defaultSuggestions = [
            "Call mom tomorrow",
            "Meeting Monday 10am",
            "Gym session 6pm",
            "Pay bills Friday"
        ]
        return colorTheme.customQuickIdeas.isEmpty ? defaultSuggestions : colorTheme.customQuickIdeas
    }
    
    var body: some View {
        ZStack {
            // Beautiful gradient background matching app
            LinearGradient(
                colors: [
                    colorTheme.primaryColor.opacity(0.1),
                    colorTheme.successColor.opacity(0.05),
                    Color(UIColor.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if animationManager.currentStatus == .hidden {
                VStack(spacing: 0) {
                    // Header with app branding - Fixed height with safe area
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(colorTheme.primaryColor)
                            
                            Text("QuickReminders")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Button("Done") {
                            onDismiss()
                        }
                        .font(.body.weight(.medium))
                        .foregroundColor(colorTheme.primaryColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 25)
                    .padding(.bottom, 15)
                    .frame(height: 70)
                    .background(Color(UIColor.systemBackground))
                    
                    // Text input display and controls - Fixed height
                    VStack(spacing: 12) {
                        // Text display area - tappable to show keyboard
                        HStack {
                            HStack {
                                Text(inputText.isEmpty ? "What would you like to remember?" : inputText)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(inputText.isEmpty ? .secondary : .primary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                if !inputText.isEmpty {
                                    Button(action: {
                                        inputText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isTextFieldFocused ? colorTheme.primaryColor : Color(UIColor.separator), lineWidth: isTextFieldFocused ? 2 : 1)
                                    )
                            )
                            .onTapGesture {
                                isTextFieldFocused = true
                                currentPage = .typing
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Control buttons
                        HStack(spacing: 12) {
                            // Voice button
                            Button(action: toggleVoiceRecognition) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: isListening ? [.red, .orange] : [colorTheme.primaryColor, colorTheme.primaryColor.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 44, height: 44)
                                        .shadow(color: (isListening ? Color.red : colorTheme.primaryColor).opacity(0.4), radius: 6, x: 0, y: 3)
                                    
                                    if isListening {
                                        Circle()
                                            .fill(RadialGradient(
                                                colors: [.red.opacity(0.3), .orange.opacity(0.1), .clear],
                                                center: .center,
                                                startRadius: 20,
                                                endRadius: 30
                                            ))
                                            .frame(width: 50, height: 50)
                                            .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 3) * 0.1)
                                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isListening)
                                    }
                                    
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .scaleEffect(isListening ? 1.05 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isListening)
                            
                            Spacer()
                            
                            // Send button
                            Button(action: processReminder) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: inputText.isEmpty ? [.gray] : [colorTheme.successColor, colorTheme.successColor.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 44, height: 44)
                                        .shadow(color: inputText.isEmpty ? .clear : colorTheme.successColor.opacity(0.4), radius: 6, x: 0, y: 3)
                                    
                                    if isProcessing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "plus")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .disabled(inputText.isEmpty || isProcessing)
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(height: 120)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    
                    // Page tabs - Fixed height
                    if isTextFieldFocused && currentPage != .typing {
                        HStack {
                            ForEach(KeyboardPage.allCases, id: \.self) { page in
                                Button(action: {
                                    currentPage = page
                                    if page == .duplicates {
                                        searchForDuplicates()
                                    } else if page == .list {
                                        loadReminders()
                                    }
                                }) {
                                    Text(page.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(currentPage == page ? .white : colorTheme.primaryColor)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(currentPage == page ? colorTheme.primaryColor : colorTheme.primaryColor.opacity(0.1))
                                        )
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(height: 50)
                        .background(Color(UIColor.tertiarySystemGroupedBackground))
                    }
                    
                    // Current page content
                    if isTextFieldFocused {
                        Group {
                            switch currentPage {
                            case .typing:
                                typingPageView
                            case .duplicates:
                                duplicatesPageView
                            case .list:
                                listPageView
                            }
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                    } else {
                        // Quick Ideas when not focused - EXACT styling as Reminders/Today tabs
                        if inputText.isEmpty && !isListening {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Quick Ideas")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(quickSuggestions.prefix(5), id: \.self) { suggestion in
                                            Button(action: {
                                                inputText = suggestion
                                                isTextFieldFocused = true
                                            }) {
                                                Text(suggestion)
                                                    .font(.caption.weight(.medium))
                                                    .foregroundColor(.primary)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(Color(UIColor.systemBackground))
                                                    .cornerRadius(8)
                                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .frame(maxHeight: 140)
                                
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .frame(height: 240)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .animation(.easeInOut(duration: 0.3), value: inputText.isEmpty)
                        }
                    }
                    
                    Spacer()
                }
            } else {
                // Animation overlay
                KeyboardAnimationOverlay(
                    status: animationManager.currentStatus,
                    colorTheme: colorTheme
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animationManager.currentStatus)
            }
        }
        .onReceive(speechManager.$transcription) { transcription in
            inputText = transcription
        }
        .onReceive(speechManager.$isListening) { listening in
            isListening = listening
        }
        .onAppear {
            // Temporarily disable microphone permission request to see if it's causing issues
            // requestMicrophonePermission()
        }
        .onChange(of: inputText) { _, newValue in
            detectCommands(in: newValue)
        }
    }
    
    // MARK: - Page Views
    
    var typingPageView: some View {
        VStack(spacing: 8) {
            if keyboardMode == .letters {
                // Numbers row (always show for letters mode)
                HStack(spacing: 6) {
                    ForEach(numbersRow, id: \.self) { number in
                        KeyButton(letter: number, isUppercase: false) { key in
                            inputText += key
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                // Letter rows
                letterKeyboardView
            } else if keyboardMode == .numbers {
                numberKeyboardView
            } else {
                symbolKeyboardView
            }
            
            // Bottom control row
            HStack(spacing: 6) {
                // Mode switch key (numbers/letters/symbols)
                Button(action: {
                    switch keyboardMode {
                    case .letters:
                        keyboardMode = .numbers
                    case .numbers:
                        keyboardMode = .symbols
                    case .symbols:
                        keyboardMode = .letters
                    }
                }) {
                    Text(keyboardMode == .letters ? "123" : keyboardMode == .numbers ? "#+=": "ABC")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 50, height: 36)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(6)
                }
                
                // Space bar
                Button(action: {
                    inputText += " "
                }) {
                    Text("space")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(6)
                }
                
                // Return key
                Button(action: processReminder) {
                    Text("return")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 36)
                        .background(colorTheme.primaryColor)
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .frame(height: 290) // Larger size = standard section height + bottom navigation height
        .background(Color(UIColor.tertiarySystemGroupedBackground))
    }
    
    var letterKeyboardView: some View {
        VStack(spacing: 8) {
            // Top row
            HStack(spacing: 6) {
                ForEach(topRow, id: \.self) { letter in
                    KeyButton(letter: letter, isUppercase: isUppercase) { key in
                        inputText += key
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Middle row
            HStack(spacing: 6) {
                ForEach(middleRow, id: \.self) { letter in
                    KeyButton(letter: letter, isUppercase: isUppercase) { key in
                        inputText += key
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Bottom row with special keys
            HStack(spacing: 6) {
                // Shift key
                Button(action: {
                    isUppercase.toggle()
                }) {
                    Image(systemName: isUppercase ? "shift.fill" : "shift")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isUppercase ? colorTheme.primaryColor : .primary)
                        .frame(width: 40, height: 36)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(6)
                }
                
                ForEach(bottomRow, id: \.self) { letter in
                    KeyButton(letter: letter, isUppercase: isUppercase) { key in
                        inputText += key
                    }
                }
                
                // Backspace key
                Button(action: {
                    if !inputText.isEmpty {
                        inputText.removeLast()
                    }
                }) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 36)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    var numberKeyboardView: some View {
        VStack(spacing: 8) {
            // Numbers top row
            HStack(spacing: 6) {
                ForEach(numbersTopRow, id: \.self) { number in
                    KeyButton(letter: number, isUppercase: false) { key in
                        inputText += key
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Numbers middle row
            HStack(spacing: 6) {
                ForEach(numbersMiddleRow, id: \.self) { symbol in
                    KeyButton(letter: symbol, isUppercase: false) { key in
                        inputText += key
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Numbers bottom row
            HStack(spacing: 6) {
                // Shift key (for symbols)
                Button(action: {
                    keyboardMode = .symbols
                }) {
                    Text("#+=")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 36)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(6)
                }
                
                ForEach(numbersBottomRow, id: \.self) { symbol in
                    KeyButton(letter: symbol, isUppercase: false) { key in
                        inputText += key
                    }
                }
                
                // Backspace key
                Button(action: {
                    if !inputText.isEmpty {
                        inputText.removeLast()
                    }
                }) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 36)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    var symbolKeyboardView: some View {
        VStack(spacing: 8) {
            // Symbols top row
            HStack(spacing: 6) {
                ForEach(symbolsTopRow, id: \.self) { symbol in
                    KeyButton(letter: symbol, isUppercase: false) { key in
                        inputText += key
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Symbols middle row
            HStack(spacing: 6) {
                ForEach(symbolsMiddleRow, id: \.self) { symbol in
                    KeyButton(letter: symbol, isUppercase: false) { key in
                        inputText += key
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Symbols bottom row
            HStack(spacing: 6) {
                // Numbers key
                Button(action: {
                    keyboardMode = .numbers
                }) {
                    Text("123")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 36)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(6)
                }
                
                ForEach(symbolsBottomRow, id: \.self) { symbol in
                    KeyButton(letter: symbol, isUppercase: false) { key in
                        inputText += key
                    }
                }
                
                // Backspace key
                Button(action: {
                    if !inputText.isEmpty {
                        inputText.removeLast()
                    }
                }) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 36)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    var duplicatesPageView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose which reminder to keep:")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            if duplicateReminders.isEmpty {
                VStack {
                    Text("No duplicates found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(duplicateReminders, id: \.calendarItemIdentifier) { reminder in
                            HStack {
                                Circle()
                                    .fill(Color(cgColor: reminder.calendar?.cgColor ?? CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)))
                                    .frame(width: 12, height: 12)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reminder.title ?? "Untitled")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.primary)
                                    
                                    if let dueDate = reminder.dueDateComponents?.date {
                                        Text(dueDate, style: .relative)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Show recurring indicator under the time (like native Reminders)
                                    if let recurrenceRules = reminder.recurrenceRules, !recurrenceRules.isEmpty,
                                       let rule = recurrenceRules.first {
                                        HStack(spacing: 2) {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 8))
                                                .foregroundColor(.secondary)
                                            
                                            Text(keyboardRecurrenceText(from: rule))
                                                .font(.system(size: 8))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Button("Keep") {
                                        // Keep this one, remove others
                                        keepReminder(reminder)
                                    }
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(colorTheme.successColor)
                                    .cornerRadius(4)
                                    
                                    Button("Remove") {
                                        deleteReminder(reminder)
                                    }
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(colorTheme.errorColor)
                                    .cornerRadius(4)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(maxHeight: 140)
            }
            
            if duplicateReminders.isEmpty {
                Spacer()
            }
        }
        .padding(.vertical, 12)
        .frame(height: 240)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
    }
    
    var listPageView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Reminders:")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            if foundReminders.isEmpty {
                VStack {
                    Text("No reminders found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(foundReminders.prefix(20), id: \.calendarItemIdentifier) { reminder in
                            HStack {
                                Circle()
                                    .fill(Color(cgColor: reminder.calendar?.cgColor ?? CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)))
                                    .frame(width: 12, height: 12)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reminder.title ?? "Untitled")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.primary)
                                    
                                    if let dueDate = reminder.dueDateComponents?.date {
                                        Text(dueDate, style: .relative)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Show recurring indicator under the time (like native Reminders)
                                    if let recurrenceRules = reminder.recurrenceRules, !recurrenceRules.isEmpty,
                                       let rule = recurrenceRules.first {
                                        HStack(spacing: 2) {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 8))
                                                .foregroundColor(.secondary)
                                            
                                            Text(keyboardRecurrenceText(from: rule))
                                                .font(.system(size: 8))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    deleteReminder(reminder)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(maxHeight: 140)
            }
            
            if foundReminders.isEmpty {
                Spacer()
            }
        }
        .padding(.vertical, 12)
        .frame(height: 240)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
    }
    
    // MARK: - Functions
    
    private func detectCommands(in text: String) {
        let lowercaseText = text.lowercased()
        
        // Detect MV/RM/LS commands
        if lowercaseText.hasPrefix("mv ") || lowercaseText.hasPrefix("rm ") {
            self.currentPage = .duplicates
            self.searchForDuplicates()
        } else if lowercaseText.hasPrefix("ls") {
            self.currentPage = .list
            self.loadReminders()
        }
    }
    
    private func processReminder() {
        guard !self.inputText.isEmpty, !self.isProcessing else { return }
        
        let textToProcess = self.inputText
        self.inputText = ""
        self.isProcessing = true
        self.isTextFieldFocused = false
        
        // Trigger animation
        self.animationManager.showProcessing("Creating reminder...")
        
        // Call the actual processing function
        self.onProcessReminder(textToProcess)
        
        // Set up success animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isProcessing = false
            self.animationManager.showSuccess("✅ Reminder created!")
        }
    }
    
    private func toggleVoiceRecognition() {
        if !self.speechManager.isAvailable {
            self.speechManager.requestPermissions()
            return
        }
        
        if self.isListening {
            self.speechManager.stopListening()
        } else {
            self.speechManager.startListening(
                onUpdate: { transcript in
                    DispatchQueue.main.async {
                        self.inputText = transcript
                    }
                },
                completion: { finalTranscript in
                    DispatchQueue.main.async {
                        self.inputText = finalTranscript
                        
                        // Auto-send if voice activation is enabled and contains trigger word
                        if self.colorTheme.voiceActivationEnabled && self.colorTheme.containsTriggerWord(finalTranscript) {
                            let cleanText = self.colorTheme.removeTriggerWordFromText(finalTranscript)
                            if !cleanText.isEmpty {
                                self.inputText = cleanText
                                self.processReminder()
                            }
                        }
                    }
                }
            )
        }
    }
    
    private func requestMicrophonePermission() {
        // For keyboard extensions, we can't request microphone permissions directly
        // The parent app needs to have the permissions
        self.speechManager.requestPermissions()
    }
    
    private func loadReminders() {
        
        self.reminderManager.getAllReminders { reminders in
            DispatchQueue.main.async {
                self.foundReminders = Array(reminders.prefix(20))
            }
        }
    }
    
    private func searchForDuplicates() {
        
        if self.inputText.isEmpty {
            self.duplicateReminders = []
            return
        }
        
        // Extract search term from command
        let searchTerm = self.inputText.lowercased()
            .replacingOccurrences(of: "mv ", with: "")
            .replacingOccurrences(of: "rm ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if searchTerm.isEmpty {
            self.duplicateReminders = []
            return
        }
        
        self.reminderManager.findReminder(withTitle: searchTerm) { reminders in
            DispatchQueue.main.async {
                if reminders.count == 1 && self.inputText.lowercased().hasPrefix("rm ") {
                    // Only one reminder found and it's an rm command - delete it automatically
                    let reminder = reminders[0]
                    self.deleteReminder(reminder)
                } else {
                    // Multiple reminders or mv command - show selection list
                    self.duplicateReminders = Array(reminders.prefix(10))
                }
            }
        }
    }
    
    private func deleteReminder(_ reminder: EKReminder) {
        self.reminderManager.deleteReminder(reminder) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Remove from local arrays
                    self.foundReminders.removeAll { $0.calendarItemIdentifier == reminder.calendarItemIdentifier }
                    self.duplicateReminders.removeAll { $0.calendarItemIdentifier == reminder.calendarItemIdentifier }
                } else {
                }
            }
        }
    }
    
    private func keepReminder(_ keeper: EKReminder) {
        // Remove all other duplicates except the one we want to keep
        let toRemove = self.duplicateReminders.filter { $0.calendarItemIdentifier != keeper.calendarItemIdentifier }
        
        for reminder in toRemove {
            deleteReminder(reminder)
        }
        
        // Clear input and go back to typing
        self.inputText = ""
        self.currentPage = .typing
    }
}

// MARK: - Supporting Components

struct KeyButton: View {
    let letter: String
    let isUppercase: Bool
    let onTap: (String) -> Void
    
    var body: some View {
        Button(action: {
            let key = isUppercase ? letter.uppercased() : letter
            onTap(key)
        }) {
            Text(isUppercase ? letter.uppercased() : letter)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 30, height: 36)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(6)
        }
    }
}

struct KeyboardAnimationOverlay: View {
    let status: AnimationStatus
    @ObservedObject var colorTheme: SharedColorThemeManager
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    animationColor.opacity(0.3),
                                    animationColor.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 3) * 0.1)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: UUID())
                    
                    Group {
                        switch status {
                        case .processing:
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        case .error:
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        case .hidden:
                            EmptyView()
                        }
                    }
                }
                
                VStack(spacing: 8) {
                    if case .processing(let message) = status {
                        Text(message)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    } else if case .success(let message) = status {
                        Text(message)
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    } else if case .error(let message) = status {
                        Text(message)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }
    
    private var animationColor: Color {
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

// MARK: - Helper Functions

private func keyboardRecurrenceText(from rule: EKRecurrenceRule) -> String {
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

#endif
