//
//  PerfectIOSAppView.swift
//  QuickReminders - iOS
//
//  FULL SCREEN app with EXACT same animation as floating window
//
#if os(iOS)
import SwiftUI
import EventKit
import Speech
import AVFoundation

// MARK: - Inside Window State (same as macOS)
enum InsideWindowState: Equatable {
    case hidden
    case showingList([EKReminder])
    case showingDuplicates([EKReminder], (EKReminder) -> Void)
    
    static func == (lhs: InsideWindowState, rhs: InsideWindowState) -> Bool {
        switch (lhs, rhs) {
        case (.hidden, .hidden):
            return true
        case (.showingList(let lhsReminders), .showingList(let rhsReminders)):
            return lhsReminders.count == rhsReminders.count && 
                   lhsReminders.map(\.calendarItemIdentifier) == rhsReminders.map(\.calendarItemIdentifier)
        case (.showingDuplicates(let lhsReminders, _), .showingDuplicates(let rhsReminders, _)):
            return lhsReminders.count == rhsReminders.count && 
                   lhsReminders.map(\.calendarItemIdentifier) == rhsReminders.map(\.calendarItemIdentifier)
        default:
            return false
        }
    }
}

struct PerfectIOSAppView: View {
    @EnvironmentObject var colorTheme: SharedColorThemeManager
    @EnvironmentObject var reminderManager: SharedReminderManager
    @EnvironmentObject var animationManager: AnimationManager
    @StateObject private var speechManager = SharedSpeechManager()
    
    // EXACT ANIMATION STATES from macOS floating window
    @State private var glowAnimation = false
    @State private var flashAnimation = false  // SUCCESS/ERROR flash animation
    @State private var glowStops: [Gradient.Stop] = []
    @State private var backgroundFlashColor: Color = .clear
    @State private var showFlash = false
    @State private var colorShift: Double = 0.0  // For color animation
    @State private var showingAnimation = false
    @State private var showingListPicker = false
    
    // STATE MANAGEMENT - same as macOS floating window
    @State private var insideWindowState: InsideWindowState = .hidden
    
    var body: some View {
        ZStack {
            TabView {
                // Create Tab
                NavigationView {
                    ZStack {
                        PerfectCreateReminderView(
                            reminderManager: reminderManager,
                            colorTheme: colorTheme,
                            speechManager: speechManager,
                            animationManager: animationManager,
                            insideWindowState: $insideWindowState,
                            onTriggerAnimation: { success in
                                triggerExactFloatingWindowAnimation(success: success)
                            }
                        )
                        
                        // Status overlay for command feedback
                        VStack {
                            Spacer()
                            StatusOverlayView(animationManager: animationManager)
                                .padding(.bottom, 100)
                        }
                    }
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .tabItem {
                    Image(systemName: "plus.circle")
                    Text("Create")
                }
                
                // Reminders Tab
                NavigationView {
                    RemindersListView(
                        reminderManager: reminderManager,
                        colorTheme: colorTheme,
                        animationManager: animationManager
                    )
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .tabItem {
                    Image(systemName: "checklist")
                    Text("Reminders")
                }
                
                // Settings Tab
                NavigationView {
                    CompleteSettingsView(
                        colorTheme: colorTheme,
                        reminderManager: reminderManager,
                        speechManager: speechManager
                    )
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
            }
            .accentColor(colorTheme.dynamicAccentColor)
            
            // PROPER APPLE INTELLIGENCE EDGE GLOW - ON THE ACTUAL EDGES!
            GeometryReader { geometry in
                ZStack {
                    // LEFT EDGE - SMOOTHLY APPEARS AND GROWS
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [
                                getCurrentGlowColor().opacity(showFlash ? 1.0 : 0),
                                getCurrentGlowColor().opacity(showFlash ? 0.6 : 0),
                                getCurrentGlowColor().opacity(showFlash ? 0.2 : 0),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: showFlash ? 220 : 0, height: geometry.size.height) // Start from 0 width
                        .blur(radius: showFlash ? 45 : 0) // Start from 0 blur
                        .position(x: 0, y: geometry.size.height / 2)
                        .animation(.easeInOut(duration: 0.6), value: showFlash)
                    
                    // RIGHT EDGE - SMOOTHLY APPEARS AND GROWS
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [
                                .clear,
                                getCurrentGlowColor().opacity(showFlash ? 0.2 : 0),
                                getCurrentGlowColor().opacity(showFlash ? 0.6 : 0),
                                getCurrentGlowColor().opacity(showFlash ? 1.0 : 0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: showFlash ? 220 : 0, height: geometry.size.height) // Start from 0 width
                        .blur(radius: showFlash ? 45 : 0) // Start from 0 blur
                        .position(x: geometry.size.width, y: geometry.size.height / 2)
                        .animation(.easeInOut(duration: 0.6), value: showFlash)
                    
                    // TOP EDGE - SMOOTHLY APPEARS AND GROWS
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [
                                getCurrentGlowColor().opacity(showFlash ? 0.8 : 0),
                                getCurrentGlowColor().opacity(showFlash ? 0.5 : 0),
                                getCurrentGlowColor().opacity(showFlash ? 0.15 : 0),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: geometry.size.width, height: showFlash ? 180 : 0) // Start from 0 height
                        .blur(radius: showFlash ? 40 : 0) // Start from 0 blur
                        .position(x: geometry.size.width / 2, y: 0)
                        .animation(.easeInOut(duration: 0.6), value: showFlash)
                    
                    // BOTTOM EDGE - SMOOTHLY APPEARS AND GROWS
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [
                                .clear,
                                getCurrentGlowColor().opacity(showFlash ? 0.15 : 0),
                                getCurrentGlowColor().opacity(showFlash ? 0.5 : 0),
                                getCurrentGlowColor().opacity(showFlash ? 0.8 : 0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: geometry.size.width, height: showFlash ? 180 : 0) // Start from 0 height
                        .blur(radius: showFlash ? 40 : 0) // Start from 0 blur
                        .position(x: geometry.size.width / 2, y: geometry.size.height)
                        .animation(.easeInOut(duration: 0.6), value: showFlash)
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea(.all)
            .zIndex(999)
            
        }
        .preferredColorScheme(colorScheme)
        .onAppear {
            // Update colors based on selected list when app appears
            colorTheme.updateColorsForRemindersList(reminderManager.selectedList)
            
            // Load reminders immediately on app start
            Task {
                await reminderManager.reloadReminderLists()
            }
            
            // Start continuous background animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
        }
        .onChange(of: reminderManager.selectedList) { _, newList in
            // Update colors when list selection changes
            colorTheme.updateColorsForRemindersList(newList)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Refresh reminder lists when app becomes active (handles new lists created outside app)
            Task {
                await reminderManager.reloadReminderLists()
            }
        }
    }
    
    private var colorScheme: ColorScheme? {
        switch colorTheme.appearanceTheme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
    
    // PERFECT APPLE INTELLIGENCE ANIMATION!
    private func triggerExactFloatingWindowAnimation(success: Bool) {
        guard colorTheme.animationsEnabled else { return }
        
        // Set the flash color (success/error from settings)
        backgroundFlashColor = success ? colorTheme.successColor : colorTheme.errorColor
        
        // INSTANT APPEAR with smooth scale-up
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showFlash = true
        }
        
        // SUPER SMOOTH color morphing - multiple cycles for beautiful effect
        withAnimation(.easeInOut(duration: 3.0).repeatCount(3, autoreverses: true)) {
            colorShift = 1.0
        }
        
        // SUPER SMOOTH continuous flow - NO PAUSE AT ALL
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 1.2)) {
                self.showFlash = false
            }
            
            // Reset color shift smoothly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.5)) {
                    self.colorShift = 0.0
                }
            }
        }
    }
    
    // Get current glow color with smooth morphing
    private func getCurrentGlowColor() -> Color {
        if showFlash {
            // Smoothly blend between flash color and bolt color based on colorShift
            return Color.lerp(backgroundFlashColor, colorTheme.boltColor, colorShift)
        } else {
            return colorTheme.boltColor
        }
    }
    
}


// MARK: - Enhanced Create Reminder View

struct PerfectCreateReminderView: View {
    @ObservedObject var reminderManager: SharedReminderManager
    @ObservedObject var colorTheme: SharedColorThemeManager
    @ObservedObject var speechManager: SharedSpeechManager
    @ObservedObject var animationManager: AnimationManager
    @Binding var insideWindowState: InsideWindowState
    let onTriggerAnimation: (Bool) -> Void
    
    @State private var reminderText = ""
    @State private var isProcessing = false
    @State private var isListening = false
    @State private var showingListPicker = false
    @State private var micRotation: Double = 0.0
    @State private var manualStop = false // Track if user manually stopped recording
    @FocusState private var isTextFieldFocused: Bool
    
    private let quickSuggestions = [
        "Call mom tomorrow",
        "Meeting Monday 10am",
        "Gym session 6pm",
        "Pay bills Friday"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header with centered bolt icon and list name underneath (CLICKABLE)
                VStack(spacing: 16) {
                    Button(action: { showingListPicker = true }) {
                        VStack(spacing: 12) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 60))
                                .foregroundColor(colorTheme.boltColor)
                                .shadow(color: colorTheme.boltColor.opacity(0.3), radius: 8, x: 0, y: 0)
                            
                            VStack(spacing: 4) {
                                Text(colorTheme.selectedListName)
                                    .font(.title.weight(.bold))
                                    .foregroundColor(colorTheme.boltColor)
                                
                                Text("Tap to change list")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("Type naturally or use voice")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Input section - REDESIGNED LAYOUT
                VStack(spacing: 24) {
                    // Text input ONLY (no microphone next to it)
                    VStack(spacing: 16) {
                        SyntaxHighlightedTextField(
                            text: $reminderText,
                            placeholder: "What would you like to remember?",
                            colorHelpersEnabled: colorTheme.colorHelpersEnabled,
                            shortcutsEnabled: colorTheme.shortcutsEnabled,
                            timePeriodsEnabled: colorTheme.timePeriodsEnabled,
                            onSubmit: {
                                createReminder()
                            }
                        )
                        .frame(height: 80)
                        .padding(.horizontal, 20)
                    }
                    
                    // UNIFIED BUTTONS - Create FIRST, Voice SECOND
                    HStack(spacing: 20) {
                        // Create button FIRST - CONSISTENT SIZE
                        Button(action: createReminder) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: reminderText.isEmpty ? [.gray] : [colorTheme.boltColor, colorTheme.boltColor.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 60, height: 60)
                                    .shadow(color: reminderText.isEmpty ? .clear : colorTheme.boltColor.opacity(0.4), radius: 8, x: 0, y: 4)
                                
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                        .animation(colorTheme.animationsEnabled ? 
                                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : 
                                            .none, value: isProcessing
                                        )
                                } else {
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(reminderText.isEmpty || isProcessing) // Available even while listening
                        
                        // Voice button SECOND - ANIMATED BACKGROUND WITH GLOW
                        Button(action: toggleVoiceRecognition) {
                            ZStack {
                                // Subtle glow when listening
                                if isListening {
                                    Circle()
                                        .fill(RadialGradient(
                                            colors: [.red.opacity(0.4), .orange.opacity(0.2), .clear],
                                            center: .center,
                                            startRadius: 25,
                                            endRadius: 35
                                        ))
                                        .frame(width: 60, height: 60)
                                        .blur(radius: 5)
                                        .scaleEffect(1.05)
                                        .animation(colorTheme.animationsEnabled ? 
                                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : 
                                            .none, value: isListening
                                        )
                                }
                                
                                // Static background
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: isListening ? 
                                            [.red, .orange] : 
                                            [colorTheme.boltColor, colorTheme.boltColor.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 60, height: 60)
                                    .shadow(color: (isListening ? Color.red : colorTheme.boltColor).opacity(0.4), radius: 8, x: 0, y: 4)
                                
                                // Animated rotating overlay when listening
                                if isListening {
                                    Circle()
                                        .fill(
                                            AngularGradient(
                                                colors: [.red.opacity(0.9), .orange.opacity(0.9), .yellow.opacity(0.7), .red.opacity(0.9)],
                                                center: .center
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                        .rotationEffect(.degrees(micRotation))
                                        .animation(colorTheme.animationsEnabled ? 
                                            .linear(duration: 2.0).repeatForever(autoreverses: false) : 
                                            .none, value: micRotation
                                        )
                                        .opacity(0.8)
                                        .blendMode(.overlay)
                                }
                                
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                                    .shadow(color: isListening ? .white.opacity(0.8) : .clear, radius: 4)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // STATE-BASED UI DISPLAY with SMOOTH ANIMATIONS - Before Quick Ideas
                switch insideWindowState {
                case .hidden:
                    EmptyView()
                case .showingList(let reminders):
                    RemindersDisplayView(reminders: reminders, onDismiss: { 
                        withAnimation(colorTheme.animationsEnabled ? .spring(response: 0.6, dampingFraction: 0.8) : .none) {
                            insideWindowState = .hidden 
                        }
                    })
                    .transition(colorTheme.animationsEnabled ? 
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ) : .identity
                    )
                    .animation(colorTheme.animationsEnabled ? 
                        .spring(response: 0.7, dampingFraction: 0.8) : 
                        .none, value: insideWindowState
                    )
                case .showingDuplicates(let reminders, let action):
                    DuplicateRemindersView(reminders: reminders, onSelect: { selected in
                        action(selected)
                        withAnimation(colorTheme.animationsEnabled ? .spring(response: 0.5, dampingFraction: 0.7) : .none) {
                            insideWindowState = .hidden
                        }
                    }, onDismiss: { 
                        withAnimation(colorTheme.animationsEnabled ? .spring(response: 0.6, dampingFraction: 0.8) : .none) {
                            insideWindowState = .hidden 
                        }
                    }, colorTheme: colorTheme)
                    .transition(colorTheme.animationsEnabled ? 
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ) : .identity
                    )
                    .animation(colorTheme.animationsEnabled ? 
                        .spring(response: 0.6, dampingFraction: 0.75) : 
                        .none, value: insideWindowState
                    )
                }
                
                // Quick suggestions with SMOOTH ANIMATIONS - Moved below sections
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
                            ForEach(Array((colorTheme.customQuickIdeas.isEmpty ? quickSuggestions : colorTheme.customQuickIdeas).enumerated()), id: \.element) { index, suggestion in
                                Button(action: {
                                    withAnimation(colorTheme.animationsEnabled ? .spring(response: 0.4, dampingFraction: 0.6) : .none) {
                                        reminderText = suggestion
                                        isTextFieldFocused = true
                                    }
                                }) {
                                    Text(suggestion)
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(8)
                                        .shadow(color: colorTheme.boltColor.opacity(0.1), radius: 2, x: 0, y: 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .transition(colorTheme.animationsEnabled ? 
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ) : .identity
                    )
                    .animation(colorTheme.animationsEnabled ? 
                        .spring(response: 0.6, dampingFraction: 0.8) : 
                        .none, value: reminderText.isEmpty && !isListening
                    )
                }
                
                Spacer()
            }
        }
        .contentShape(Rectangle()) // Make entire ScrollView tappable
        .onTapGesture {
            // Dismiss keyboard when tapping background
            isTextFieldFocused = false
            // Force dismiss keyboard using UIKit as backup
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .sheet(isPresented: $showingListPicker) {
            ReminderListPickerView(
                reminderManager: reminderManager,
                colorTheme: colorTheme,
                isPresented: $showingListPicker
            )
        }
        .onReceive(speechManager.$transcription) { transcription in
            reminderText = transcription
        }
        .onReceive(speechManager.$isListening) { listening in
            isListening = listening
        }
        .onAppear {
            // Set up voice trigger callbacks like macOS
            speechManager.onAutoSend = { finalTranscription in
                DispatchQueue.main.async {
                    reminderText = finalTranscription
                    createReminder()
                    reminderText = ""
                    isTextFieldFocused = false // Dismiss keyboard after voice command
                    // Force dismiss keyboard using UIKit
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .onChange(of: reminderText) { _, newValue in
            // Reset state when user starts typing new content (same as macOS)
            if !newValue.isEmpty && insideWindowState != .hidden {
                insideWindowState = .hidden
            }
        }
    }
    
    private func toggleVoiceRecognition() {
        if isListening {
            manualStop = true // Mark as manual stop
            speechManager.stopListening()
            // Stop background animation
            micRotation = 0.0
            // When manually stopped, just keep the current text - don't auto-send
        } else {
            manualStop = false // Reset manual stop flag
            speechManager.startListening(
                onUpdate: { transcript in
                    reminderText = transcript
                },
                completion: { finalTranscript in
                    // Only set text if it wasn't manually stopped and not empty
                    if !manualStop && !finalTranscript.isEmpty {
                        reminderText = finalTranscript
                    }
                    // Reset manual stop flag
                    manualStop = false
                }
            )
            // Start background animation
            micRotation = 360.0
        }
    }
    
    private func createReminder() {
        guard !reminderText.isEmpty, !isProcessing else { return }
        
        // If listening while user pressed send, stop listening first
        if isListening {
            speechManager.stopListening()
            micRotation = 0.0
        }
        
        let text = reminderText.lowercased()
        
        // Check for delete commands - EXACTLY like macOS with proper trailing spaces
        let deleteKeywords = colorTheme.shortcutsEnabled ? 
            ["delete ", "remove ", "rm "] : 
            ["delete ", "remove "]
        
        if deleteKeywords.contains(where: { text.starts(with: $0) }) {
            handleDeleteCommand(text)
            return
        }
        
        // Check for move/reschedule commands - EXACTLY like macOS with proper trailing spaces
        let moveKeywords = colorTheme.shortcutsEnabled ?
            ["move ", "reschedule ", "mv "] :
            ["move ", "reschedule "]
        
        if moveKeywords.contains(where: { text.starts(with: $0) }) {
            handleMoveCommand(text)
            return
        }
        
        // Check for list commands - EXACTLY like macOS
        let listKeywords = colorTheme.shortcutsEnabled ?
            ["list", "ls"] :
            ["list"]
        
        if listKeywords.contains(where: { text.starts(with: $0) }) {
            handleListCommand()
            return
        }
        
        // Regular reminder creation
        isProcessing = true
        let textToProcess = reminderText
        reminderText = ""
        isTextFieldFocused = false // Dismiss keyboard after manual reminder creation
        // Force dismiss keyboard using UIKit
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        Task {
            do {
                try await reminderManager.createReminder(from: textToProcess)
                
                await MainActor.run {
                    isProcessing = false
                    
                    // SUCCESS - trigger background gradient animation
                    onTriggerAnimation(true)
                    
                    // Haptic feedback (with error handling)
                    if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    
                    // ERROR - trigger background gradient animation
                    onTriggerAnimation(false)
                    
                    // Error haptic feedback (with error handling)
                    if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil {
                        let notification = UINotificationFeedbackGenerator()
                        notification.notificationOccurred(.error)
                    }
                }
            }
        }
    }
    
    // MARK: - Command Handling Functions (like macOS)
    
    private func handleListCommand() {
        let originalText = reminderText
        reminderText = ""
        isTextFieldFocused = false // Dismiss keyboard after list command
        // Force dismiss keyboard using UIKit
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Trigger SUCCESS animation for list command like macOS
        onTriggerAnimation(true)
        
        // Parse list command: "list", "list today", "list jelo", etc.
        let words = originalText.lowercased().components(separatedBy: " ")
        let filter = words.count > 1 ? words.dropFirst().joined(separator: " ") : "all"
        
        reminderManager.getAllReminders { reminders in
            DispatchQueue.main.async {
                var filteredReminders: [EKReminder] = []
                
                // Check if filter matches a list name first
                let listMatch = reminderManager.availableLists.first { list in
                    list.title.lowercased() == filter.lowercased()
                }
                
                if let targetList = listMatch {
                    // Filter by specific list name (e.g., "list jelo")
                    filteredReminders = reminders.filter { 
                        $0.calendar?.calendarIdentifier == targetList.calendarIdentifier && !$0.isCompleted
                    }
                } else {
                    // Filter by date/time (e.g., "list today", "list tomorrow") - use keyboard approach
                    filteredReminders = self.filterRemindersByDateKeyboardStyle(reminders, command: originalText)
                }
                
                if filteredReminders.isEmpty {
                    // Animate empty state appearance
                    withAnimation(colorTheme.animationsEnabled ? .spring(response: 0.6, dampingFraction: 0.8) : .none) {
                        self.insideWindowState = .showingList([])
                    }
                } else {
                    // Animate filtered reminders appearance
                    withAnimation(colorTheme.animationsEnabled ? .spring(response: 0.6, dampingFraction: 0.8) : .none) {
                        self.insideWindowState = .showingList(filteredReminders)
                    }
                }
            }
        }
    }
    
    private func handleDeleteCommand(_ text: String) {
        // Extract reminder title from "delete X", "remove X", or "rm X"
        let words = text.components(separatedBy: " ")
        guard words.count > 1 else {
            // Trigger ERROR animation for invalid command
            onTriggerAnimation(false)
            return
        }
        
        let titleToDelete = words.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        reminderText = ""
        isTextFieldFocused = false // Dismiss keyboard after delete command
        // Force dismiss keyboard using UIKit
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Trigger SUCCESS animation for delete command like macOS
        onTriggerAnimation(true)
        
        // Filter reminders by selected list if setting is enabled
        let searchCallback: ([EKReminder]) -> Void = { allReminders in
            let filteredReminders: [EKReminder]
            if colorTheme.searchInSelectedListOnly, let selectedList = reminderManager.selectedList {
                filteredReminders = allReminders.filter { $0.calendar?.calendarIdentifier == selectedList.calendarIdentifier }
            } else {
                filteredReminders = allReminders
            }
            
            DispatchQueue.main.async {
                if filteredReminders.count > 1 {
                    // Multiple matches found - animate duplicate selection UI appearance
                    let deleteAction = { (selectedReminder: EKReminder) in
                        self.reminderManager.deleteReminder(selectedReminder) { success, error in
                            // No notification popup - silent deletion like macOS
                        }
                    }
                    withAnimation(colorTheme.animationsEnabled ? .spring(response: 0.6, dampingFraction: 0.8) : .none) {
                        self.insideWindowState = .showingDuplicates(filteredReminders, deleteAction)
                    }
                } else if let reminderToDelete = filteredReminders.first {
                    // Single match - delete it
                    self.reminderManager.deleteReminder(reminderToDelete) { success, error in
                        // No notification popup - silent deletion like macOS
                    }
                } else {
                    // No matches found - no notification popup like macOS
                }
            }
        }
        
        reminderManager.findReminder(withTitle: titleToDelete, completion: searchCallback)
    }
    
    private func handleMoveCommand(_ text: String) {
        // Parse "move X to Y", "reschedule X to Y", or "mv X to Y"
        let words = text.components(separatedBy: " ")
        
        // Find "to" keyword to split the command
        guard let toIndex = words.firstIndex(of: "to"), toIndex > 1 else {
            // Trigger ERROR animation for invalid command
            onTriggerAnimation(false)
            return
        }
        
        // Extract reminder title (everything between "move"/"reschedule" and "to")
        let titleWords = Array(words[1..<toIndex])
        let titleToMove = titleWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract new date/time (everything after "to")
        let dateWords = Array(words[(toIndex + 1)...])
        let newDateText = dateWords.joined(separator: " ")
        
        reminderText = ""
        isTextFieldFocused = false // Dismiss keyboard after move command
        // Force dismiss keyboard using UIKit
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Parse the new date
        let parsedReminder = reminderManager.nlParser.parseReminderText("dummy " + newDateText)
        guard let newDate = parsedReminder.dueDate else {
            // Trigger ERROR animation for invalid date
            onTriggerAnimation(false)
            return
        }
        
        // Trigger SUCCESS animation for move command like macOS
        onTriggerAnimation(true)
        
        // Filter reminders by selected list if setting is enabled
        let moveSearchCallback: ([EKReminder]) -> Void = { allReminders in
            let filteredReminders: [EKReminder]
            if colorTheme.searchInSelectedListOnly, let selectedList = reminderManager.selectedList {
                filteredReminders = allReminders.filter { $0.calendar?.calendarIdentifier == selectedList.calendarIdentifier }
            } else {
                filteredReminders = allReminders
            }
            
            DispatchQueue.main.async {
                if filteredReminders.count > 1 {
                    // Multiple matches found - animate duplicate selection UI appearance
                    let moveAction = { (selectedReminder: EKReminder) in
                        self.reminderManager.moveReminder(selectedReminder, to: newDate) { success, error in
                            // No notification popup - silent move like macOS
                        }
                    }
                    withAnimation(colorTheme.animationsEnabled ? .spring(response: 0.6, dampingFraction: 0.8) : .none) {
                        self.insideWindowState = .showingDuplicates(filteredReminders, moveAction)
                    }
                } else if let reminderToMove = filteredReminders.first {
                    // Single match - move it
                    self.reminderManager.moveReminder(reminderToMove, to: newDate) { success, error in
                        // No notification popup - silent move like macOS
                    }
                } else {
                    // No matches found - no notification popup like macOS
                }
            }
        }
        
        reminderManager.findReminder(withTitle: titleToMove, completion: moveSearchCallback)
    }
    
    // MARK: - Date Filtering Functions (EXACTLY like macOS)
    
    private func filterRemindersByDateKeyboardStyle(_ reminders: [EKReminder], command: String) -> [EKReminder] {
        let calendar = Calendar.current
        
        // Parse date from command using keyboard approach
        let targetDate = parseDateFromCommandKeyboardStyle(command)
        
        if let date = targetDate {
            // Filter reminders for specific date
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else {
                    return false // Only show reminders with due dates for date-specific queries
                }
                return calendar.isDate(dueDate, inSameDayAs: date)
            }
        } else if !command.isEmpty && (command.lowercased().contains("week") || command.lowercased().contains("month")) {
            // Handle week/month filters
            return filterRemindersForPeriodKeyboardStyle(reminders, command: command)
        } else {
            // No specific date filter - return all non-completed reminders
            return reminders.filter { !$0.isCompleted }
        }
    }
    
    private func parseDateFromCommandKeyboardStyle(_ command: String) -> Date? {
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
    
    private func filterRemindersForPeriodKeyboardStyle(_ reminders: [EKReminder], command: String) -> [EKReminder] {
        let calendar = Calendar.current
        let today = Date()
        let lowercaseCommand = command.lowercased()
        
        if lowercaseCommand.contains("this week") {
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return weekInterval.contains(dueDate)
            }
        } else if lowercaseCommand.contains("next week") {
            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: today),
                  let weekInterval = calendar.dateInterval(of: .weekOfYear, for: nextWeek) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return weekInterval.contains(dueDate)
            }
        } else if lowercaseCommand.contains("this month") {
            guard let monthInterval = calendar.dateInterval(of: .month, for: today) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return monthInterval.contains(dueDate)
            }
        } else if lowercaseCommand.contains("next month") {
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: today),
                  let monthInterval = calendar.dateInterval(of: .month, for: nextMonth) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return monthInterval.contains(dueDate)
            }
        }
        
        return reminders.filter { !$0.isCompleted }
    }
    
    private func filterRemindersByDate(_ reminders: [EKReminder], filter: String) -> [EKReminder] {
        let expandedFilter = expandDayShortcuts(filter)
        let calendar = Calendar.current
        let now = Date()
        
        switch expandedFilter.lowercased() {
        case "today":
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: now)
            }
            
        case "tomorrow":
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: tomorrow)
            }
            
        case "this week":
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return weekInterval.contains(dueDate)
            }
            
        case "this month":
            guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return monthInterval.contains(dueDate)
            }
            
        case "next week":
            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now),
                  let weekInterval = calendar.dateInterval(of: .weekOfYear, for: nextWeek) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return weekInterval.contains(dueDate)
            }
            
        case "next month":
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now),
                  let monthInterval = calendar.dateInterval(of: .month, for: nextMonth) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return monthInterval.contains(dueDate)
            }
            
        case "overdue":
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return dueDate < now
            }
            
        case "scheduled":
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return dueDate >= calendar.startOfDay(for: now)
            }
            
        case "completed":
            return reminders.filter { $0.isCompleted }
            
        case "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday":
            let targetWeekday = weekdayNumber(for: expandedFilter)
            guard let nextWeekDay = getNextWeekday(targetWeekday, from: now) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: nextWeekDay)
            }
            
        case let thisDay where thisDay.hasPrefix("this "):
            let day = String(thisDay.dropFirst(5))
            let targetWeekday = weekdayNumber(for: day)
            guard let thisWeekDay = getThisWeekday(targetWeekday, from: now) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: thisWeekDay)
            }
            
        case let nextDay where nextDay.hasPrefix("next "):
            let day = String(nextDay.dropFirst(5))
            let targetWeekday = weekdayNumber(for: day)
            guard let nextWeekDay = getNextWeekday(targetWeekday, from: now) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: nextWeekDay)
            }
            
        case "all":
            return reminders.filter { !$0.isCompleted }
            
        default:
            return reminders.filter { !$0.isCompleted }
        }
    }
    
    private func expandDayShortcuts(_ text: String) -> String {
        // Only expand shortcuts if the setting is enabled, but always return the text
        // This allows full weekday names like "monday" to work regardless of shortcut setting
        if colorTheme.shortcutsEnabled {
            let shortcuts = [
                "tm": "tomorrow",
                "td": "today",
                "mon": "monday",
                "tue": "tuesday", 
                "wed": "wednesday",
                "thu": "thursday",
                "fri": "friday",
                "sat": "saturday",
                "sun": "sunday"
            ]
            
            var expanded = text
            for (shortcut, fullForm) in shortcuts {
                expanded = expanded.replacingOccurrences(of: shortcut, with: fullForm)
            }
            return expanded
        } else {
            // When shortcuts disabled, return text as-is (full weekday names like "monday" still work)
            return text
        }
    }
    
    private func weekdayNumber(for day: String) -> Int {
        switch day.lowercased() {
        case "sunday": return 1
        case "monday": return 2
        case "tuesday": return 3
        case "wednesday": return 4
        case "thursday": return 5
        case "friday": return 6
        case "saturday": return 7
        default: return 0
        }
    }
    
    private func getThisWeekday(_ weekday: Int, from date: Date) -> Date? {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        let daysToAdd = weekday - currentWeekday
        return calendar.date(byAdding: .day, value: daysToAdd, to: date)
    }
    
    private func getNextWeekday(_ weekday: Int, from date: Date) -> Date? {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        var daysToAdd = weekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7
        }
        return calendar.date(byAdding: .day, value: daysToAdd, to: date)
    }
    
    // MARK: - Helper Functions
    
    private func formatDate(_ components: DateComponents?) -> String {
        guard let components = components else { return "No date" }
        
        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else { return "Invalid date" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Reminder List Picker View

struct ReminderListPickerView: View {
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

// MARK: - EXACT Floating Window Animation - Full Screen Version

struct ExactFloatingWindowAnimationView: View {
    let glowAnimation: Bool
    let glowStops: [Gradient.Stop]
    @ObservedObject var colorTheme: SharedColorThemeManager
    let isSuccess: Bool
    
    var body: some View {
        ZStack {
            // FULL SCREEN Background - covers entire screen
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .ignoresSafeArea(.all)
            
            // CENTER AREA - EXACT floating window animation
            ZStack {
                // PRIMARY ANIMATED GRADIENT (exactly like floating window)
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        AngularGradient(
                            stops: glowStops.isEmpty ? [Gradient.Stop(color: .clear, location: 0)] : glowStops,
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        )
                    )
                    .frame(width: 300, height: 300)
                    .blur(radius: 30)
                    .rotationEffect(.degrees(glowAnimation ? 360 : 0))
                    .animation(.linear(duration: 3).repeatCount(1, autoreverses: false), value: glowAnimation)
                    .opacity(glowAnimation ? 0.6 : 0)
                    .animation(.easeInOut(duration: 0.6), value: glowAnimation)
                
                // SECONDARY FLOWING LAYER (exactly like floating window)
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        AngularGradient(
                            stops: glowStops.isEmpty ? [Gradient.Stop(color: .clear, location: 0)] : glowStops,
                            center: .center,
                            startAngle: .degrees(180),
                            endAngle: .degrees(540)
                        )
                    )
                    .frame(width: 300, height: 300)
                    .blur(radius: 20)
                    .rotationEffect(.degrees(glowAnimation ? -240 : 0))
                    .animation(.easeInOut(duration: 2.5).repeatCount(1, autoreverses: false), value: glowAnimation)
                    .opacity(glowAnimation ? 0.45 : 0)
                    .animation(.easeInOut(duration: 0.8), value: glowAnimation)
                
                // CENTER ICON
                VStack(spacing: 20) {
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.5), radius: 20, x: 0, y: 10)
                        .scaleEffect(glowAnimation ? 1.2 : 0.8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.4), value: glowAnimation)
                    
                    Text(isSuccess ? "✨ Reminder Created!" : "❌ Failed to Create")
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
        }
    }
}

// MARK: - Reminders Display View (Enhanced with segments like macOS)

struct RemindersDisplayView: View {
    let reminders: [EKReminder]
    let onDismiss: () -> Void
    
    // Group reminders by their calendar/list
    private var groupedReminders: [String: [EKReminder]] {
        Dictionary(grouping: reminders) { reminder in
            reminder.calendar?.title ?? "Unknown List"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("📋 Found \(reminders.count) reminder\(reminders.count == 1 ? "" : "s")")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                if groupedReminders.count > 1 {
                    Text("in \(groupedReminders.count) lists")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Close", action: onDismiss)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.blue)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(groupedReminders.keys.sorted()), id: \.self) { listName in
                        let listReminders = groupedReminders[listName] ?? []
                        
                        VStack(alignment: .leading, spacing: 8) {
                            // List header with color dot
                            HStack {
                                Circle()
                                    .fill(Color(cgColor: listReminders.first?.calendar?.cgColor ?? CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)))
                                    .frame(width: 12, height: 12)
                                
                                Text(listName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                
                                Text("(\(listReminders.count))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            
                            // Reminders in this list
                            ForEach(Array(listReminders.enumerated()), id: \.element.calendarItemIdentifier) { index, reminder in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("• \(reminder.title ?? "Untitled")")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    if let dueDateComponents = reminder.dueDateComponents {
                                        Text("Due: \(formatReminderDate(dueDateComponents))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 16)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(6)
                            }
                            .padding(.horizontal, 8)
                        }
                        .padding(.vertical, 8)
                        .background(Color(UIColor.systemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
            }
            .frame(maxHeight: 350)
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
    
    private func formatReminderDate(_ components: DateComponents) -> String {
        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else { return "Invalid date" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Duplicate Reminders View (same as macOS)

struct DuplicateRemindersView: View {
    let reminders: [EKReminder]
    let onSelect: (EKReminder) -> Void
    let onDismiss: () -> Void
    @ObservedObject var colorTheme: SharedColorThemeManager
    
    // Group reminders by list when showing across multiple lists
    private var groupedReminders: [String: [EKReminder]] {
        Dictionary(grouping: reminders) { reminder in
            reminder.calendar?.title ?? "Unknown List"
        }
    }
    
    private var shouldShowGrouped: Bool {
        !colorTheme.searchInSelectedListOnly && groupedReminders.count > 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🔍 Multiple reminders found")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Cancel", action: onDismiss)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.red)
            }
            
            Text("Please select which one:")
                .font(.body)
                .foregroundColor(.secondary)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    if shouldShowGrouped {
                        // SHOW GROUPED BY LIST
                        ForEach(Array(groupedReminders.keys.sorted()), id: \.self) { listName in
                            // List header
                            HStack {
                                Circle()
                                    .fill(Color(cgColor: (groupedReminders[listName]?.first?.calendar?.cgColor ?? CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0))))
                                    .frame(width: 10, height: 10)
                                
                                Text(listName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                
                                Text("(\(groupedReminders[listName]?.count ?? 0))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            .padding(.top, 8)
                            
                            // Reminders in this list
                            ForEach(groupedReminders[listName] ?? [], id: \.calendarItemIdentifier) { reminder in
                                Button(action: { onSelect(reminder) }) {
                                    ReminderDuplicateRowView(reminder: reminder)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        // SHOW SIMPLE LIST
                        ForEach(reminders, id: \.calendarItemIdentifier) { reminder in
                            Button(action: { onSelect(reminder) }) {
                                ReminderDuplicateRowView(reminder: reminder)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxHeight: 250)
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
    
    private func formatReminderDate(_ components: DateComponents) -> String {
        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else { return "Invalid date" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Reminder Duplicate Row View

struct ReminderDuplicateRowView: View {
    let reminder: EKReminder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(reminder.title ?? "Untitled")
                .font(.body.weight(.medium))
                .foregroundColor(.primary)
            
            if let dueDateComponents = reminder.dueDateComponents {
                Text("Due: \(formatReminderDate(dueDateComponents))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func formatReminderDate(_ components: DateComponents) -> String {
        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else { return "Invalid date" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Color Extension for Smooth Blending

extension Color {
    static func lerp(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let uiColorA = UIColor(a)
        let uiColorB = UIColor(b)

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        uiColorA.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)

        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        uiColorB.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let r = r1 + (r2 - r1) * t
        let g = g1 + (g2 - g1) * t
        let b = b1 + (b2 - b1) * t
        let a = a1 + (a2 - a1) * t

        return Color(red: r, green: g, blue: b, opacity: a)
    }
}
#endif
