import Cocoa
import SwiftUI
import Combine
import Carbon.HIToolbox.Events

struct KeyboardShortcut {
    let key: CarbonKey
    let modifiers: [CarbonKeyboardShortcutModifier]
    let carbonModifiers: UInt32
    let id: UInt32
    
    init(key: CarbonKey, modifiers: [CarbonKeyboardShortcutModifier]) {
        self.key = key
        self.modifiers = modifiers
        self.carbonModifiers = modifiers.reduce(0) { result, modifier in
            result | modifier.carbonFlag
        }
        self.id = UInt32.random(in: 1000...9999)
    }
}

struct CarbonKey {
    let keyCode: UInt32
    let character: String
    
    static let z = CarbonKey(keyCode: UInt32(kVK_ANSI_Z), character: "Z")
    static let space = CarbonKey(keyCode: UInt32(kVK_Space), character: "Space")
}

enum CarbonKeyboardShortcutModifier {
    case command
    case shift
    case option
    case control
    
    var carbonFlag: UInt32 {
        switch self {
        case .command: return UInt32(cmdKey)
        case .shift: return UInt32(shiftKey)
        case .option: return UInt32(optionKey)
        case .control: return UInt32(controlKey)
        }
    }
    
    var displaySymbol: String {
        switch self {
        case .command: return "⌘"
        case .shift: return "⇧"
        case .option: return "⌥"
        case .control: return "⌃"
        }
    }
}

class HotKeyManager: ObservableObject {
    @Published var currentHotKey: String = "⌃⇧Z"
    var onHotKeyPressed: (() -> Void)?
    
    private var keyboardShortcut: KeyboardShortcut
    private var eventHandler: EventHandlerRef?
    private var currentHotKeyRef: EventHotKeyRef?
    private var notificationObserver: NSObjectProtocol?
    
    init() {
        // Load saved hotkey from UserDefaults or use default
        if let savedModifiers = UserDefaults.standard.array(forKey: "HotKeyModifiers") as? [UInt],
           let savedKeyCode = UserDefaults.standard.object(forKey: "HotKeyCode") as? Int,
           let savedCharacter = UserDefaults.standard.string(forKey: "HotKeyCharacter") {
            
            // Convert saved modifiers back to Carbon modifiers
            var carbonModifiers: [CarbonKeyboardShortcutModifier] = []
            for modifier in savedModifiers {
                switch NSEvent.ModifierFlags(rawValue: modifier) {
                case .command: carbonModifiers.append(.command)
                case .shift: carbonModifiers.append(.shift)
                case .option: carbonModifiers.append(.option)
                case .control: carbonModifiers.append(.control)
                default: break
                }
            }
            
            let carbonKey = CarbonKey(keyCode: UInt32(savedKeyCode), character: savedCharacter)
            keyboardShortcut = KeyboardShortcut(key: carbonKey, modifiers: carbonModifiers)
            
            // Loaded saved hotkey with modifiers
        } else {
            // Default to Ctrl+Shift+Z like Spotlight uses Cmd+Space
            keyboardShortcut = KeyboardShortcut(
                key: .z,
                modifiers: [.control, .shift]
            )
            // Using default hotkey: Ctrl+Shift+Z
        }
        
        updateDisplayString()
        setupCarbonHotKey()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshHotKeyMonitoring),
            name: .accessibilityPermissionChanged,
            object: nil
        )
    }
    
    deinit {
        removeCarbonHotKey()
    }
    
    private func updateDisplayString() {
        let modifierString = keyboardShortcut.modifiers
            .map { $0.displaySymbol }
            .joined()
        currentHotKey = modifierString + keyboardShortcut.key.character
    }
    
    private func setupCarbonHotKey() {
        // Check if we have accessibility permissions
        let trusted = AXIsProcessTrusted()
        
        if !trusted {
            // Cannot setup global hotkey - accessibility permissions required
            return
        }
        
        // Setting up Carbon-based global hotkey
        
        // Create a HotKey ID
        let eventHotKeyID = EventHotKeyID(
            signature: FourCharCode(1397966955),
            id: keyboardShortcut.id
        )
        
        // Unregister any existing hotkey first
        if let existingHotKey = currentHotKeyRef {
            UnregisterEventHotKey(existingHotKey)
            currentHotKeyRef = nil
        }
        
        // Register the shortcut using Carbon API
        var eventHotKey: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyboardShortcut.key.keyCode,
            keyboardShortcut.carbonModifiers,
            eventHotKeyID,
            GetEventDispatcherTarget(),
            0,
            &eventHotKey
        )
        
        if status != noErr {
            // Failed to register hotkey
            return
        }
        
        // Store the hotkey reference for safe cleanup
        currentHotKeyRef = eventHotKey
        
        // Event specification for HotKey events
        var eventSpecification = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        ]
        
        // Install an event handler
        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                
                // Get the EventHotKeyID from the event
                GetEventParameter(
                    event,
                    UInt32(kEventParamDirectObject),
                    UInt32(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                // Post a Notification with the ID
                NotificationCenter.default.post(
                    name: NSNotification.Name("HotKeyWithID\(hotKeyID.id)"),
                    object: nil
                )
                
                return 0
            },
            1,
            &eventSpecification,
            nil,
            &eventHandler
        )
        
        if installStatus != noErr {
            // Failed to install event handler
            return
        }
        
        // Remove existing notification observer
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        
        // Listen for the notification
        notificationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("HotKeyWithID\(eventHotKeyID.id)"),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            // Carbon hotkey triggered
            DispatchQueue.main.async {
                self?.onHotKeyPressed?()
            }
        }
        
        // Carbon-based hotkey setup complete
    }
    
    private func removeCarbonHotKey() {
        // Safely removing Carbon hotkey
        
        // Unregister the hotkey first
        if let hotKeyRef = currentHotKeyRef {
            let status = UnregisterEventHotKey(hotKeyRef)
            if status == noErr {
                // Hotkey unregistered successfully
            } else {
                // Failed to unregister hotkey
            }
            currentHotKeyRef = nil
        }
        
        // Remove event handler
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
            // Event handler removed
        }
        
        // Remove notification observer safely
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
            // Notification observer removed
        }
        
        // Carbon hotkey cleanup complete
    }
    
    @objc func refreshHotKeyMonitoring() {
        // Refreshing Carbon hotkey
        removeCarbonHotKey()
        setupCarbonHotKey()
    }
    
    // Legacy method for compatibility with SettingsView
    func setupHotKey(modifiers: [NSEvent.ModifierFlags], keyCode: UInt16) {
        // Convert NSEvent modifiers to Carbon modifiers
        var carbonModifiers: [CarbonKeyboardShortcutModifier] = []
        let combinedModifiers = NSEvent.ModifierFlags(modifiers)
        
        if combinedModifiers.contains(.command) {
            carbonModifiers.append(.command)
        }
        if combinedModifiers.contains(.shift) {
            carbonModifiers.append(.shift)
        }
        if combinedModifiers.contains(.option) {
            carbonModifiers.append(.option)
        }
        if combinedModifiers.contains(.control) {
            carbonModifiers.append(.control)
        }
        
        // Create carbon key from keyCode
        let carbonKey = CarbonKey(keyCode: UInt32(keyCode), character: keyCodeToCharacter(keyCode))
        
        // Remove existing hotkey
        removeCarbonHotKey()
        
        // Create new keyboard shortcut
        keyboardShortcut = KeyboardShortcut(key: carbonKey, modifiers: carbonModifiers)
        updateDisplayString()
        
        // Setup the new hotkey
        setupCarbonHotKey()
    }
    
    private func keyCodeToCharacter(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Escape"
        default: return "Unknown"
        }
    }
}