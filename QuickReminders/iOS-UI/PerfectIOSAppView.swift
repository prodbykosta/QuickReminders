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
import Contacts
import ContactsUI
import MapKit
import CoreLocation

// MARK: - Inside Window State (same as macOS)
enum InsideWindowState: Equatable {
    case hidden
    case showingList([EKReminder])
    case showingDuplicates([EKReminder], (EKReminder) -> Void)
    case showingGoogleList([UniversalReminder])
    case showingGoogleDuplicates([UniversalReminder], (UniversalReminder) -> Void)

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
        case (.showingGoogleList(let lhs), .showingGoogleList(let rhs)):
            return lhs.count == rhs.count && lhs.map(\.id) == rhs.map(\.id)
        case (.showingGoogleDuplicates(let lhs, _), .showingGoogleDuplicates(let rhs, _)):
            return lhs.count == rhs.count && lhs.map(\.id) == rhs.map(\.id)
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
            // CRITICAL: Request permissions immediately on iOS app start
            reminderManager.requestPermissionManually()
            
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

    // NEW: Feature integration states
    @StateObject private var contactResolver = ContactResolver()
    @StateObject private var locationResolver = LocationResolver()
    @State private var selectedContact: CNContact?
    @State private var selectedLocation: MKMapItem?
    @State private var locationProximity: EKAlarmProximity = .enter  // NEW: Location proximity
    @State private var notesText = ""
    @State private var showNotesField = false
    @State private var parsedVariables: [ParsedVariable] = []
    @State private var isUrgent = false  // NEW: Urgent toggle state
    @State private var showContactPicker = false  // NEW: Contact picker state
    @State private var showLocationPicker = false  // NEW: Location picker state
    @State private var overriddenRanges: [NSRange] = []  // NEW: Track toggled-off highlighted words
    @State private var isEditingVariables = false  // NEW: Edit mode for toggling variables

    // AI Mode states
    @State private var isAIProcessing = false
    @State private var aiTransformPreview: String? = nil
    @State private var pendingReminderData: PendingReminderData? = nil

    private let quickSuggestions = [
        "Call mom tomorrow",
        "Meeting Monday 10am",
        "Gym session 6pm",
        "Pay bills Friday"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // SHOW ONLY PERMISSION WARNING IF NO REMINDERS ACCESS
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

                // Header with centered bolt icon and list name underneath (CLICKABLE)
                VStack(spacing: 16) {
                    Button(action: { showingListPicker = true }) {
                        VStack(spacing: 12) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 60))
                                .foregroundColor(colorTheme.boltColor)
                                .shadow(color: colorTheme.boltColor.opacity(0.3), radius: 8, x: 0, y: 0)

                            VStack(spacing: 4) {
                                Text(reminderManager.currentListName)
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
                .padding(.top, !reminderManager.hasAccess ? 0 : 40)
                
                // Input section - REDESIGNED LAYOUT
                VStack(spacing: 24) {
                    // Text input ONLY (no microphone next to it)
                    VStack(spacing: 16) {
                        // Edit mode indicator
                        if isEditingVariables {
                            HStack {
                                Image(systemName: "hand.tap.fill")
                                    .foregroundColor(.orange)
                                Text("Tap colored words to toggle")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        }

                        SyntaxHighlightedTextField(
                            text: $reminderText,
                            placeholder: "What would you like to remember?",
                            colorHelpersEnabled: colorTheme.colorHelpersEnabled,
                            shortcutsEnabled: colorTheme.shortcutsEnabled,
                            timePeriodsEnabled: colorTheme.timePeriodsEnabled,
                            onSubmit: {
                                createReminder()
                            },
                            overriddenRanges: $overriddenRanges,
                            onTapHighlightedWord: colorTheme.enableVariableToggle ? { tappedRange in
                                // Only allow toggling if feature is enabled
                                // Toggle: if range is already overridden, remove it; otherwise add it
                                if let index = overriddenRanges.firstIndex(where: { NSEqualRanges($0, tappedRange) }) {
                                    // Already overridden - turn back to colored (remove from list)
                                    overriddenRanges.remove(at: index)
                                } else {
                                    // Not overridden yet - add underline (add to list)
                                    overriddenRanges.append(tappedRange)
                                }
                            } : nil,  // Don't add gesture if feature is disabled
                            isEditMode: isEditingVariables  // Pass edit mode state
                        )
                        .frame(height: 80)
                        .padding(.horizontal, 20)
                        .onChange(of: reminderText) {
                            // Clean up overridden ranges that are no longer valid (only if feature enabled)
                            if colorTheme.enableVariableToggle {
                                overriddenRanges.removeAll { range in
                                    range.location + range.length > reminderText.count
                                }
                            }
                            // Exit edit mode if text is cleared
                            if reminderText.isEmpty {
                                isEditingVariables = false
                            }
                        }
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
                                
                                if isProcessing || isAIProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                        .animation(colorTheme.animationsEnabled ?
                                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true) :
                                            .none, value: isProcessing || isAIProcessing
                                        )
                                } else {
                                    Image(systemName: colorTheme.aiModeEnabled ? "wand.and.stars" : "plus")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(reminderText.isEmpty || isProcessing || isAIProcessing) // Available even while listening
                        
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

                    // NEW: Feature Buttons with Visual Feedback (Centered)
                    HStack(spacing: 16) {
                        Spacer()  // Add spacer before buttons to center them

                        // Contact Button with highlight when selected
                        Button(action: {
                            showContactPicker = true
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: selectedContact != nil ? "person.fill" : "person")
                                    .font(.system(size: 20))
                                    .foregroundColor(selectedContact != nil ? .white : colorTheme.boltColor)
                                Text("Contact")
                                    .font(.caption2)
                                    .foregroundColor(selectedContact != nil ? .white : .secondary)
                            }
                            .frame(width: 70, height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedContact != nil ? colorTheme.boltColor : Color.secondary.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedContact != nil ? colorTheme.boltColor : Color.clear, lineWidth: 2)
                            )
                        }
                        .sheet(isPresented: $showContactPicker) {
                            ContactPickerView(selectedContact: $selectedContact)
                        }

                        // Location Button with highlight when selected
                        Button(action: {
                            showLocationPicker = true
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: selectedLocation != nil ? "location.fill" : "location")
                                    .font(.system(size: 20))
                                    .foregroundColor(selectedLocation != nil ? .white : colorTheme.boltColor)
                                Text("Location")
                                    .font(.caption2)
                                    .foregroundColor(selectedLocation != nil ? .white : .secondary)
                            }
                            .frame(width: 70, height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedLocation != nil ? colorTheme.boltColor : Color.secondary.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedLocation != nil ? colorTheme.boltColor : Color.clear, lineWidth: 2)
                            )
                        }
                        .sheet(isPresented: $showLocationPicker) {
                            LocationPickerView(selectedLocation: $selectedLocation, locationProximity: $locationProximity)
                        }

                        // Urgent Toggle Button
                        Button(action: {
                            isUrgent.toggle()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: isUrgent ? "exclamationmark.circle.fill" : "exclamationmark.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(isUrgent ? .white : .red)
                                Text("Urgent")
                                    .font(.caption2)
                                    .foregroundColor(isUrgent ? .white : .secondary)
                            }
                            .frame(width: 70, height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isUrgent ? Color.red : Color.secondary.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isUrgent ? Color.red : Color.clear, lineWidth: 2)
                            )
                        }

                        // Edit Variables Button (always visible if feature enabled)
                        if colorTheme.enableVariableToggle {
                            Button(action: {
                                isEditingVariables.toggle()
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: isEditingVariables ? "checkmark.circle.fill" : "text.word.spacing")
                                        .font(.system(size: 20))
                                        .foregroundColor(isEditingVariables ? .white : .orange)
                                    Text(isEditingVariables ? "Done" : "Edit")
                                        .font(.caption2)
                                        .foregroundColor(isEditingVariables ? .white : .secondary)
                                }
                                .frame(width: 70, height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isEditingVariables ? Color.orange : Color.secondary.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isEditingVariables ? Color.orange : Color.clear, lineWidth: 2)
                                )
                            }
                            .disabled(reminderText.isEmpty)  // Disable when no text
                            .opacity(reminderText.isEmpty ? 0.5 : 1.0)  // Show as disabled
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    // NEW: Notes Expansion View (if enabled in settings)
                    if colorTheme.enableNotesField {
                        NotesExpansionView(
                            notes: $notesText,
                            isExpanded: $showNotesField
                        )
                        .environmentObject(colorTheme)
                    }
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
                case .showingGoogleList(let reminders):
                    GoogleRemindersDisplayView(reminders: reminders, onDismiss: {
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
                case .showingGoogleDuplicates(let reminders, let action):
                    GoogleDuplicateRemindersView(reminders: reminders, onSelect: { selected in
                        action(selected)
                        withAnimation(colorTheme.animationsEnabled ? .spring(response: 0.5, dampingFraction: 0.7) : .none) {
                            insideWindowState = .hidden
                        }
                    }, onDismiss: {
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
                } // End of else block - main content only when permissions granted
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
        .sheet(isPresented: Binding(
            get: { aiTransformPreview != nil },
            set: { if !$0 { cancelAIReminder() } }
        )) {
            AIPreviewSheet(
                originalText: pendingReminderData?.originalText ?? "",
                transformedText: aiTransformPreview ?? "",
                accentColor: colorTheme.dynamicAccentColor,
                onConfirm: { confirmAIReminder() },
                onCancel: { cancelAIReminder() }
            )
        }
        .onReceive(speechManager.$transcription) { transcription in
            reminderText = transcription
        }
        .onReceive(speechManager.$isListening) { listening in
            isListening = listening
        }
        .onAppear {
            // CRITICAL: Request permissions for reminder creation
            reminderManager.requestPermissionManually()
            
            // Set up voice trigger callbacks like macOS
            speechManager.onAutoSend = { finalTranscription in
                DispatchQueue.main.async {
                    // Stop mic animation — tryStop() already ran in speech manager
                    isListening = false
                    micRotation = 0.0
                    reminderText = finalTranscription
                    createReminder()
                    isTextFieldFocused = false
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
        // CHECK PERMISSIONS FIRST - If no permissions, open Settings instead of activating
        if !speechManager.hasPermissions() {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            return
        }

        // During AI processing, tapping mic stops any lingering speech recognition
        if isAIProcessing {
            speechManager.stopListening()
            speechManager.onTranscriptionUpdate = nil
            return
        }

        if isListening {
            manualStop = true // Mark as manual stop
            speechManager.stopListening()
            // Stop background animation
            micRotation = 0.0
            // When manually stopped, just keep the current text - don't auto-send
        } else {
            manualStop = false // Reset manual stop flag
            // Use selected AI locale when AI mode is on, otherwise always English
            let locale = colorTheme.aiModeEnabled ? colorTheme.aiVoiceLocale : "en-US"
            speechManager.setLocale(locale)
            speechManager.startListening(
                onUpdate: { transcript in
                    if !manualStop {
                        reminderText = transcript
                    }
                },
                completion: { finalTranscript in
                    // Only set text if it wasn't manually stopped and not empty
                    if !manualStop && !finalTranscript.isEmpty {
                        reminderText = finalTranscript
                    }
                    // Do NOT reset manualStop here — it stays true until the next session
                    // starts (reset in the else branch above), so any late onUpdate callbacks
                    // from the speech engine can't overwrite the user's manual edits.
                }
            )
            // Start background animation
            micRotation = 360.0
        }
    }
    
    private func createReminder() {
        guard !reminderText.isEmpty, !isProcessing, !isAIProcessing else { return }

        // If listening while user pressed send, stop listening first
        if isListening {
            speechManager.stopListening()
            micRotation = 0.0
        }

        // AI Mode: transform text before NL parsing
        if colorTheme.aiModeEnabled {
            // Ensure mic is fully stopped before AI processing starts
            speechManager.stopListening()
            speechManager.onTranscriptionUpdate = nil  // Prevent any stale callbacks from writing to reminderText
            isListening = false
            micRotation = 0.0

            let capturedText = reminderText
            let capturedContact = selectedContact
            let capturedLocation = selectedLocation
            let capturedProximity = locationProximity
            let capturedNotes = notesText.isEmpty ? nil : notesText
            let capturedUrgent = isUrgent
            let capturedOverriddenRanges = overriddenRanges

            isAIProcessing = true
            reminderText = ""
            overriddenRanges.removeAll()
            isEditingVariables = false
            selectedContact = nil
            selectedLocation = nil
            locationProximity = .enter
            notesText = ""
            showNotesField = false
            isUrgent = false
            isTextFieldFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

            Task {
                do {
                    let transformed = try await callGemini(input: capturedText)
                    await MainActor.run {
                        isAIProcessing = false
                        let lower = transformed.lowercased()

                        // Route commands returned by Gemini
                        if lower.starts(with: "delete ") || lower.starts(with: "remove ") {
                            handleDeleteCommand(lower)
                        } else if lower.starts(with: "move ") {
                            handleMoveCommand(lower)
                        } else if lower == "list" || lower.starts(with: "list ") {
                            reminderText = transformed
                            handleListCommand()
                        } else {
                            // Regular reminder — auto-approve or show preview
                            let data = PendingReminderData(
                                originalText: capturedText,
                                transformedText: transformed,
                                contact: capturedContact,
                                location: capturedLocation,
                                locationProximity: capturedProximity,
                                notes: capturedNotes,
                                isUrgent: capturedUrgent,
                                overriddenRanges: capturedOverriddenRanges
                            )
                            if colorTheme.aiAutoApprove {
                                pendingReminderData = data
                                confirmAIReminder()
                            } else {
                                pendingReminderData = data
                                aiTransformPreview = transformed
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        reminderText = capturedText
                        selectedContact = capturedContact
                        selectedLocation = capturedLocation
                        locationProximity = capturedProximity
                        notesText = capturedNotes ?? ""
                        isUrgent = capturedUrgent
                        overriddenRanges = capturedOverriddenRanges
                        isAIProcessing = false
                        animationManager.showError(error.localizedDescription)
                    }
                }
            }
            return
        }

        let text = reminderText.lowercased()

        // Check if the command keyword at the start is overridden (user toggled it to literal text)
        let commandKeywordOverridden = overriddenRanges.contains { range in
            range.location == 0
        }

        // Only check for commands if the command keyword is NOT overridden
        if !commandKeywordOverridden {
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
        }
        
        // Regular reminder creation
        isProcessing = true
        let textToProcess = reminderText
        let contactToAdd = selectedContact
        let locationToAdd = selectedLocation
        let notesToAdd = notesText.isEmpty ? nil : notesText
        let isUrgentToAdd = isUrgent
        let overriddenRangesToProcess = overriddenRanges  // Capture overridden ranges

        reminderText = ""
        overriddenRanges.removeAll()  // Clear toggled-off words
        isEditingVariables = false  // Exit edit mode
        selectedContact = nil
        selectedLocation = nil
        locationProximity = .enter  // Reset proximity
        notesText = ""
        showNotesField = false
        isUrgent = false  // Reset urgent state
        isTextFieldFocused = false // Dismiss keyboard after manual reminder creation
        // Force dismiss keyboard using UIKit
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        Task {
            do {
                // CRITICAL: Replace underlined words with "XXX" for parsing!
                // This prevents them from being parsed as dates/times while keeping the structure
                var textForParsing = textToProcess
                if !overriddenRangesToProcess.isEmpty {
                    let nsText = textToProcess as NSString

                    // Sort ranges in reverse order to replace from end to start (preserves earlier ranges)
                    let sortedRanges = overriddenRangesToProcess.sorted { $0.location > $1.location }

                    for range in sortedRanges {
                        if range.location >= 0 && range.location + range.length <= nsText.length {
                            let originalWord = nsText.substring(with: range)

                            // DON'T replace recurrence keywords! They're critical for parsing
                            let lowercased = originalWord.lowercased()
                            if lowercased.contains("every") ||
                               lowercased == "day" || lowercased == "days" ||
                               lowercased == "week" || lowercased == "weeks" ||
                               lowercased == "month" || lowercased == "months" {
                                continue  // Don't replace recurrence keywords!
                            }

                            // Replace non-recurrence underlined words with "XXX" (won't be parsed)
                            if let swiftRange = Range(range, in: textForParsing) {
                                textForParsing.replaceSubrange(swiftRange, with: "XXX")
                            }
                        }
                    }
                }

                // Parse the MODIFIED text (underlined words replaced with "XXX")
                var parsedReminder = reminderManager.nlParser.parseReminderText(textForParsing)

                // Clean up the title: Use original text but remove ONLY parsed (non-underlined) dates/times
                // Start with the parsed title (which has dates/times removed)
                var cleanTitle = parsedReminder.title

                // Replace "XXX" placeholders back with the original underlined words
                // (excluding recurrence keywords which were never replaced)
                if !overriddenRangesToProcess.isEmpty {
                    let nsText = textToProcess as NSString

                    // Get underlined words in order
                    let sortedRanges = overriddenRangesToProcess.sorted { $0.location < $1.location }

                    for range in sortedRanges {
                        if range.location >= 0 && range.location + range.length <= nsText.length {
                            let originalWord = nsText.substring(with: range)

                            // Skip recurrence keywords (they were never replaced, so no "XXX" to restore)
                            let lowercased = originalWord.lowercased()
                            if lowercased.contains("every") ||
                               lowercased == "day" || lowercased == "days" ||
                               lowercased == "week" || lowercased == "weeks" ||
                               lowercased == "month" || lowercased == "months" {
                                continue
                            }

                            // Replace first occurrence of "XXX" with the original underlined word
                            if let xxxRange = cleanTitle.range(of: "XXX") {
                                 cleanTitle.replaceSubrange(xxxRange, with: originalWord)
                            }
                        }
                    }
                }

                // Clean up any extra spaces
                cleanTitle = cleanTitle.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)

                // Update parsedReminder with the cleaned title
                parsedReminder = SharedParsedReminder(
                    title: cleanTitle,  // Use cleaned title with underlined words restored!
                    dueDate: parsedReminder.dueDate,
                    isRecurring: parsedReminder.isRecurring,
                    recurrenceInterval: parsedReminder.recurrenceInterval,
                    recurrenceFrequency: parsedReminder.recurrenceFrequency,
                    recurrenceEndDate: parsedReminder.recurrenceEndDate,
                    isValid: parsedReminder.isValid,
                    errorMessage: parsedReminder.errorMessage,
                    contactName: parsedReminder.contactName,
                    contactIdentifier: parsedReminder.contactIdentifier,
                    locationName: parsedReminder.locationName,
                    locationAddress: parsedReminder.locationAddress,
                    locationCoordinates: parsedReminder.locationCoordinates,
                    locationProximity: parsedReminder.locationProximity,
                    isUrgent: parsedReminder.isUrgent,
                    alarmOffset: parsedReminder.alarmOffset,
                    notes: parsedReminder.notes,
                    parsedVariables: parsedReminder.parsedVariables
                )

                // Override with button states (buttons take precedence over NLP!)
                let finalProximity = locationToAdd != nil ? locationProximity : parsedReminder.locationProximity

                parsedReminder = SharedParsedReminder(
                    title: parsedReminder.title,
                    dueDate: parsedReminder.dueDate,
                    isRecurring: parsedReminder.isRecurring,
                    recurrenceInterval: parsedReminder.recurrenceInterval,
                    recurrenceFrequency: parsedReminder.recurrenceFrequency,
                    recurrenceEndDate: parsedReminder.recurrenceEndDate,
                    isValid: parsedReminder.isValid,
                    errorMessage: parsedReminder.errorMessage,
                    contactName: parsedReminder.contactName,
                    contactIdentifier: parsedReminder.contactIdentifier,
                    locationName: parsedReminder.locationName,
                    locationAddress: parsedReminder.locationAddress,
                    locationCoordinates: parsedReminder.locationCoordinates,
                    locationProximity: finalProximity,  // Use picker proximity if location selected!
                    isUrgent: isUrgentToAdd,  // Use button state!
                    alarmOffset: parsedReminder.alarmOffset,
                    notes: parsedReminder.notes,
                    parsedVariables: parsedReminder.parsedVariables
                )

                // Create reminder with all new features
                try await reminderManager.createReminder(
                    from: parsedReminder,
                    selectedContact: contactToAdd,
                    selectedLocation: locationToAdd,
                    additionalNotes: notesToAdd
                )

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

    // MARK: - AI Mode Helpers

    private func callGemini(input: String) async throws -> String {
        switch colorTheme.aiProvider {
        case .gemini:
            return try await GeminiService.shared.transformText(input, apiKey: colorTheme.geminiApiKey, model: colorTheme.geminiModel)
        case .groq:
            return try await GroqService.shared.transformText(input, apiKey: colorTheme.groqApiKey, model: colorTheme.groqModel)
        case .custom:
            return try await CustomAPIService.shared.transformText(
                input,
                baseURL: colorTheme.customApiUrl,
                model: colorTheme.customApiModel,
                apiKey: colorTheme.customApiKey
            )
        }
    }

    private func confirmAIReminder() {
        guard let data = pendingReminderData else { return }
        aiTransformPreview = nil
        pendingReminderData = nil

        isProcessing = true
        let textToProcess = data.transformedText
        let contactToAdd = data.contact
        let locationToAdd = data.location
        let notesToAdd = data.notes
        let isUrgentToAdd = data.isUrgent
        let overriddenRangesToProcess = data.overriddenRanges

        Task {
            do {
                var textForParsing = textToProcess
                if !overriddenRangesToProcess.isEmpty {
                    let nsText = textToProcess as NSString
                    let sortedRanges = overriddenRangesToProcess.sorted { $0.location > $1.location }
                    for range in sortedRanges {
                        if range.location >= 0 && range.location + range.length <= nsText.length {
                            let originalWord = nsText.substring(with: range)
                            let lowercased = originalWord.lowercased()
                            if lowercased.contains("every") ||
                               lowercased == "day" || lowercased == "days" ||
                               lowercased == "week" || lowercased == "weeks" ||
                               lowercased == "month" || lowercased == "months" {
                                continue
                            }
                            if let swiftRange = Range(range, in: textForParsing) {
                                textForParsing.replaceSubrange(swiftRange, with: "XXX")
                            }
                        }
                    }
                }

                var parsedReminder = reminderManager.nlParser.parseReminderText(textForParsing)
                var cleanTitle = parsedReminder.title

                if !overriddenRangesToProcess.isEmpty {
                    let nsText = textToProcess as NSString
                    let sortedRanges = overriddenRangesToProcess.sorted { $0.location < $1.location }
                    for range in sortedRanges {
                        if range.location >= 0 && range.location + range.length <= nsText.length {
                            let originalWord = nsText.substring(with: range)
                            let lowercased = originalWord.lowercased()
                            if lowercased.contains("every") ||
                               lowercased == "day" || lowercased == "days" ||
                               lowercased == "week" || lowercased == "weeks" ||
                               lowercased == "month" || lowercased == "months" {
                                continue
                            }
                            if let xxxRange = cleanTitle.range(of: "XXX") {
                                cleanTitle.replaceSubrange(xxxRange, with: originalWord)
                            }
                        }
                    }
                }

                cleanTitle = cleanTitle.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)

                parsedReminder = SharedParsedReminder(
                    title: cleanTitle,
                    dueDate: parsedReminder.dueDate,
                    isRecurring: parsedReminder.isRecurring,
                    recurrenceInterval: parsedReminder.recurrenceInterval,
                    recurrenceFrequency: parsedReminder.recurrenceFrequency,
                    recurrenceEndDate: parsedReminder.recurrenceEndDate,
                    isValid: parsedReminder.isValid,
                    errorMessage: parsedReminder.errorMessage,
                    contactName: parsedReminder.contactName,
                    contactIdentifier: parsedReminder.contactIdentifier,
                    locationName: parsedReminder.locationName,
                    locationAddress: parsedReminder.locationAddress,
                    locationCoordinates: parsedReminder.locationCoordinates,
                    locationProximity: locationToAdd != nil ? data.locationProximity : parsedReminder.locationProximity,
                    isUrgent: isUrgentToAdd,
                    alarmOffset: parsedReminder.alarmOffset,
                    notes: parsedReminder.notes,
                    parsedVariables: parsedReminder.parsedVariables
                )

                try await reminderManager.createReminder(
                    from: parsedReminder,
                    selectedContact: contactToAdd,
                    selectedLocation: locationToAdd,
                    additionalNotes: notesToAdd
                )

                await MainActor.run {
                    isProcessing = false
                    onTriggerAnimation(true)
                    if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    onTriggerAnimation(false)
                    if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil {
                        let notification = UINotificationFeedbackGenerator()
                        notification.notificationOccurred(.error)
                    }
                }
            }
        }
    }

    private func cancelAIReminder() {
        guard let data = pendingReminderData else {
            aiTransformPreview = nil
            return
        }
        reminderText = data.originalText
        selectedContact = data.contact
        selectedLocation = data.location
        locationProximity = data.locationProximity
        notesText = data.notes ?? ""
        isUrgent = data.isUrgent
        overriddenRanges = data.overriddenRanges
        aiTransformPreview = nil
        pendingReminderData = nil
    }

    // MARK: - NEW: Helper Methods for Feature Integration

    private func updateParsedVariables(_ text: String) {
        // Clear variables if text is empty
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            parsedVariables = []
            return
        }

        // Extract variables using the dedicated extraction function
        parsedVariables = reminderManager.nlParser.extractVariables(from: text)
    }

    private func toggleVariable(at index: Int) {
        guard index < parsedVariables.count else { return }
        parsedVariables[index].isOverriddenAsText.toggle()
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

        // Check if using Google provider
        if colorTheme.selectedProvider == "Google (Tasks + Calendar)" && GoogleAuthManager.shared.isSignedIn {
            handleGoogleListCommand(originalText: originalText, filter: filter)
        } else {
            handleAppleListCommand(originalText: originalText, filter: filter)
        }
    }

    private func handleAppleListCommand(originalText: String, filter: String) {
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

                withAnimation(self.colorTheme.animationsEnabled ? .spring(response: 0.6, dampingFraction: 0.8) : .none) {
                    self.insideWindowState = .showingList(filteredReminders)
                }
            }
        }
    }

    private func handleGoogleListCommand(originalText: String, filter: String) {
        Task {
            do {
                let allReminders = try await reminderManager.getAllGoogleReminders()
                let filteredReminders: [UniversalReminder]

                // Check if filter matches a Google list name first
                let listMatch = reminderManager.googleLists.first { list in
                    list.name.lowercased() == filter.lowercased()
                }
                let calendarMatch = reminderManager.googleCalendars.first { cal in
                    cal.name.lowercased() == filter.lowercased()
                }

                if let targetList = listMatch {
                    filteredReminders = allReminders.filter { $0.listId == targetList.id && !$0.isCompleted }
                } else if let targetCal = calendarMatch {
                    filteredReminders = allReminders.filter { $0.listId == targetCal.id && !$0.isCompleted }
                } else {
                    // Filter by date/time
                    filteredReminders = self.filterGoogleRemindersByDate(allReminders, command: originalText)
                }

                await MainActor.run {
                    withAnimation(self.colorTheme.animationsEnabled ? .spring(response: 0.6, dampingFraction: 0.8) : .none) {
                        self.insideWindowState = .showingGoogleList(filteredReminders)
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(self.colorTheme.animationsEnabled ? .spring(response: 0.6, dampingFraction: 0.8) : .none) {
                        self.insideWindowState = .showingGoogleList([])
                    }
                }
            }
        }
    }

    private func filterGoogleRemindersByDate(_ reminders: [UniversalReminder], command: String) -> [UniversalReminder] {
        let calendar = Calendar.current
        let targetDate = parseDateFromCommandKeyboardStyle(command)

        if let date = targetDate {
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDate else { return false }
                return calendar.isDate(dueDate, inSameDayAs: date)
            }
        } else if command.lowercased().contains("week") || command.lowercased().contains("month") {
            return filterGoogleRemindersForPeriod(reminders, command: command)
        } else {
            // No specific date filter - return all non-completed reminders
            return reminders.filter { !$0.isCompleted }
        }
    }

    private func filterGoogleRemindersForPeriod(_ reminders: [UniversalReminder], command: String) -> [UniversalReminder] {
        let calendar = Calendar.current
        let today = Date()
        let lowercaseCommand = command.lowercased()

        if lowercaseCommand.contains("this week") {
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDate else { return false }
                return weekInterval.contains(dueDate)
            }
        } else if lowercaseCommand.contains("next week") {
            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: today),
                  let weekInterval = calendar.dateInterval(of: .weekOfYear, for: nextWeek) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDate else { return false }
                return weekInterval.contains(dueDate)
            }
        } else if lowercaseCommand.contains("this month") {
            guard let monthInterval = calendar.dateInterval(of: .month, for: today) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDate else { return false }
                return monthInterval.contains(dueDate)
            }
        } else if lowercaseCommand.contains("next month") {
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: today),
                  let monthInterval = calendar.dateInterval(of: .month, for: nextMonth) else { return [] }
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDate else { return false }
                return monthInterval.contains(dueDate)
            }
        }
        return reminders.filter { !$0.isCompleted }
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
        isTextFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        // Trigger SUCCESS animation for delete command
        onTriggerAnimation(true)

        // Check if using Google
        if colorTheme.selectedProvider == "Google (Tasks + Calendar)" && GoogleAuthManager.shared.isSignedIn {
            handleGoogleDelete(title: titleToDelete)
        } else {
            handleAppleDelete(title: titleToDelete)
        }
    }

    private func handleAppleDelete(title: String) {
        let searchCallback: ([EKReminder]) -> Void = { allReminders in
            let filteredReminders: [EKReminder]
            if self.colorTheme.searchInSelectedListOnly, let selectedList = self.reminderManager.selectedList {
                filteredReminders = allReminders.filter { $0.calendar?.calendarIdentifier == selectedList.calendarIdentifier }
            } else {
                filteredReminders = allReminders
            }

            DispatchQueue.main.async {
                if filteredReminders.count > 1 {
                    let deleteAction = { (selectedReminder: EKReminder) in
                        self.reminderManager.deleteReminder(selectedReminder) { success, error in
                            // Silent deletion
                        }
                    }
                    withAnimation(self.colorTheme.animationsEnabled ? .spring(response: 0.6, dampingFraction: 0.8) : .none) {
                        self.insideWindowState = .showingDuplicates(filteredReminders, deleteAction)
                    }
                } else if let reminderToDelete = filteredReminders.first {
                    self.reminderManager.deleteReminder(reminderToDelete) { success, error in
                        // Silent deletion
                    }
                }
            }
        }

        reminderManager.findReminder(withTitle: title, completion: searchCallback)
    }

    private func handleGoogleDelete(title: String) {
        Task {
            do {
                let matchingReminders = try await reminderManager.findGoogleReminder(withTitle: title, allowDuplicates: true)

                await MainActor.run {
                    if matchingReminders.count > 1 {
                        // Show duplicate selection UI for Google reminders
                        let deleteAction = { (selectedReminder: UniversalReminder) in
                            _ = Task {
                                try? await self.reminderManager.deleteGoogleReminder(selectedReminder)
                            }
                        }
                        withAnimation(self.colorTheme.animationsEnabled ? .spring(response: 0.6, dampingFraction: 0.8) : .none) {
                            self.insideWindowState = .showingGoogleDuplicates(matchingReminders, deleteAction)
                        }
                    } else if let reminderToDelete = matchingReminders.first {
                        Task {
                            try? await self.reminderManager.deleteGoogleReminder(reminderToDelete)
                        }
                    }
                }
            } catch {
                // Silently handle error
            }
        }
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
        isTextFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        // Parse the new date
        let parsedReminder = reminderManager.nlParser.parseReminderText("dummy " + newDateText)
        guard let newDate = parsedReminder.dueDate else {
            // Trigger ERROR animation for invalid date
            onTriggerAnimation(false)
            return
        }

        // Trigger SUCCESS animation for move command
        onTriggerAnimation(true)

        // Check if using Google
        if colorTheme.selectedProvider == "Google (Tasks + Calendar)" && GoogleAuthManager.shared.isSignedIn {
            handleGoogleMove(title: titleToMove, newDate: newDate)
        } else {
            handleAppleMove(title: titleToMove, newDate: newDate)
        }
    }

    private func handleAppleMove(title: String, newDate: Date) {
        let moveSearchCallback: ([EKReminder]) -> Void = { allReminders in
            let filteredReminders: [EKReminder]
            if self.colorTheme.searchInSelectedListOnly, let selectedList = self.reminderManager.selectedList {
                filteredReminders = allReminders.filter { $0.calendar?.calendarIdentifier == selectedList.calendarIdentifier }
            } else {
                filteredReminders = allReminders
            }

            DispatchQueue.main.async {
                if filteredReminders.count > 1 {
                    let moveAction = { (selectedReminder: EKReminder) in
                        self.reminderManager.moveReminder(selectedReminder, to: newDate) { success, error in
                            // Silent move
                        }
                    }
                    withAnimation(self.colorTheme.animationsEnabled ? .spring(response: 0.6, dampingFraction: 0.8) : .none) {
                        self.insideWindowState = .showingDuplicates(filteredReminders, moveAction)
                    }
                } else if let reminderToMove = filteredReminders.first {
                    self.reminderManager.moveReminder(reminderToMove, to: newDate) { success, error in
                        // Silent move
                    }
                }
            }
        }

        reminderManager.findReminder(withTitle: title, completion: moveSearchCallback)
    }

    private func handleGoogleMove(title: String, newDate: Date) {
        Task {
            do {
                let matchingReminders = try await reminderManager.findGoogleReminder(withTitle: title, allowDuplicates: true)

                await MainActor.run {
                    if matchingReminders.count > 1 {
                        // Show duplicate selection UI for Google reminders
                        let moveAction = { (selectedReminder: UniversalReminder) in
                            _ = Task {
                                try? await self.reminderManager.moveGoogleReminder(selectedReminder, to: newDate)
                            }
                        }
                        withAnimation(self.colorTheme.animationsEnabled ? .spring(response: 0.6, dampingFraction: 0.8) : .none) {
                            self.insideWindowState = .showingGoogleDuplicates(matchingReminders, moveAction)
                        }
                    } else if let reminderToMove = matchingReminders.first {
                        Task {
                            try? await self.reminderManager.moveGoogleReminder(reminderToMove, to: newDate)
                        }
                    }
                }
            } catch {
                // Silently handle error
            }
        }
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

    private var isUsingGoogle: Bool {
        return colorTheme.selectedProvider == "Google (Tasks + Calendar)" && GoogleAuthManager.shared.isSignedIn
    }

    var body: some View {
        NavigationView {
            List {
                if isUsingGoogle {
                    // SECTION: Google Tasks Lists
                    Section(header: Text("Google Tasks Lists").font(.caption).foregroundColor(.secondary)) {
                        ForEach(reminderManager.googleLists, id: \.id) { list in
                            Button(action: {
                                reminderManager.setSelectedGoogleList(listId: list.id)
                                isPresented = false
                            }) {
                                HStack {
                                    Image(systemName: "checklist")
                                        .foregroundColor(.blue)
                                        .frame(width: 20)

                                    Text(list.name)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    if list.id == reminderManager.selectedGoogleListId {
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

                    // SECTION: Google Calendars
                    Section(header: Text("Google Calendars").font(.caption).foregroundColor(.secondary)) {
                        ForEach(reminderManager.googleCalendars, id: \.id) { calendar in
                            Button(action: {
                                reminderManager.setSelectedGoogleCalendar(calendarId: calendar.id)
                                isPresented = false
                            }) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.orange)
                                        .frame(width: 20)

                                    Text(calendar.name)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    if calendar.id == reminderManager.selectedGoogleCalendarId {
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
                } else {
                    // Show Apple Reminders lists
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
            
            // Show recurring indicator under the time (like native Reminders)
            if let recurrenceRules = reminder.recurrenceRules, !recurrenceRules.isEmpty,
               let rule = recurrenceRules.first {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(perfectIOSRecurrenceText(from: rule))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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

// MARK: - Google Reminders Display View

struct GoogleRemindersDisplayView: View {
    let reminders: [UniversalReminder]
    let onDismiss: () -> Void

    private var groupedReminders: [String: [UniversalReminder]] {
        Dictionary(grouping: reminders) { $0.listName ?? "Unknown" }
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
                            HStack {
                                Image(systemName: listReminders.first?.storageType == .googleCalendar ? "calendar" : "checklist")
                                    .foregroundColor(.blue)
                                    .font(.caption)

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

                            ForEach(listReminders) { reminder in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("• \(reminder.title)")
                                        .font(.body)
                                        .foregroundColor(.primary)

                                    if let dueDate = reminder.dueDate {
                                        Text("Due: \(formatDate(dueDate))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    if reminder.isRecurring {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.caption2)
                                            Text("Recurring")
                                                .font(.caption2)
                                        }
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Google Duplicate Reminders View

struct GoogleDuplicateRemindersView: View {
    let reminders: [UniversalReminder]
    let onSelect: (UniversalReminder) -> Void
    let onDismiss: () -> Void

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
                    ForEach(reminders) { reminder in
                        Button(action: { onSelect(reminder) }) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(reminder.title)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.primary)

                                HStack(spacing: 8) {
                                    if let dueDate = reminder.dueDate {
                                        Text("Due: \(formatDate(dueDate))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Text(reminder.storageType == .googleCalendar ? "Calendar" : "Tasks")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                        .foregroundColor(.blue)

                                    if let listName = reminder.listName {
                                        Text(listName)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                if reminder.isRecurring {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption2)
                                        Text("Recurring")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
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

    private func formatDate(_ date: Date) -> String {
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

// MARK: - Helper Functions

private func perfectIOSRecurrenceText(from rule: EKRecurrenceRule) -> String {
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

/// MARK: - AI Mode Supporting Types

private struct PendingReminderData {
    let originalText: String
    let transformedText: String
    let contact: CNContact?
    let location: MKMapItem?
    let locationProximity: EKAlarmProximity
    let notes: String?
    let isUrgent: Bool
    let overriddenRanges: [NSRange]
}

private struct AIPreviewSheet: View {
    let originalText: String
    let transformedText: String
    let accentColor: Color
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Original", systemImage: "text.bubble")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(originalText)
                        .font(.body)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("AI transformed to", systemImage: "wand.and.stars")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(accentColor)
                    Text(transformedText)
                        .font(.body.weight(.medium))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(accentColor.opacity(0.3), lineWidth: 1)
                        )
                }

                Spacer()

                HStack(spacing: 16) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .foregroundColor(.primary)

                    Button(action: onConfirm) {
                        Text("Create")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(accentColor, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .foregroundColor(.white)
                }
            }
            .padding(24)
            .navigationTitle("AI Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

#endif
