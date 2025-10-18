//
//  QuickRemindersApp.swift
//  QuickReminders
//
//  Created by Martin Kostelka on 03.10.2025.
//

import SwiftUI
import AppKit
import Combine
import EventKit

extension Notification.Name {
    static let shouldDeactivateApp = Notification.Name("shouldDeactivateApp")
    static let upArrowPressed = Notification.Name("upArrowPressed")
    static let downArrowPressed = Notification.Name("downArrowPressed")
    static let returnPressed = Notification.Name("returnPressed")
    static let tabPressed = Notification.Name("tabPressed")
    static let escapeKeyWasPressed = Notification.Name("EscapeKeyWasPressed")
    static let applicationShouldExit = Notification.Name("ApplicationShouldExit")
    static let accessibilityPermissionChanged = Notification.Name("accessibilityPermissionChanged")
}

@main
struct QuickRemindersApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Only show Settings - main interaction is through global hotkey
        Settings {
            PreferencesView(
                reminderManager: appDelegate.reminderManager,
                hotKeyManager: appDelegate.hotKeyManager,
                colorTheme: appDelegate.colorTheme,
                speechManager: appDelegate.speechManager
            )
            .frame(minWidth: 700, minHeight: 500)
        }
    }
}

// Window delegate for settings window
class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem!
    @Published var reminderManager: ReminderManager
    @Published var hotKeyManager: HotKeyManager
    @Published var floatingWindowManager: FloatingWindowManager
    @Published var colorTheme: ColorThemeManager
    @Published var speechManager: SpeechManager

    @Published var showInMenuBar = true
    private var cancellables = Set<AnyCancellable>()
    
    // Spotlight-like app state (following Snap's pattern)
    private var isActive = false
    private var isStarted = false
    private var monitor: Any?
    private let notificationCenter = NotificationCenter.default
    private var gettingStartedWindow: NSWindow?
    private var isShowingSettings = false // Track if settings are being shown
    
    override init() {
        let colorTheme = ColorThemeManager()
        self.colorTheme = colorTheme
        self.reminderManager = ReminderManager(colorTheme: colorTheme)
        self.hotKeyManager = HotKeyManager()
        self.floatingWindowManager = FloatingWindowManager()
        self.speechManager = SpeechManager()
        
        super.init()
        // AppDelegate initializing
        
        // Subscribe to hotKeyManager changes
        hotKeyManager.$currentHotKey
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupMenuBar()
            }
            .store(in: &cancellables)
        
        // Observe accessibility permission changes
        notificationCenter.addObserver(
            self,
            selector: #selector(setupMenuBar),
            name: .accessibilityPermissionChanged,
            object: nil
        )
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // QuickReminders launched as Spotlight-like app
        
        // Ensure we don't block the main thread
        DispatchQueue.main.async { [weak self] in
            // Set as background app initially (no dock icon, no menu bar)
            NSApp.setActivationPolicy(.accessory)
            
            // Hide main window if any
            NSApp.windows.forEach { $0.orderOut(nil) }
            
            self?.setupMenuBar()
            
            // Check for permissions and first launch
            var remindersAuthorized = false
            if #available(macOS 14.0, *) {
                let status = EKEventStore.authorizationStatus(for: .reminder)
                remindersAuthorized = status == .fullAccess || status == .writeOnly
            } else {
                remindersAuthorized = EKEventStore.authorizationStatus(for: .reminder) == .authorized
            }
            let accessibilityTrusted = AXIsProcessTrusted()
            
            if !UserDefaults.standard.bool(forKey: "StartedBefore") || !remindersAuthorized || !accessibilityTrusted {
                self?.showGettingStartedWindow()
                return
            }
            
            // Small delay to ensure managers are ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.start()
            }
        }
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        // Following Snap's pattern - only deactivate if no important windows are visible
        // Don't deactivate if we're showing settings
        if isStarted && isActive && !floatingWindowManager.isWindowVisible && !isShowingSettings {
            let hasVisibleWindows = (gettingStartedWindow?.isVisible == true) || 
                                   (preferencesWindow?.isVisible == true)
            
            if !hasVisibleWindows {
                // App resigned active with no visible window, deactivating
                deactivate()
            }
        }
    }
    
    private func requestPermissions() {
        // Check accessibility permissions
        let trusted = AXIsProcessTrusted()
        if !trusted {
            // Accessibility permissions needed for global hotkeys
            // We'll let the user grant this through settings when they want to use hotkeys
        } else {
            // Accessibility permissions already granted
        }
    }
    
    private func isRunningInPreview() -> Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] != nil ||
               ProcessInfo.processInfo.environment["PLAYGROUND_LOGGER_FILTER"] != nil
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep app running even when no windows are open
    }
    
    @objc private func setupMenuBar() {
        // Setting up menu bar
        
        // Create or reuse status item
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        }
        
        guard let button = statusItem.button else {
            // CRITICAL: Failed to get status item button
            return
        }
        
        // Set up the bolt icon
        button.image = NSImage(named: "MenuBarIcon")
        button.image?.isTemplate = true
        
        // Ensure button is enabled
        button.isEnabled = true
        
        // Status item button created and configured
        
        // Create menu immediately (no async delays)
        let menu = NSMenu()
        
        // Quick Reminder menu item (main feature)
        let quickReminderItem = NSMenuItem(title: "Quick Reminder (\(hotKeyManager.currentHotKey))", action: #selector(activate), keyEquivalent: "")
        quickReminderItem.target = self
        menu.addItem(quickReminderItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings menu item
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Permission status - check immediately
        let trusted = AXIsProcessTrusted()
        let permissionItem = NSMenuItem(
            title: trusted ? "✅ Global Hotkey Ready" : "⚠️ Enable Global Hotkey...", 
            action: trusted ? nil : #selector(requestPermissionsManually),
            keyEquivalent: ""
        )
        permissionItem.target = self
        menu.addItem(permissionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit menu item
        let quitItem = NSMenuItem(title: "Quit QuickReminders", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Set the menu immediately
        statusItem.menu = menu
        // Menu bar setup complete
    }
    
    
    private var preferencesWindow: PreferencesWindow?
    
    @objc private func showSettings() {
        // Settings menu item clicked
        
        // Mark that we're showing settings
        isShowingSettings = true
        
        // Just hide floating window without full deactivation to prevent layering issues
        if floatingWindowManager.isWindowVisible {
            floatingWindowManager.hideFloatingWindow()
            // Set isActive to false but don't call full deactivate
            isActive = false
            // Remove keyboard monitor since floating window is hidden
            removeKeyboardMonitor()
        }
        
        // Check if preferences window already exists and is visible (like Snap)
        if preferencesWindow?.isVisible == true {
            preferencesWindow?.makeKeyAndOrderFront(nil)
            return
        }
        
        // Bring app to front
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Create new preferences window (like Snap)
        preferencesWindow = PreferencesWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        preferencesWindow?.title = "QuickReminders Preferences"
        preferencesWindow?.center()
        preferencesWindow?.level = .normal
        preferencesWindow?.isReleasedWhenClosed = false // Prevent crashes (like Snap)
        
        // Set up delegate to track when settings window closes
        let settingsDelegate = SettingsWindowDelegate { [weak self] in
            self?.isShowingSettings = false
            // Settings window closed
        }
        preferencesWindow?.delegate = settingsDelegate
        
        let preferencesView = PreferencesView(
            reminderManager: reminderManager,
            hotKeyManager: hotKeyManager,
            colorTheme: colorTheme,
            speechManager: speechManager
        )
        let hostingView = NSHostingView(rootView: preferencesView)
        preferencesWindow?.contentView = hostingView
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc private func requestPermissionsManually() {
        // Grant Permissions menu item clicked
        
        // Show alert with instructions
        let alert = NSAlert()
        alert.messageText = "Enable Global Hotkey"
        alert.informativeText = "To use the global hotkey (\(hotKeyManager.currentHotKey)), QuickReminders needs Accessibility permissions.\n\n1. Click 'Open System Settings'\n2. Go to Privacy & Security → Accessibility\n3. Add QuickReminders and enable it\n4. Restart QuickReminders"
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .informational
        
        // Show alert
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Preferences
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
        
        // Return to menu bar mode
        NSApp.setActivationPolicy(.accessory)
    }
    
    @objc private func quitApp() {
        // Quit menu item clicked
        NSApplication.shared.terminate(nil)
    }
    
    
    private func showGettingStartedWindow() {
        // Create getting started window
        gettingStartedWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 800),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        guard let window = gettingStartedWindow else { return }
        
        window.title = "Welcome to QuickReminders"
        window.level = .floating
        window.center()
        window.isReleasedWhenClosed = false // Like Snap does
        
        let contentView = NSHostingView(rootView: GettingStartedView(
            reminderManager: reminderManager
        ) { [weak self] in
            // Mark as started and close getting started window
            UserDefaults.standard.setValue(true, forKey: "StartedBefore")
            UserDefaults.standard.synchronize()
            self?.gettingStartedWindow?.close()
            self?.gettingStartedWindow = nil
            self?.start()
        })
        
        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        
        // Show as regular app for getting started
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func start() {
        // Starting QuickReminders main functionality
        isStarted = true
        
        // Return to background mode
        NSApp.setActivationPolicy(.accessory)
        
        setupSpotlightLikeApp()
        
        // Do permission checking in background
        DispatchQueue.global(qos: .userInitiated).async {
            self.requestPermissions()
        }
        
        // QuickReminders started successfully
    }
    
    private func setupSpotlightLikeApp() {
        // Setup the floating window manager with shared reminder manager and color theme
        floatingWindowManager.setReminderManager(reminderManager)
        floatingWindowManager.setColorTheme(colorTheme)
        floatingWindowManager.setSpeechManager(speechManager)
        
        // Setup Spotlight-like global hotkey behavior
        hotKeyManager.onHotKeyPressed = { [weak self] in
            DispatchQueue.main.async {
                if self?.isActive == true && self?.floatingWindowManager.isWindowVisible == true {
                    // If already active, deactivate
                    self?.deactivate()
                } else {
                    // If not active, activate
                    self?.activate()
                }
            }
        }
        
        // Setup notifications for proper app lifecycle (like Snap)
        notificationCenter.addObserver(
            forName: .shouldDeactivateApp,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.deactivate()
        }
        
        notificationCenter.addObserver(
            forName: .applicationShouldExit,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.deactivate()
        }
        
        notificationCenter.addObserver(
            forName: .escapeKeyWasPressed,
            object: nil,
            queue: nil
        ) { _ in
            // Additional cleanup if needed when escape is pressed
            // Escape key notification received
        }
    }
    
    // MARK: - Spotlight-like Activation/Deactivation
    
    @objc func activate() {
        // Prevent activation if not started yet (like Snap)
        guard isStarted else {
            // App not started yet, ignoring activation request
            return
        }
        
        // Prevent activation if already active
        guard !isActive else { 
            // Already active, ignoring activation request
            return 
        }
        
        // Activating Spotlight-like interface
        
        // Just hide settings window without closing it to prevent layering issues
        if preferencesWindow?.isVisible == true {
            preferencesWindow?.orderOut(nil)
        }
        
        // Set active first to prevent race conditions
        isActive = true
        
        // Set app as regular to receive focus
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Show the floating window
        floatingWindowManager.showFloatingWindow()
        
        // Start keyboard monitoring
        addKeyboardMonitor()
        
        // QuickReminders activated
    }
    
    func deactivate() {
        // If the app isn't started yet, return from the function (like Snap)
        guard isStarted else {
            // App not started yet, skipping deactivation
            return
        }
        
        guard isActive else { 
            // Deactivation called but app is not active, skipping
            return 
        }
        
        // Deactivating Spotlight-like interface
        
        // Set inactive first to prevent race conditions
        isActive = false
        
        // Hide the floating window first
        floatingWindowManager.hideFloatingWindow()
        
        // Remove keyboard monitoring safely
        removeKeyboardMonitor()
        
        // Return to background mode safely
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
            NSApp.hide(nil)
        }
        
        // QuickReminders deactivated
    }


    
    // MARK: - Keyboard Event Monitoring (like Snap)
    
    private func addKeyboardMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // The escape key was pressed - deactivate like Spotlight (following Snap's pattern)
            if event.keyCode == 53 { // kVK_Escape
                // Post a notification first (like Snap does)
                NotificationCenter.default.post(name: .escapeKeyWasPressed, object: nil)
                
                // Close the window
                self?.deactivate()
                
                // Return from the closure
                return nil
            }
            
            // Send notifications for other special keys that the floating window can respond to
            switch event.keyCode {
            case 126: // kVK_UpArrow
                NotificationCenter.default.post(name: .upArrowPressed, object: nil)
                return nil
            case 125: // kVK_DownArrow
                NotificationCenter.default.post(name: .downArrowPressed, object: nil)
                return nil
            case 36: // kVK_Return
                NotificationCenter.default.post(name: .returnPressed, object: nil)
                return nil
            case 48: // kVK_Tab
                NotificationCenter.default.post(name: .tabPressed, object: nil)
                return nil
            default:
                break
            }
            
            return event
        }
    }
    
    private func removeKeyboardMonitor() {
        // Unwrap the monitor (like Snap's pattern)
        // The monitor should never be nil because normally addKeyboardMonitor is called before removing
        // To avoid crashes because of mistakes, it's an optional anyway
        guard let monitor = monitor else {
            // No keyboard monitor to remove
            return 
        }
        
        // Remove the event monitor
        NSEvent.removeMonitor(monitor)
        
        // Set the monitor to nil to avoid crashing if the app deactivates for a reason not related to the search bar
        self.monitor = nil
        // Keyboard monitor removed safely
    }
    
}
