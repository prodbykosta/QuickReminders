import SwiftUI
import AppKit
import EventKit
import Combine
import Speech
import AVFoundation

enum InsideWindowState {
    case hidden
    case showingList
    case showingDuplicates
}

// Structure to hold pending commands that require duplicate selection
struct PendingCommand {
    let type: CommandType
    let query: String
    let targetDate: Date?
    let targetList: EKCalendar?
    let isRecurring: Bool
    let recurrenceInterval: Int?
    let recurrenceFrequency: EKRecurrenceFrequency?
    let recurrenceEndDate: Date?
    
    enum CommandType {
        case remove
        case move
    }
}

// Window delegate for handling Spotlight-like behavior
class FloatingWindowDelegate: NSObject, NSWindowDelegate {
    weak var windowManager: FloatingWindowManager?
    private var hasDeactivated = false
    var deactivationTimer: DispatchWorkItem?
    
    init(windowManager: FloatingWindowManager) {
        self.windowManager = windowManager
        super.init()
    }
    
    deinit {
        // Cancel any pending timer to prevent crashes
        deactivationTimer?.cancel()
        deactivationTimer = nil
        // Window delegate cleanup
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // When window loses focus, trigger deactivation like Spotlight
        // Only do this once to prevent multiple calls
        guard !hasDeactivated else { return }
        hasDeactivated = true
        
        // Cancel any existing timer
        deactivationTimer?.cancel()
        
        // Create a new timer that can be cancelled
        let workItem = DispatchWorkItem { [weak self] in
            guard let _ = self else { return }
            NotificationCenter.default.post(name: .shouldDeactivateApp, object: nil)
        }
        
        deactivationTimer = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Cancel any pending timer
        deactivationTimer?.cancel()
        deactivationTimer = nil
        
        // Don't trigger deactivation here if already done
        if !hasDeactivated {
            hasDeactivated = true
            NotificationCenter.default.post(name: .shouldDeactivateApp, object: nil)
        }
        return true
    }
}

// Custom window class that can become key and main for floating windows
class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}

// Custom TextField that works properly in floating windows and automatically focuses
struct FocusableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var colorHelpersEnabled: Bool
    var shortcutsEnabled: Bool
    var timePeriodsEnabled: Bool
    
    func makeNSView(context: Context) -> HighlightedTextField {
        let textField = HighlightedTextField()
        textField.stringValue = text
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.textFieldAction(_:))
        textField.colorHelpersEnabled = colorHelpersEnabled
        textField.shortcutsEnabled = shortcutsEnabled
        textField.timePeriodsEnabled = timePeriodsEnabled
        
        // Auto-focus after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            textField.window?.makeFirstResponder(textField)
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: HighlightedTextField, context: Context) {
        // Update settings first
        nsView.setColorHelpersEnabled(colorHelpersEnabled)
        nsView.setShortcutsEnabled(shortcutsEnabled)
        nsView.setTimePeriodsEnabled(timePeriodsEnabled)
        
        // Only update text if it's different to avoid cursor jumping
        if nsView.stringValue != text {
            nsView.updateText(text)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: FocusableTextField
        
        init(_ parent: FocusableTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? HighlightedTextField {
                let newText = textField.stringValue
                
                DispatchQueue.main.async {
                    self.parent.text = newText
                }
            }
        }
        
        @objc func textFieldAction(_ sender: NSTextField) {
            parent.onSubmit()
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

class FloatingWindowManager: ObservableObject {
    private var floatingWindow: NSWindow?
    private var reminderManager: ReminderManager?
    private var colorTheme: ColorThemeManager?
    private var speechManager: SpeechManager?
    private var windowDelegate: FloatingWindowDelegate?
    private var isCleaningUp = false
    
    var isWindowVisible: Bool {
        return floatingWindow?.isVisible == true
    }
    
    deinit {
        cleanupExistingWindow()
    }
    
    func showFloatingWindow() {
        // Close existing window if any
        cleanupExistingWindow()
        
        // Create new window
        createFloatingWindow()
        
        guard let window = floatingWindow else { 
            // Failed to create floating window
            return 
        }
        
        // Position based on user settings
        if let screen = NSScreen.main {
            let windowSize = NSSize(width: 600, height: 140)
            let windowFrame: NSRect
            
            if colorTheme?.windowPosition == .custom {
                // Use custom X/Y sliders
                windowFrame = calculateCustomWindowPosition(
                    screenFrame: screen.frame,
                    windowSize: windowSize,
                    x: colorTheme?.windowPositionX ?? 0.5,
                    y: colorTheme?.windowPositionY ?? 0.5
                )
            } else {
                // Use preset position
                windowFrame = calculateWindowPosition(
                    screenFrame: screen.frame,
                    windowSize: windowSize,
                    position: colorTheme?.windowPosition ?? .center
                )
            }
            
            window.setFrame(windowFrame, display: true)
        }
        
        // Make window visible and focusable like Spotlight
        window.level = .popUpMenu // Higher level than floating
        window.orderFront(nil)
        window.makeKeyAndOrderFront(nil)
        
        // Force app activation and window focus
        NSApp.activate(ignoringOtherApps: true)
        window.makeKey()
        window.makeMain()
        
        // Window delegate already configured in createFloatingWindow()
        
        // Multiple focus attempts for reliable focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeFirstResponder(window.contentView)
        }
        
        // Window shown and ready
    }
    
    func hideFloatingWindow() {
        cleanupExistingWindow()
    }
    
    func cleanupExistingWindow() {
        // Prevent multiple cleanup calls
        guard !isCleaningUp else { 
            // Cleanup already in progress
            return 
        }
        
        guard let window = floatingWindow else { 
            // No window to cleanup
            // Still reset references just in case
            windowDelegate = nil
            isCleaningUp = false
            return 
        }
        
        isCleaningUp = true
        // Starting window cleanup
        
        // Cancel any pending delegate timers first
        if let delegate = windowDelegate {
            delegate.deactivationTimer?.cancel()
            delegate.deactivationTimer = nil
        }
        
        // Remove delegate first to prevent callbacks during cleanup
        window.delegate = nil
        
        // Remove all observers and cleanup content safely
        if let contentView = window.contentView {
            contentView.removeFromSuperview()
        }
        
        // Force close the window
        window.orderOut(nil)
        window.close()
        
        // Clear all references thoroughly
        floatingWindow = nil
        windowDelegate = nil
        
        // Reset cleanup flag
        isCleaningUp = false
        
        // Window cleanup completed
    }
    
    func setReminderManager(_ manager: ReminderManager) {
        reminderManager = manager
    }
    
    func setColorTheme(_ theme: ColorThemeManager) {
        colorTheme = theme
        // Note: ReminderManager's colorTheme is immutable (set in init), so we don't update it here
    }
    
    func setSpeechManager(_ manager: SpeechManager) {
        speechManager = manager
    }
    
    private func createFloatingWindow() {
        floatingWindow = FloatingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 140),
            styleMask: [.borderless, .resizable], // Borderless like Spotlight but resizable
            backing: .buffered,
            defer: false
        )
        
        guard let window = floatingWindow else { return }
        
        window.title = ""
        window.level = .popUpMenu
        window.backgroundColor = NSColor.clear
        window.isOpaque = false
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = false // Don't allow moving like Spotlight
        window.isReleasedWhenClosed = false // Like Snap - prevents premature deallocation
        
        
        // Set up the window delegate for Spotlight-like behavior
        windowDelegate = FloatingWindowDelegate(windowManager: self)
        window.delegate = windowDelegate
        
        // Create the Spotlight-like content view
        let contentView = NSHostingView(rootView: FloatingReminderView(
            reminderManager: reminderManager ?? ReminderManager(colorTheme: ColorThemeManager()),
            colorTheme: colorTheme ?? ColorThemeManager(),
            speechManager: speechManager ?? SpeechManager(),
            onClose: { [weak self] in
                self?.hideFloatingWindow()
            }
        ))
        
        window.contentView = contentView
        
        // Make window frame corners rounded to match content (apply after setting content view)
        if #available(macOS 11.0, *) {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 16
            contentView.layer?.masksToBounds = true
        }
        
        // Make sure the window can receive keyboard events
        window.acceptsMouseMovedEvents = true
        
        // Created borderless window
    }
    
    private func calculateWindowPosition(screenFrame: NSRect, windowSize: NSSize, position: WindowPosition) -> NSRect {
        let margin: CGFloat = 50 // Distance from screen edges
        
        var x: CGFloat
        var y: CGFloat
        
        // Calculate X position
        switch position {
        case .topLeft, .centerLeft, .bottomLeft:
            x = screenFrame.minX + margin
        case .topCenter, .center, .bottomCenter:
            x = screenFrame.midX - windowSize.width / 2
        case .topRight, .centerRight, .bottomRight:
            x = screenFrame.maxX - windowSize.width - margin
        case .custom:
            x = screenFrame.midX - windowSize.width / 2 // Default to center for custom
        }
        
        // Calculate Y position (remember: macOS coordinate system has origin at bottom-left)
        switch position {
        case .topLeft, .topCenter, .topRight:
            y = screenFrame.maxY - windowSize.height - margin
        case .centerLeft, .center, .centerRight:
            y = screenFrame.midY - windowSize.height / 2
        case .bottomLeft, .bottomCenter, .bottomRight:
            y = screenFrame.minY + margin
        case .custom:
            y = screenFrame.midY - windowSize.height / 2 // Default to center for custom
        }
        
        return NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height)
    }
    
    private func calculateCustomWindowPosition(screenFrame: NSRect, windowSize: NSSize, x: Double, y: Double) -> NSRect {
        let margin: CGFloat = 50 // Minimum distance from screen edges
        
        // Calculate available positioning area (screen minus margins and window size)
        let availableWidth = screenFrame.width - (2 * margin) - windowSize.width
        let availableHeight = screenFrame.height - (2 * margin) - windowSize.height
        
        // Convert normalized position (0.0-1.0) to actual coordinates
        let actualX = screenFrame.minX + margin + (availableWidth * CGFloat(x))
        let actualY = screenFrame.minY + margin + (availableHeight * CGFloat(y))
        
        return NSRect(x: actualX, y: actualY, width: windowSize.width, height: windowSize.height)
    }
    
    // MARK: - Voice Activation Support
    
    // Public method for voice activation via hotkey
    func toggleVoiceRecognition() {
        // We need to trigger voice recognition on the view
        // Since this is called from the app level, we need to handle this differently
        // We'll post a notification that the view can listen to
        NotificationCenter.default.post(name: .voiceActivationRequested, object: nil)
    }
}

struct FloatingReminderView: View {
    @ObservedObject var reminderManager: ReminderManager
    @ObservedObject var colorTheme: ColorThemeManager
    @ObservedObject var speechManager: SpeechManager
    @State private var reminderText = ""
    @State private var statusMessage = ""
    @State private var isSuccess = false
    @State private var isProcessing = false
    @State private var currentTimer: DispatchWorkItem?
    @State private var backgroundFlashColor: Color = .clear
    @State private var showFlash = false
    @State private var glowAnimation = false
    @State private var glowStops: [Gradient.Stop] = []
    @State private var buttonScale: CGFloat = 1.0
    @State private var buttonPressed = false
    @State private var permanentGlow = true // Always show glow with list color
    @State private var showListPicker = false
    @State private var windowAppearAnimation = false // For sexy opening animation
    @State private var insideWindowState: InsideWindowState = .hidden // Mutually exclusive window state
    @State private var listFilter = "" // Filter for list display (today, scheduled, etc.)
    @State private var currentListColor: Color? = nil // Track current list color for persistence
    @State private var duplicateReminders: [EKReminder] = [] // Reminders with duplicate names
    @State private var pendingCommand: PendingCommand? = nil // Command waiting for duplicate selection
    @State private var baseWindowHeight: CGFloat = 140 // Base height for input only
    @State private var lastCommandTime: Date = Date() // Track last command time to prevent rapid commands
    @State private var isTransitioning = false // Prevent multiple simultaneous state transitions
    
    private var nlParser: NLParser
    let onClose: () -> Void
    
    init(reminderManager: ReminderManager, colorTheme: ColorThemeManager, speechManager: SpeechManager, onClose: @escaping () -> Void) {
        self.reminderManager = reminderManager
        self.colorTheme = colorTheme
        self.speechManager = speechManager
        self.nlParser = NLParser(colorTheme: colorTheme)
        self.onClose = onClose
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Spotlight-like input field with list selection
            HStack(spacing: 12) {
                Button(action: { showListPicker.toggle() }) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    colorTheme.primaryColor.opacity(0.9), 
                                    colorTheme.selectedListColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: colorTheme.selectedListColor.opacity(0.3), radius: 2, x: 0, y: 1)
                        .font(.system(size: 18, weight: .semibold))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showListPicker) {
                    ListPickerView(
                        reminderManager: reminderManager,
                        colorTheme: colorTheme,
                        onListSelected: { list in
                            // Safely update selected list
                            DispatchQueue.main.async {
                                reminderManager.selectedList = list
                                
                                // Safely update color theme
                                if let cgColor = list.cgColor {
                                    let listColor = Color(cgColor)
                                    colorTheme.updateSelectedListColor(listColor)
                                }
                                
                                // Save selected list for persistence
                                UserDefaults.standard.set(list.calendarIdentifier, forKey: "SelectedListIdentifier")
                                showListPicker = false
                                
                                
                                // Successfully selected list
                            }
                        }
                    )
                    .frame(width: 250, height: 200)
                }
                
                HStack(spacing: 8) {
                    FocusableTextField(
                        text: $reminderText,
                        placeholder: speechManager.isListening ? "Listening..." : "Type your reminder command...",
                        onSubmit: processCommand,
                        colorHelpersEnabled: colorTheme.colorHelpersEnabled,
                        shortcutsEnabled: colorTheme.shortcutsEnabled,
                        timePeriodsEnabled: colorTheme.timePeriodsEnabled
                    )
                    .font(.system(size: 16, weight: .medium))
                    .disabled(speechManager.isListening)
                    
                    // Microphone button - only show if both speech recognition and microphone permissions are granted
                    if speechPermissionsGranted() {
                        Button(action: toggleSpeechRecognition) {
                            Image(systemName: speechManager.isListening ? "mic.fill" : "mic")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(speechManager.isListening ? .red : (speechManager.errorMessage != nil ? .orange : .primary))
                                .background(
                                    Circle()
                                        .fill(speechManager.isListening ? Color.red.opacity(0.1) : Color.clear)
                                        .frame(width: 28, height: 28)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!speechManager.isAvailable)
                        .opacity(speechManager.isAvailable ? 1.0 : 0.5)
                        .help(speechManager.errorMessage ?? 
                              (speechManager.isAvailable ? 
                               (speechManager.isListening ? "Stop listening" : "Start voice recognition") : 
                               "Speech recognition not available"))
                    }
                }
                
                Group {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .progressViewStyle(CircularProgressViewStyle())
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.1).combined(with: .opacity),
                                removal: .scale(scale: 0.1).combined(with: .opacity)
                            ))
                    } else {
                        Button(action: {
                            guard !reminderText.isEmpty else { return }
                            
                            buttonPressed = true
                            
                            // Scale feedback animation
                            withAnimation(.easeOut(duration: 0.1)) {
                                buttonScale = 0.9
                            }
                            
                            // Reset scale and process command
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeOut(duration: 0.1)) {
                                    buttonScale = 1.0
                                }
                                processCommand()
                                buttonPressed = false
                            }
                        }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: reminderText.isEmpty ? 
                                        [colorTheme.primaryColor.opacity(0.5), colorTheme.selectedListColor.opacity(0.5)] :
                                        [colorTheme.primaryColor.opacity(0.9), colorTheme.selectedListColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .font(.system(size: 20))
                                .scaleEffect(buttonScale)
                                .opacity(1.0)
                                .brightness(buttonPressed ? -0.1 : 0)
                        }
                        .buttonStyle(.plain)
                        .disabled(!reminderManager.hasAccess || reminderText.isEmpty)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: isProcessing)
                .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: reminderText.isEmpty)
            }
            .frame(minHeight: 32) // Fixed height for input area to prevent jumping
            .padding(16)
            .background(
                ZStack {
                    // Ultra-transparent base - slightly darker
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                    
                    // Subtle highlight
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Liquid glass border
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                }
            )
            .overlay(
                ZStack {
                    // Permanent outer glow effect underneath (like success/error but with list color)
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(colorTheme.selectedListColor, lineWidth: 3)
                        .blur(radius: 8)
                        .opacity(0.4)
                    
                    // Permanent inner crisp glow (like success/error inner glow but with list color)
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(colorTheme.selectedListColor, lineWidth: 2)
                        .blur(radius: 4)
                        .opacity(0.3)
                    
                    // Permanent outer border glow (like success/error but always there)
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    colorTheme.selectedListColor.opacity(0.6),
                                    colorTheme.primaryColor.opacity(0.4),
                                    colorTheme.selectedListColor.opacity(0.5),
                                    colorTheme.primaryColor.opacity(0.3),
                                    colorTheme.selectedListColor.opacity(0.6)
                                ],
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            lineWidth: 3
                        )
                        .blur(radius: 8)
                        .opacity(0.4)
                    
                    // Permanent inner border glow (like success/error but always there)
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    colorTheme.selectedListColor.opacity(0.5),
                                    colorTheme.primaryColor.opacity(0.3),
                                    colorTheme.selectedListColor.opacity(0.4),
                                    colorTheme.primaryColor.opacity(0.2),
                                    colorTheme.selectedListColor.opacity(0.5)
                                ],
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            lineWidth: 2
                        )
                        .blur(radius: 4)
                        .opacity(0.3)

                    // Enhanced liquid glass border with gradient - more visible  
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [colorTheme.selectedListColor.opacity(0.7), colorTheme.primaryColor.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                    
                    // No extra animated border glows - we have permanent ones!
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            
            
            // Permission warning if needed
            if !reminderManager.hasAccess {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    Text("Reminders access required - Open Settings to grant permissions")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                .padding(.top, 8)
            }
            
            // Inside window content (list or duplicate selection)
            switch insideWindowState {
            case .hidden:
                EmptyView()
            case .showingList:
                RemindersListView(
                    reminderManager: reminderManager,
                    colorTheme: colorTheme,
                    filter: listFilter,
                    onClose: {
                        guard !isTransitioning else { return }
                        isTransitioning = true
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            insideWindowState = .hidden
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            resizeWindowForList(show: false)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            isTransitioning = false
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .padding(.top, 12)
            case .showingDuplicates:
                DuplicateSelectionView(
                    duplicateReminders: duplicateReminders,
                    pendingCommand: pendingCommand,
                    colorTheme: colorTheme,
                    onReminderSelected: { selectedReminder in
                        guard !isTransitioning else { return }
                        isTransitioning = true
                        
                        handleDuplicateSelection(selectedReminder)
                        
                        // Coordinate SwiftUI and window animations
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            insideWindowState = .hidden
                        }
                        
                        // Start window resize immediately with the view animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            resizeWindowForDuplicateSelection(show: false)
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isTransitioning = false
                        }
                    },
                    onCancel: {
                        guard !isTransitioning else { return }
                        isTransitioning = true
                        
                        // Coordinate SwiftUI and window animations
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            insideWindowState = .hidden
                        }
                        
                        // Start window resize immediately with the view animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            resizeWindowForDuplicateSelection(show: false)
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isTransitioning = false
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .padding(.top, 12)
            }
        }
        .frame(minHeight: 50) // Fixed minimum height to prevent jumping
        .padding(20)
        .background(
            ZStack {
                // Liquid glass base - darker and more transparent
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .opacity(0.45)
                
                // Darker frosted glass overlay
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.12),
                                Color.black.opacity(0.08),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Liquid glass highlight edge
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                
                // Permanent background glow with list color (subtle, always there)
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        RadialGradient(
                            colors: [
                                colorTheme.selectedListColor.opacity(0.15),
                                colorTheme.selectedListColor.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 200
                        )
                    )
                    .blur(radius: 25)
                    .opacity(0.6)

                // Permanent primary background glow with list color (subtle, always there)
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        AngularGradient(
                            colors: [
                                colorTheme.selectedListColor.opacity(0.15),
                                colorTheme.primaryColor.opacity(0.1),
                                colorTheme.selectedListColor.opacity(0.12),
                                colorTheme.primaryColor.opacity(0.08),
                                colorTheme.selectedListColor.opacity(0.15)
                            ],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        )
                    )
                    .blur(radius: 30)
                    .opacity(0.3)
                
                // Permanent secondary background glow with list color (subtle, always there)
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        AngularGradient(
                            colors: [
                                colorTheme.selectedListColor.opacity(0.12),
                                colorTheme.primaryColor.opacity(0.08),
                                colorTheme.selectedListColor.opacity(0.1),
                                colorTheme.primaryColor.opacity(0.06),
                                colorTheme.selectedListColor.opacity(0.12)
                            ],
                            center: .center,
                            startAngle: .degrees(180),
                            endAngle: .degrees(540)
                        )
                    )
                    .blur(radius: 20)
                    .opacity(0.2)

                // Apple Intelligence background glow animation - enhanced for liquid glass
                ZStack {
                    // Primary animated gradient background
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            AngularGradient(
                                stops: glowStops.isEmpty ? [Gradient.Stop(color: .clear, location: 0)] : glowStops,
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            )
                        )
                        .blur(radius: 30)
                        .rotationEffect(.degrees(glowAnimation ? 360 : 0))
                        .animation(.linear(duration: 3).repeatCount(1, autoreverses: false), value: glowAnimation)
                        .opacity(glowAnimation ? 0.6 : 0)
                        .animation(.easeInOut(duration: 0.6), value: glowAnimation)
                    
                    // Secondary flowing layer for liquid effect
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            AngularGradient(
                                stops: glowStops.isEmpty ? [Gradient.Stop(color: .clear, location: 0)] : glowStops,
                                center: .center,
                                startAngle: .degrees(180),
                                endAngle: .degrees(540)
                            )
                        )
                        .blur(radius: 20)
                        .rotationEffect(.degrees(glowAnimation ? -240 : 0))
                        .animation(.easeInOut(duration: 2.5).repeatCount(1, autoreverses: false), value: glowAnimation)
                        .opacity(glowAnimation ? 0.45 : 0)
                        .animation(.easeInOut(duration: 0.8), value: glowAnimation)
                    
                    // Liquid glass readability overlay - less opaque for modern look
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial.opacity(glowAnimation ? 0.3 : 0.5))
                        .animation(.easeInOut(duration: 0.6), value: glowAnimation)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .scaleEffect(windowAppearAnimation ? 1.0 : 0.3)
        .opacity(windowAppearAnimation ? 1.0 : 0.0)
        .blur(radius: windowAppearAnimation ? 0 : 10)
        .onAppear {
            speechManager.requestPermissions()
            // Reminder view appeared
            // Check if opening animation is enabled
            if colorTheme.openingAnimationEnabled {
                // Sexy liquid opening animation with spring bounce
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                    windowAppearAnimation = true
                }
            } else {
                // Instant appearance
                windowAppearAnimation = true
            }
            
            // Set up speech recognition callbacks
            speechManager.onTranscriptionUpdate = { transcription in
                DispatchQueue.main.async {
                    self.reminderText = transcription
                }
            }
            
            speechManager.onTranscriptionComplete = { transcription in
                DispatchQueue.main.async {
                    self.reminderText = transcription
                    self.processCommand()
                }
            }
            
            speechManager.onAutoSend = { transcription in
                DispatchQueue.main.async {
                    self.reminderText = transcription
                    self.processCommand()
                    self.reminderText = ""
                }
            }
        }
        .onExitCommand {
            onClose()
        }
        .onReceive(NotificationCenter.default.publisher(for: .returnPressed)) { _ in
            processCommand()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shouldDeactivateApp)) { _ in
            // Immediately cancel any running operations before closing
            // Deactivation signal received
            currentTimer?.cancel()
            currentTimer = nil
            isProcessing = false
            onClose()
        }
        .onReceive(NotificationCenter.default.publisher(for: .voiceActivationRequested)) { _ in
            // Handle voice activation request from hotkey
            toggleSpeechRecognition()
        }
        .onDisappear {
            // Clean up timer when view disappears
            // View disappearing, cleaning up
            currentTimer?.cancel()
            currentTimer = nil
            
            // Reset processing state to be safe
            isProcessing = false
            
            // Reset animation state for next time
            windowAppearAnimation = false
            
            // Stop speech recognition if active
            if speechManager.isListening {
                speechManager.stopListening()
            }
        }
    }
    
    // Helper function to trigger Apple Intelligence-style glow animation
    private func showFlashFeedback(color: Color, success: Bool) {
        // Generate gradient stops for Apple Intelligence-style animation
        generateGlowStops(baseColor: color, success: success)
        
        // Start the glow animation
        glowAnimation = true
        
        // Stop animation after completion (even shorter duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            glowAnimation = false
        }
        
        // Note: Text clearing is now handled earlier in the flow
        // No automatic text clearing here since we handle it after validation
    }
    
    // Generate permanent glow with selected list color
    private func generateListColorGlow() {
        let listColor = colorTheme.selectedListColor
        let primaryColor = colorTheme.primaryColor
        
        let colorVariants: [Color] = [
            listColor,
            primaryColor.opacity(0.8),
            listColor.opacity(0.9),
            primaryColor.opacity(0.6),
            listColor.opacity(0.7),
            primaryColor.opacity(0.4),
            listColor.opacity(0.5),
            Color.clear
        ]
        
        // Create gradient stops for permanent glow
        glowStops = colorVariants.enumerated().map { index, color in
            let position = Double(index) / Double(colorVariants.count - 1)
            return Gradient.Stop(color: color, location: position)
        }.sorted { $0.location < $1.location }
    }
    
    // Generate Apple Intelligence-style gradient stops using theme colors
    private func generateGlowStops(baseColor: Color, success: Bool) {
        let colorVariants: [Color]
        
        if success {
            // Success: Use success color from theme with variants - MORE INTENSE
            let themeSuccess = colorTheme.successColor
            let themePrimary = colorTheme.primaryColor
            let themeSelected = colorTheme.selectedListColor
            
            colorVariants = [
                themeSuccess, // Full intensity
                themePrimary.opacity(0.95),
                themeSelected,
                themeSuccess.opacity(0.9),
                themePrimary.opacity(0.8),
                themeSelected.opacity(0.7),
                themeSuccess.opacity(0.5),
                Color.clear
            ]
        } else {
            // Error: Use error color from theme with variants - MORE INTENSE
            let themeError = colorTheme.errorColor
            let themePrimary = colorTheme.primaryColor
            
            colorVariants = [
                themeError, // Full intensity
                Color.orange.opacity(0.95),
                themeError.opacity(0.95),
                themePrimary.opacity(0.9),
                themeError.opacity(0.8),
                Color.orange.opacity(0.7),
                themeError.opacity(0.5),
                Color.clear
            ]
        }
        
        // Create gradient stops with ordered positions (fix Xcode warning)
        glowStops = colorVariants.enumerated().map { index, color in
            let position = Double(index) / Double(colorVariants.count - 1)
            return Gradient.Stop(color: color, location: position)
        }.sorted { $0.location < $1.location }
    }
    
    private func processCommand() {
        guard !reminderText.isEmpty, !isProcessing else { return }
        
        // Capture the command text immediately
        let commandText = reminderText
        let lowercaseText = commandText.lowercased()
        
        // Add backend delay between command processing to prevent rapid execution issues
        let now = Date()
        let timeSinceLastCommand = now.timeIntervalSince(lastCommandTime)
        let minimumDelay: TimeInterval = 0.8 // 800ms minimum delay between commands (increased)
        
        if timeSinceLastCommand < minimumDelay {
            let remainingDelay = minimumDelay - timeSinceLastCommand
            // Queuing command for processing
            
            // Queue the command for processing after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + remainingDelay) {
                self.executeCommand(commandText, lowercaseText)
            }
            return
        }
        
        // Execute immediately if enough time has passed
        executeCommand(commandText, lowercaseText)
    }
    
    // MARK: - Speech Recognition Functions
    
    private func toggleSpeechRecognition() {
        if speechManager.isListening {
            speechManager.stopListening()
        } else {
            speechManager.startListening()
        }
    }
    
    
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Permission Required"
        alert.informativeText = "QuickReminders needs microphone access to use voice commands.\n\nSteps:\n1. Click 'Open System Settings'\n2. Go to Privacy & Security → Microphone\n3. Find QuickReminders and enable it\n4. Return to the app and try again"
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            speechManager.openMicrophoneSettings()
        }
    }
    
    private func startSpeechRecognition() {
        // Clear any existing text and start listening
        reminderText = ""
        speechManager.startListening()
    }
    
    private func speechPermissionsGranted() -> Bool {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        return speechStatus == .authorized && microphoneStatus == .authorized
    }
    
    private func executeCommand(_ commandText: String, _ lowercaseText: String) {
        // Prevent rapid commands (especially list commands that can cause crashes)
        let now = Date()
        if now.timeIntervalSince(lastCommandTime) < 0.5 {
            // Command too soon after last one, ignore
            return
        }
        
        lastCommandTime = now
        isProcessing = true
        
        // Cancel any existing timer
        currentTimer?.cancel()
        
        // Create a cancellable timer work item instead of DispatchSource
        let timeoutWorkItem = DispatchWorkItem {
            DispatchQueue.main.async {
                if self.isProcessing {
                    self.isProcessing = false
                    self.showFlashFeedback(color: self.colorTheme.errorColor, success: false)
                    self.currentTimer = nil
                }
            }
        }
        
        currentTimer = timeoutWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: timeoutWorkItem)
        
        // Helper to reset processing state safely
        let resetProcessing = {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.currentTimer?.cancel()
                self.currentTimer = nil
            }
        }
        
        // Check for list commands
        let listKeywords = colorTheme.shortcutsEnabled ? ["list", "ls"] : ["list"]
        if listKeywords.contains(where: { lowercaseText.starts(with: $0) }) {
            handleListCommand(lowercaseText, resetProcessing: resetProcessing)
            return
        }
        
        // Check for delete commands
        let deleteKeywords = colorTheme.shortcutsEnabled ? 
            ["delete", "remove", "rm "] : 
            ["delete", "remove"]
        if deleteKeywords.contains(where: { lowercaseText.starts(with: $0) }) {
            handleDeleteCommand(lowercaseText, resetProcessing: resetProcessing)
            return
        }
        
        // Check for move/reschedule commands
        let moveKeywords = colorTheme.shortcutsEnabled ?
            ["move", "reschedule", "mv "] :
            ["move", "reschedule"]
        if moveKeywords.contains(where: { lowercaseText.starts(with: $0) }) {
            handleMoveCommand(lowercaseText, resetProcessing: resetProcessing)
            return
        }
        
        // Regular reminder creation
        nlParser.colorTheme = colorTheme // Set the theme reference for default time
        let parsedReminder = nlParser.parseReminderText(commandText)
        
        // Check validation
        if !parsedReminder.isValid {
            resetProcessing()
            showFlashFeedback(color: colorTheme.errorColor, success: false)
            // Validation error
            return
        }
        
        // Clear the input only after validation passes
        reminderText = ""
        
        if parsedReminder.isRecurring {
            // Create recurring reminder
            guard let startDate = parsedReminder.dueDate,
                  let interval = parsedReminder.recurrenceInterval,
                  let frequency = parsedReminder.recurrenceFrequency else {
                resetProcessing()
                showFlashFeedback(color: colorTheme.errorColor, success: false)
                // Invalid recurring reminder data
                return
            }
            
            reminderManager.createRecurringReminder(
                title: parsedReminder.title,
                notes: nil,
                startDate: startDate,
                interval: interval,
                frequency: frequency,
                endDate: parsedReminder.recurrenceEndDate
            ) { success, error in
                DispatchQueue.main.async {
                    resetProcessing()
                    
                    if success {
                        self.showFlashFeedback(color: self.colorTheme.successColor, success: true)
                        // Created recurring reminder
                    } else {
                        let _ = error?.localizedDescription ?? "Unknown error"
                        self.showFlashFeedback(color: self.colorTheme.errorColor, success: false)
                        // Create recurring reminder error
                    }
                }
            }
        } else {
            // Create regular reminder
            reminderManager.createReminder(
                title: parsedReminder.title,
                notes: nil,
                dueDate: parsedReminder.dueDate
            ) { success, error in
                DispatchQueue.main.async {
                    resetProcessing()
                    
                    if success {
                        self.showFlashFeedback(color: self.colorTheme.successColor, success: true)
                    } else {
                        let _ = error?.localizedDescription ?? "Unknown error"
                        self.showFlashFeedback(color: self.colorTheme.errorColor, success: false)
                        // Create reminder error
                    }
                }
            }
        }
    }
    
    private func handleDeleteCommand(_ text: String, resetProcessing: @escaping () -> Void) {
        let words = text.components(separatedBy: " ")
        guard words.count > 1 else {
            showFlashFeedback(color: colorTheme.errorColor, success: false)
            resetProcessing()
            return
        }
        
        // Handle both full commands (delete/remove) and shortcuts (rm)
        let searchText = words.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        // Deleting reminder
        
        // Enhanced time detection - check for time patterns in the search text BEFORE "to"
        let hasTimeInfo = hasTimeInSearchText(searchText)
        // Enhanced time detection
        
        if hasTimeInfo {
            // Using time-specific search
            // Use enhanced search that can handle time-specific reminders
            reminderManager.findReminderWithTimeContext(searchText: searchText, searchOnlyCurrentList: colorTheme.searchOnlyCurrentList, allowDuplicates: true) { reminders in
                self.processDeleteResult(reminders: reminders, resetProcessing: resetProcessing)
            }
        } else {
            // Using basic search
            // Use original method for basic searches
            reminderManager.findReminder(withTitle: searchText, searchOnlyCurrentList: colorTheme.searchOnlyCurrentList, allowDuplicates: true) { reminders in
                self.processDeleteResult(reminders: reminders, resetProcessing: resetProcessing)
            }
        }
    }
    
    // Enhanced time detection function
    private func hasTimeInSearchText(_ text: String) -> Bool {
        // Look for time patterns: 9:45, at 9:45, from 9:45, 9pm, at 9pm, etc.
        // Also look for date+time patterns: 6.10 9pm, 6/10 at 9:45, etc.
        let timePatterns = [
            "\\d{1,2}:\\d{2}(am|pm|AM|PM)?",      // 9:45, 21:45, 9:45pm (standalone)
            "at \\d{1,2}:\\d{2}(am|pm|AM|PM)?",   // at 9:45, at 9:45pm  
            "from \\d{1,2}:\\d{2}(am|pm|AM|PM)?", // from 9:45, from 9:45pm
            "\\d{1,2}(am|pm|AM|PM)",              // 9pm, 9AM (standalone)
            "at \\d{1,2}(am|pm|AM|PM)",           // at 9pm, at 9AM
            "from \\d{1,2}(am|pm|AM|PM)",         // from 9pm, from 9AM
            "\\d{1,2}[./]\\d{1,2}\\.?\\s+\\d{1,2}(am|pm|AM|PM)", // 6.10 9pm, 6/10 9AM
            "\\d{1,2}[./]\\d{1,2}\\.?\\s+at\\s+\\d{1,2}(am|pm|AM|PM)", // 6.10 at 9pm
            "\\d{1,2}[./]\\d{1,2}\\.?\\s+\\d{1,2}:\\d{2}(am|pm|AM|PM)?", // 6.10 9:45pm, 6/10 21:45
            "\\b(morning|noon|afternoon|evening|night)\\b" // Preset times
        ]
        
        for (_, pattern) in timePatterns.enumerated() {
            // Testing pattern
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                let timeRange = Range(match.range, in: text)!
                let _ = String(text[timeRange])
                // Time pattern matched
                return true
            } else {
                // Pattern did not match
            }
        }
        
        // No time patterns found
        return false
    }
    
    private func processDeleteResult(reminders: [EKReminder], resetProcessing: @escaping () -> Void) {
        DispatchQueue.main.async {
            if reminders.isEmpty {
                // No reminders found to delete - keep text so user can fix typo
                resetProcessing()
                self.showFlashFeedback(color: self.colorTheme.errorColor, success: false)
                // Don't clear reminderText so user can easily fix the command
                return
            }
            
            if reminders.count > 1 {
                // Multiple reminders found - show duplicate selection window
                let command = PendingCommand(
                    type: .remove,
                    query: "", // Not needed for remove
                    targetDate: nil,
                    targetList: nil,
                    isRecurring: false,
                    recurrenceInterval: nil,
                    recurrenceFrequency: nil,
                    recurrenceEndDate: nil
                )
                
                // Clear text since we found reminders and will show selection
                self.reminderText = ""
                self.showDuplicateSelectionFor(reminders: reminders, command: command)
                resetProcessing()
                return
            }
            
            // Single reminder found - delete it directly
            let reminderToDelete = reminders.first!
            // Clear text since we found the reminder and will delete it
            self.reminderText = ""
            self.executeRemoveCommand(for: reminderToDelete)
            resetProcessing()
        }
    }
    
    private func handleMoveCommand(_ text: String, resetProcessing: @escaping () -> Void) {
        // Parse "move X to Y", "reschedule X to Y", or "mv X to Y"
        let words = text.components(separatedBy: " ")
        
        // Find "to" keyword to split the command
        guard let toIndex = words.firstIndex(of: "to"), toIndex > 1 else {
            showFlashFeedback(color: colorTheme.errorColor, success: false)
            resetProcessing()
            return
        }
        
        // Extract reminder search text (everything between "move"/"reschedule" and "to")
        let titleWords = Array(words[1..<toIndex])
        let searchText = titleWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract new date/time (everything after "to")
        let dateWords = Array(words[(toIndex + 1)...])
        let newDateText = dateWords.joined(separator: " ")
        
        // Moving reminder
        
        // For move commands, only use time-specific search if the SOURCE has time info
        // If only target has time (like "move X to 8:12"), use basic search for source
        let hasTimeInSearch = hasTimeInSearchText(searchText)
        // Time in search detected
        // Time in target detected
        
        if hasTimeInSearch {
            // Using time-specific search for move
            // Use enhanced search that can handle time-specific reminders
            reminderManager.findReminderWithTimeContext(searchText: searchText, searchOnlyCurrentList: colorTheme.searchOnlyCurrentList, allowDuplicates: true) { reminders in
                self.processMoveResult(reminders: reminders, newDateText: newDateText, resetProcessing: resetProcessing)
            }
        } else {
            // Using basic search for move
            // Use original method for basic searches
            reminderManager.findReminder(withTitle: searchText, searchOnlyCurrentList: colorTheme.searchOnlyCurrentList, allowDuplicates: true) { reminders in
                self.processMoveResult(reminders: reminders, newDateText: newDateText, resetProcessing: resetProcessing)
            }
        }
    }
    
    private func handleListCommand(_ text: String, resetProcessing: @escaping () -> Void) {
        // Handling list command
        
        // Parse command variants: "list", "ls", "list today", "ls scheduled", etc.
        let words = text.components(separatedBy: " ")
        let _ = words[0] // "list" or "ls"
        
        // Extract filter - join all words after the command to support spaces in list names
        var filter = words.count > 1 ? words[1...].joined(separator: " ").lowercased() : "all"
        
        // Enhanced day parsing - convert shortcuts to full words if enabled
        if colorTheme.shortcutsEnabled {
            filter = expandDayShortcuts(filter)
        }
        
        // List command with filter
        
        // Set the filter for the expandable list
        listFilter = filter
        
        // Guard against rapid state changes
        guard !isTransitioning else { 
            return 
        }
        isTransitioning = true
        
        // First hide any existing view
        if insideWindowState != .hidden {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                insideWindowState = .hidden
            }
            // Wait for hide animation to complete, then show list
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                // Resize window first for smooth appearance
                resizeWindowForList(show: true)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    insideWindowState = .showingList
                }
            }
        } else {
            // Show list immediately if nothing was showing - resize first
            resizeWindowForList(show: true)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                insideWindowState = .showingList
            }
        }
        
        // Set transition to false after animation with safety timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isTransitioning = false
        }
        
        // Safety timeout in case something goes wrong
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.isTransitioning {
                self.isTransitioning = false
            }
        }
        
        // Clear text on successful list command
        reminderText = ""
        showFlashFeedback(color: colorTheme.successColor, success: true)
        resetProcessing()
    }
    
    private func expandDayShortcuts(_ filter: String) -> String {
        // Map of shortcuts to full words
        let dayShortcuts = [
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
        
        var expandedFilter = filter
        
        // Replace shortcuts with full words
        for (shortcut, fullWord) in dayShortcuts {
            // Use word boundaries to avoid partial matches
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: shortcut) + "\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                expandedFilter = regex.stringByReplacingMatches(
                    in: expandedFilter,
                    options: [],
                    range: NSRange(expandedFilter.startIndex..., in: expandedFilter),
                    withTemplate: fullWord
                )
            }
        }
        
        // Expanded filter
        return expandedFilter
    }
    
    private func resizeWindowForList(show: Bool) {
        // Get the current window
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.level == .popUpMenu }) else {
            // Could not find window to resize
            return
        }
        
        let currentFrame = window.frame
        let newHeight: CGFloat = show ? 450 : baseWindowHeight // Expand to 450px for list
        let heightDifference = newHeight - currentFrame.height
        
        // Calculate new frame - expand upward so input stays in same position
        let newFrame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.minY - heightDifference, // Move window up by height difference
            width: currentFrame.width,
            height: newHeight
        )
        
        // Resizing window
        
        // Animate the resize
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
    }
    
    private func processSingleReminderMove(_ reminderToMove: EKReminder, newDateText: String, resetProcessing: @escaping () -> Void) {
        // Parse the new date/time and recurrence using smart parsing
        self.nlParser.colorTheme = self.colorTheme
        let enhancedDateText: String
        if newDateText.trimmingCharacters(in: .whitespacesAndNewlines).range(of: "^\\d{1,2}$", options: .regularExpression) != nil {
            enhancedDateText = "at " + newDateText
        } else {
            enhancedDateText = newDateText
        }
        
        let parsedResult = self.nlParser.parseReminderText("dummy " + enhancedDateText)
        guard let parsedDate = parsedResult.dueDate,
              let originalDueDate = reminderToMove.dueDateComponents?.date else {
            resetProcessing()
            self.showFlashFeedback(color: self.colorTheme.errorColor, success: false)
            return
        }
        
        // Check if the move command includes recurrence
        let hasRecurrence = parsedResult.isRecurring
        
        // Smart date combination logic
        let calendar = Calendar.current
        let newDate: Date
        
        // Apply smart date combination logic for both recurring and non-recurring moves
        let dateKeywords = ["today", "td", "tomorrow", "tm", "monday", "mon", "tuesday", "tue", "wednesday", "wed", "thursday", "thu", "friday", "fri", "saturday", "sat", "sunday", "sun", "next week", "next month"]
        let datePatterns = ["\\d{1,2}[./]\\d{1,2}"] // Match date patterns like 6.10, 6/10
        let containsDateKeyword = dateKeywords.contains { newDateText.lowercased().contains($0) }
        let containsDatePattern = datePatterns.contains { pattern in
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            return regex?.firstMatch(in: newDateText, options: [], range: NSRange(newDateText.startIndex..., in: newDateText)) != nil
        }
        
        if containsDateKeyword || containsDatePattern {
            // User specified a day but check if time was also specified
            let hasTimeInTarget = self.hasTimeInSearchText(newDateText)
            
            if hasTimeInTarget {
                // Day + time specified, use parsed date completely
                newDate = parsedDate
            } else {
                // Only day specified, preserve original time
                let originalTimeComponents = calendar.dateComponents([.hour, .minute], from: originalDueDate)
                let newDayComponents = calendar.dateComponents([.year, .month, .day], from: parsedDate)
                
                var combinedComponents = DateComponents()
                combinedComponents.year = newDayComponents.year
                combinedComponents.month = newDayComponents.month
                combinedComponents.day = newDayComponents.day
                combinedComponents.hour = originalTimeComponents.hour
                combinedComponents.minute = originalTimeComponents.minute
                
                newDate = calendar.date(from: combinedComponents) ?? parsedDate
            }
        } else {
            // User only specified time (like "8pm"), preserve original day
            let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedDate)
            let dayComponents = calendar.dateComponents([.year, .month, .day], from: originalDueDate)
            
            var combinedComponents = DateComponents()
            combinedComponents.year = dayComponents.year
            combinedComponents.month = dayComponents.month
            combinedComponents.day = dayComponents.day
            combinedComponents.hour = timeComponents.hour
            combinedComponents.minute = timeComponents.minute
            
            newDate = calendar.date(from: combinedComponents) ?? parsedDate
        }
        
        // Use the appropriate update function based on whether recurrence is involved
        if hasRecurrence {
            self.reminderManager.updateReminderDateAndRecurrence(
                reminderToMove,
                newDate: newDate,
                isRecurring: parsedResult.isRecurring,
                interval: parsedResult.recurrenceInterval,
                frequency: parsedResult.recurrenceFrequency,
                endDate: parsedResult.recurrenceEndDate
            ) { success, error in
                DispatchQueue.main.async {
                    resetProcessing()
                    
                    if success {
                        self.showFlashFeedback(color: self.colorTheme.successColor, success: true)
                    } else {
                        self.showFlashFeedback(color: self.colorTheme.errorColor, success: false)
                    }
                }
            }
        } else {
            self.reminderManager.updateReminderDate(reminderToMove, newDate: newDate) { success, error in
                DispatchQueue.main.async {
                    resetProcessing()
                    
                    if success {
                        self.showFlashFeedback(color: self.colorTheme.successColor, success: true)
                    } else {
                        self.showFlashFeedback(color: self.colorTheme.errorColor, success: false)
                    }
                }
            }
        }
    }
    
    private func processMoveResult(reminders: [EKReminder], newDateText: String, resetProcessing: @escaping () -> Void) {
        DispatchQueue.main.async {
            if reminders.isEmpty {
                // No reminders found to move - keep text so user can fix typo
                resetProcessing()
                self.showFlashFeedback(color: self.colorTheme.errorColor, success: false)
                // Don't clear reminderText so user can easily fix the command
                return
            }
            
            if reminders.count > 1 {
                // Multiple reminders found - show duplicate selection window
                // First, we need to parse the target date
                self.nlParser.colorTheme = self.colorTheme
                let enhancedDateText: String
                if newDateText.trimmingCharacters(in: .whitespacesAndNewlines).range(of: "^\\d{1,2}$", options: .regularExpression) != nil {
                    enhancedDateText = "at " + newDateText
                } else {
                    enhancedDateText = newDateText
                }
                
                let parsedResult = self.nlParser.parseReminderText("dummy " + enhancedDateText)
                guard let parsedDate = parsedResult.dueDate else {
                    resetProcessing()
                    self.showFlashFeedback(color: self.colorTheme.errorColor, success: false)
                    return
                }
                
                let command = PendingCommand(
                    type: .move,
                    query: newDateText,
                    targetDate: parsedDate,
                    targetList: nil,
                    isRecurring: parsedResult.isRecurring,
                    recurrenceInterval: parsedResult.recurrenceInterval,
                    recurrenceFrequency: parsedResult.recurrenceFrequency,
                    recurrenceEndDate: parsedResult.recurrenceEndDate
                )
                
                // Clear text since we found reminders and will show selection
                self.reminderText = ""
                self.showDuplicateSelectionFor(reminders: reminders, command: command)
                resetProcessing()
                return
            }
            
            // Single reminder found - move it directly using the existing complex logic
            let reminderToMove = reminders.first!
            // Clear text since we found the reminder and will move it
            self.reminderText = ""
            self.processSingleReminderMove(reminderToMove, newDateText: newDateText, resetProcessing: resetProcessing)
        }
    }
    
    // MARK: - Duplicate Selection Functions
    
    private func showDuplicateSelectionFor(reminders: [EKReminder], command: PendingCommand) {
        duplicateReminders = reminders
        pendingCommand = command
        
        // Guard against rapid state changes
        guard !isTransitioning else { 
            return 
        }
        isTransitioning = true
        
        // First hide any existing view
        if insideWindowState != .hidden {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                insideWindowState = .hidden
            }
            // Wait for hide animation to complete, then show duplicates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                // Resize window first for smooth appearance
                resizeWindowForDuplicateSelection(show: true)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    insideWindowState = .showingDuplicates
                }
            }
        } else {
            // Show duplicates immediately if nothing was showing - resize first
            resizeWindowForDuplicateSelection(show: true)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                insideWindowState = .showingDuplicates
            }
        }
        
        // Set transition to false after animation with safety timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isTransitioning = false
        }
        
        // Safety timeout in case something goes wrong
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.isTransitioning {
                self.isTransitioning = false
            }
        }
    }
    
    private func handleDuplicateSelection(_ selectedReminder: EKReminder) {
        guard let command = pendingCommand else { return }
        
        closeDuplicateSelection()
        
        // Execute the original command on the selected reminder
        switch command.type {
        case .remove:
            executeRemoveCommand(for: selectedReminder)
        case .move:
            executeMoveCommand(for: selectedReminder, command: command)
        }
    }
    
    private func closeDuplicateSelection() {
        guard !isTransitioning else { return }
        isTransitioning = true
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            insideWindowState = .hidden
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            resizeWindowForDuplicateSelection(show: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isTransitioning = false
        }
        
        // Clear state
        duplicateReminders = []
        pendingCommand = nil
        reminderText = ""
    }
    
    private func resizeWindowForDuplicateSelection(show: Bool) {
        // Get the current window
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.level == .popUpMenu }) else {
            return
        }
        
        let currentFrame = window.frame
        let newHeight: CGFloat = show ? 350 : baseWindowHeight // Smaller than list view
        let heightDifference = newHeight - currentFrame.height
        
        // Calculate new frame - expand upward so input stays in same position
        let newFrame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.minY - heightDifference,
            width: currentFrame.width,
            height: newHeight
        )
        
        // Animate the resize
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.allowsImplicitAnimation = true
            window.animator().setFrame(newFrame, display: true, animate: true)
        })
    }
    
    private func executeRemoveCommand(for reminder: EKReminder) {
        reminderManager.deleteReminder(reminder) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.showFlashFeedback(color: self.colorTheme.successColor, success: true)
                } else {
                    self.showFlashFeedback(color: self.colorTheme.errorColor, success: false)
                }
            }
        }
    }
    
    private func executeMoveCommand(for reminder: EKReminder, command: PendingCommand) {
        if let targetDate = command.targetDate {
            // Use the appropriate update function based on whether recurrence is involved
            if command.isRecurring {
                reminderManager.updateReminderDateAndRecurrence(
                    reminder,
                    newDate: targetDate,
                    isRecurring: command.isRecurring,
                    interval: command.recurrenceInterval,
                    frequency: command.recurrenceFrequency,
                    endDate: command.recurrenceEndDate
                ) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.showFlashFeedback(color: self.colorTheme.successColor, success: true)
                        } else {
                            self.showFlashFeedback(color: self.colorTheme.errorColor, success: false)
                        }
                    }
                }
            } else {
                reminderManager.updateReminderDate(reminder, newDate: targetDate) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            self.showFlashFeedback(color: self.colorTheme.successColor, success: true)
                        } else {
                            self.showFlashFeedback(color: self.colorTheme.errorColor, success: false)
                        }
                    }
                }
            }
        } else if let targetList = command.targetList {
            // Handle list move
            reminderManager.updateReminderList(reminder, newList: targetList) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.showFlashFeedback(color: self.colorTheme.successColor, success: true)
                    } else {
                        self.showFlashFeedback(color: self.colorTheme.errorColor, success: false)
                    }
                }
            }
        }
    }
}

struct ListPickerView: View {
    @ObservedObject var reminderManager: ReminderManager
    @ObservedObject var colorTheme: ColorThemeManager
    let onListSelected: (EKCalendar) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Reminder List")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 12)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(reminderManager.availableLists, id: \.calendarIdentifier) { list in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(list.cgColor))
                                .frame(width: 12, height: 12)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(list.title)
                                    .font(.system(size: 13, weight: .medium))
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            list == reminderManager.selectedList ? 
                            Color(list.cgColor).opacity(0.1) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .contentShape(Rectangle()) // Make entire area clickable
                        .onTapGesture {
                            // Safe list selection - now works anywhere in the row
                            onListSelected(list)
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct RemindersListView: View {
    @ObservedObject var reminderManager: ReminderManager
    @ObservedObject var colorTheme: ColorThemeManager
    let filter: String
    let onClose: () -> Void
    
    @State private var filteredReminders: [EKReminder] = []
    @State private var isLoading = true
    @State private var currentListColor: Color? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(headerTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            Divider()
                .opacity(0.3)
            
            // Reminders list content
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading reminders...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if filteredReminders.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundColor(.secondary)
                            .font(.system(size: 24))
                        Text("No reminders found")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("for \"\(filter)\"")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredReminders, id: \.calendarItemIdentifier) { reminder in
                            ReminderRowView(
                                reminder: reminder,
                                colorTheme: colorTheme
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxHeight: 280) // Reasonable max height with scrolling
            }
            
            Spacer(minLength: 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(listBorderColor.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            loadFilteredReminders()
        }
        .onChange(of: filter) {
            loadFilteredReminders()
        }
    }
    
    private var headerTitle: String {
        switch filter.lowercased() {
        case "today":
            return "Today's Reminders"
        case "tomorrow":
            return "Tomorrow's Reminders"
        case "scheduled":
            return "Scheduled Reminders"
        case "all":
            return "All Reminders"
        case "completed":
            return "Completed Reminders"
        case "overdue":
            return "Overdue Reminders"
        case "monday":
            return "Monday Reminders"
        case "tuesday":
            return "Tuesday Reminders"
        case "wednesday":
            return "Wednesday Reminders"
        case "thursday":
            return "Thursday Reminders"
        case "friday":
            return "Friday Reminders"
        case "saturday":
            return "Saturday Reminders"
        case "sunday":
            return "Sunday Reminders"
        case let filter where filter.contains("next"):
            let dayName = filter.replacingOccurrences(of: "next ", with: "").capitalized
            return "Next \(dayName) Reminders"
        default:
            return "Reminders (\(filter.capitalized))"
        }
    }
    
    private var listBorderColor: Color {
        // Use tracked current list color, or color of first reminder, or fallback to selected list color
        if let trackedColor = currentListColor {
            return trackedColor
        }
        if let firstReminder = filteredReminders.first {
            return Color(firstReminder.calendar.cgColor)
        }
        return colorTheme.selectedListColor
    }
    
    private func loadFilteredReminders() {
        isLoading = true
        
        // Loading reminders with filter
        
        // Get all reminders fresh from EventKit
        reminderManager.getAllReminders { allReminders in
            DispatchQueue.main.async {
                // Received reminders from EventKit
                self.filteredReminders = self.filterReminders(allReminders)
                
                // Capture the list color for this filter
                if let firstReminder = self.filteredReminders.first {
                    self.currentListColor = Color(firstReminder.calendar.cgColor)
                    // Captured list color for filter
                } else {
                    self.currentListColor = nil
                    // No reminders found, cleared list color
                }
                
                // Filtered reminders for filter
                self.isLoading = false
            }
        }
    }
    
    private func filterReminders(_ reminders: [EKReminder]) -> [EKReminder] {
        let calendar = Calendar.current
        let now = Date()
        
        switch filter.lowercased() {
        case "today":
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: now) && !reminder.isCompleted
            }
            
        case "scheduled":
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                // Include all reminders from today onwards (start of today)
                let startOfToday = calendar.startOfDay(for: now)
                return dueDate >= startOfToday && !reminder.isCompleted
            }
            
        case "completed":
            return reminders.filter { $0.isCompleted }
            
        case "overdue":
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return dueDate < now && !reminder.isCompleted
            }
            
        case "this week":
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return dueDate >= startOfWeek && dueDate < endOfWeek && !reminder.isCompleted
            }
            
        case "this month":
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return dueDate >= startOfMonth && dueDate < endOfMonth && !reminder.isCompleted
            }
            
        case "this year":
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            let endOfYear = calendar.dateInterval(of: .year, for: now)?.end ?? now
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return dueDate >= startOfYear && dueDate < endOfYear && !reminder.isCompleted
            }
            
        case "next week":
            let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
            let startOfNextWeek = calendar.dateInterval(of: .weekOfYear, for: nextWeek)?.start ?? now
            let endOfNextWeek = calendar.dateInterval(of: .weekOfYear, for: nextWeek)?.end ?? now
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return dueDate >= startOfNextWeek && dueDate < endOfNextWeek && !reminder.isCompleted
            }
            
        case "next month":
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            let startOfNextMonth = calendar.dateInterval(of: .month, for: nextMonth)?.start ?? now
            let endOfNextMonth = calendar.dateInterval(of: .month, for: nextMonth)?.end ?? now
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return dueDate >= startOfNextMonth && dueDate < endOfNextMonth && !reminder.isCompleted
            }
            
        case "next year":
            let nextYear = calendar.date(byAdding: .year, value: 1, to: now) ?? now
            let startOfNextYear = calendar.dateInterval(of: .year, for: nextYear)?.start ?? now
            let endOfNextYear = calendar.dateInterval(of: .year, for: nextYear)?.end ?? now
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return dueDate >= startOfNextYear && dueDate < endOfNextYear && !reminder.isCompleted
            }
            
        case "all":
            return reminders.filter { !$0.isCompleted }
            
        case "tomorrow":
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: now) ?? now) && !reminder.isCompleted
            }
            
        case let filter where filter.hasPrefix("this ") && (filter.contains("monday") || filter.contains("tuesday") || filter.contains("wednesday") || filter.contains("thursday") || filter.contains("friday") || filter.contains("saturday") || filter.contains("sunday")):
            return filterThisPeriod(reminders, filter: filter)
            
        case "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday":
            return filterByWeekday(reminders, weekdayName: filter.lowercased())
            
        case let filter where filter.contains("next"):
            return filterNextPeriod(reminders, filter: filter)
            
        default:
            // First check for exact list name match
            let exactListMatch = reminders.filter { reminder in
                let listName = reminder.calendar.title.lowercased()
                return listName == filter && !reminder.isCompleted
            }
            
            if !exactListMatch.isEmpty {
                // Found reminders in exact list match
                return exactListMatch
            }
            
            // Then check for partial list name match
            let partialListMatch = reminders.filter { reminder in
                let listName = reminder.calendar.title.lowercased()
                return listName.contains(filter) && !reminder.isCompleted
            }
            
            if !partialListMatch.isEmpty {
                // Found reminders in partial list match
                return partialListMatch
            }
            
            // If no list matches, search by reminder title
            let filteredByTitle = reminders.filter { reminder in
                let title = reminder.title?.lowercased() ?? ""
                return title.contains(filter) && !reminder.isCompleted
            }
            
            // Found reminders with title matching
            return filteredByTitle
        }
    }
    
    private func filterByWeekday(_ reminders: [EKReminder], weekdayName: String) -> [EKReminder] {
        let calendar = Calendar.current
        let _ = Date() // Build warning fix - unused variable
        
        // Map day names to Calendar weekday values (1=Sunday, 2=Monday, etc.)
        let weekdayMap = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7
        ]
        
        guard let targetWeekday = weekdayMap[weekdayName] else {
            // Unknown weekday
            return []
        }
        
        return reminders.filter { reminder in
            guard let dueDate = reminder.dueDateComponents?.date else { return false }
            let reminderWeekday = calendar.component(.weekday, from: dueDate)
            return reminderWeekday == targetWeekday && !reminder.isCompleted
        }
    }
    
    private func filterNextPeriod(_ reminders: [EKReminder], filter: String) -> [EKReminder] {
        let calendar = Calendar.current
        let now = Date()
        
        if filter.contains("next friday") {
            // Find next Friday
            let nextFriday = getNext(.friday, from: now)
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: nextFriday) && !reminder.isCompleted
            }
        } else if filter.contains("next monday") {
            let nextMonday = getNext(.monday, from: now)
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: nextMonday) && !reminder.isCompleted
            }
        } else if filter.contains("next tuesday") {
            let nextTuesday = getNext(.tuesday, from: now)
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: nextTuesday) && !reminder.isCompleted
            }
        } else if filter.contains("next wednesday") {
            let nextWednesday = getNext(.wednesday, from: now)
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: nextWednesday) && !reminder.isCompleted
            }
        } else if filter.contains("next thursday") {
            let nextThursday = getNext(.thursday, from: now)
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: nextThursday) && !reminder.isCompleted
            }
        } else if filter.contains("next saturday") {
            let nextSaturday = getNext(.saturday, from: now)
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: nextSaturday) && !reminder.isCompleted
            }
        } else if filter.contains("next sunday") {
            let nextSunday = getNext(.sunday, from: now)
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: nextSunday) && !reminder.isCompleted
            }
        }
        
        return []
    }
    
    private func filterThisPeriod(_ reminders: [EKReminder], filter: String) -> [EKReminder] {
        let calendar = Calendar.current
        let now = Date()
        
        if filter.contains("this monday") {
            // Find this Monday (the Monday of current week)
            let thisMonday = getThis(.monday, from: now)
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: thisMonday) && !reminder.isCompleted
            }
        } else if filter.contains("this tuesday") {
            let thisTuesday = getThis(.tuesday, from: now)
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: thisTuesday) && !reminder.isCompleted
            }
        } else if filter.contains("this wednesday") {
            let thisWednesday = getThis(.wednesday, from: now)
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: thisWednesday) && !reminder.isCompleted
            }
        } else if filter.contains("this thursday") {
            let thisThursday = getThis(.thursday, from: now)
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: thisThursday) && !reminder.isCompleted
            }
        } else if filter.contains("this friday") {
            let thisFriday = getThis(.friday, from: now)
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: thisFriday) && !reminder.isCompleted
            }
        } else if filter.contains("this saturday") {
            let thisSaturday = getThis(.saturday, from: now)
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: thisSaturday) && !reminder.isCompleted
            }
        } else if filter.contains("this sunday") {
            let thisSunday = getThis(.sunday, from: now)
            return reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: thisSunday) && !reminder.isCompleted
            }
        }
        
        return []
    }
    
    private func getThis(_ weekday: Weekday, from date: Date) -> Date {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        
        let targetWeekdayValue: Int
        switch weekday {
        case .sunday: targetWeekdayValue = 1
        case .monday: targetWeekdayValue = 2
        case .tuesday: targetWeekdayValue = 3
        case .wednesday: targetWeekdayValue = 4
        case .thursday: targetWeekdayValue = 5
        case .friday: targetWeekdayValue = 6
        case .saturday: targetWeekdayValue = 7
        }
        
        let daysToAdd = targetWeekdayValue - currentWeekday
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: date) ?? date
    }
    
    private func getNext(_ weekday: Weekday, from date: Date) -> Date {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        
        let targetWeekdayValue: Int
        switch weekday {
        case .sunday: targetWeekdayValue = 1
        case .monday: targetWeekdayValue = 2
        case .tuesday: targetWeekdayValue = 3
        case .wednesday: targetWeekdayValue = 4
        case .thursday: targetWeekdayValue = 5
        case .friday: targetWeekdayValue = 6
        case .saturday: targetWeekdayValue = 7
        }
        
        var daysToAdd = targetWeekdayValue - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7 // Move to next week
        }
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: date) ?? date
    }
}

enum Weekday {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday
}

struct ReminderRowView: View {
    let reminder: EKReminder
    @ObservedObject var colorTheme: ColorThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Calendar color indicator
            Circle()
                .fill(Color(reminder.calendar.cgColor))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title ?? "Untitled")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if let dueDate = reminder.dueDateComponents?.date {
                    Text(formatDate(dueDate))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                if let notes = reminder.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Status indicator
            if reminder.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(colorTheme.successColor)
                    .font(.system(size: 14))
            } else if let dueDate = reminder.dueDateComponents?.date, dueDate < Date() {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(colorTheme.errorColor)
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(reminder.calendar.cgColor).opacity(0.05))
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "h:mm a"
            return "Tomorrow at \(formatter.string(from: date))"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE 'at' h:mm a"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"
            return formatter.string(from: date)
        }
    }
    
}

// MARK: - Duplicate Selection View

struct DuplicateSelectionView: View {
    let duplicateReminders: [EKReminder]
    let pendingCommand: PendingCommand?
    let colorTheme: ColorThemeManager
    let onReminderSelected: (EKReminder) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Multiple Reminders Found")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let command = pendingCommand {
                        let actionText = command.type == .remove ? "remove" : "move"
                        Text("Select which reminder to \(actionText):")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            // Reminders list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(duplicateReminders, id: \.calendarItemIdentifier) { reminder in
                        DuplicateReminderRow(
                            reminder: reminder,
                            colorTheme: colorTheme,
                            onSelect: {
                                onReminderSelected(reminder)
                            }
                        )
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct DuplicateReminderRow: View {
    let reminder: EKReminder
    let colorTheme: ColorThemeManager
    let onSelect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // List color indicator
            Circle()
                .fill(Color(reminder.calendar.cgColor))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(reminder.title ?? "Untitled")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let dueDate = reminder.dueDateComponents?.date {
                        Text(formatDate(dueDate))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text(reminder.calendar.title)
                        .font(.system(size: 11))
                        .foregroundColor(Color(reminder.calendar.cgColor))
                    
                    if reminder.hasRecurrenceRules && !(reminder.recurrenceRules?.isEmpty ?? true) {
                        Text("• Recurring")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.blue.opacity(0.1) : Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isHovered ? Color.blue.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "Today \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "h:mm a"
            return "Tomorrow \(formatter.string(from: date))"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEE h:mm a"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}