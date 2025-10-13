//
//  HotkeySettingsView.swift
//  QuickReminders
//
//  Created by QuickReminders on 04.10.2025.
//

import SwiftUI

struct HotkeySettingsView: View {
    @ObservedObject var hotKeyManager: HotKeyManager
    @State private var selectedModifiers: [NSEvent.ModifierFlags] = [.control, .shift]
    @State private var selectedKey = "Z"
    
    private let availableKeys = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "Space", "Return"]
    
    var body: some View {
        PreferencesSection(title: "Global Hotkey") {
            VStack(alignment: .leading, spacing: 16) {
                Text("Configure the global keyboard shortcut to activate QuickReminders from anywhere.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Current hotkey display
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Hotkey")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(hotKeyManager.currentHotKey)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
                
                Divider()
                
                // Hotkey configuration
                VStack(alignment: .leading, spacing: 16) {
                    Text("Configure New Hotkey")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Modifiers:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                Toggle("⌘", isOn: Binding(
                                    get: { selectedModifiers.contains(.command) },
                                    set: { if $0 { selectedModifiers.append(.command) } else { selectedModifiers.removeAll { $0 == .command } } }
                                ))
                                .toggleStyle(HotkeyToggleStyle())
                                
                                Toggle("⇧", isOn: Binding(
                                    get: { selectedModifiers.contains(.shift) },
                                    set: { if $0 { selectedModifiers.append(.shift) } else { selectedModifiers.removeAll { $0 == .shift } } }
                                ))
                                .toggleStyle(HotkeyToggleStyle())
                                
                                Toggle("⌥", isOn: Binding(
                                    get: { selectedModifiers.contains(.option) },
                                    set: { if $0 { selectedModifiers.append(.option) } else { selectedModifiers.removeAll { $0 == .option } } }
                                ))
                                .toggleStyle(HotkeyToggleStyle())
                                
                                Toggle("⌃", isOn: Binding(
                                    get: { selectedModifiers.contains(.control) },
                                    set: { if $0 { selectedModifiers.append(.control) } else { selectedModifiers.removeAll { $0 == .control } } }
                                ))
                                .toggleStyle(HotkeyToggleStyle())
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Key:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Key", selection: $selectedKey) {
                                ForEach(availableKeys, id: \.self) { key in
                                    Text(key).tag(key)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 120)
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button("Apply Hotkey") {
                            applyHotkey()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedModifiers.isEmpty)
                        
                        Button("Reset to Default") {
                            resetToDefault()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Divider()
                
                // Help text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text("• Choose a unique combination to avoid conflicts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• Hotkey changes are applied instantly")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• Make sure Accessibility permissions are granted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() {
        if let savedModifiers = UserDefaults.standard.array(forKey: "HotKeyModifiers") as? [UInt] {
            selectedModifiers = savedModifiers.map { NSEvent.ModifierFlags(rawValue: $0) }
        } else {
            selectedModifiers = [.control, .shift]
        }
        
        if let savedCharacter = UserDefaults.standard.string(forKey: "HotKeyCharacter") {
            selectedKey = savedCharacter
        } else {
            selectedKey = "Z"
        }
    }
    
    private func applyHotkey() {
        // Save the new hotkey to UserDefaults
        let keyCode = keyCodeForString(selectedKey)
        UserDefaults.standard.set(selectedModifiers.map { $0.rawValue }, forKey: "HotKeyModifiers")
        UserDefaults.standard.set(Int(keyCode), forKey: "HotKeyCode")
        UserDefaults.standard.set(selectedKey, forKey: "HotKeyCharacter")
        
        // Apply the new hotkey instantly
        hotKeyManager.setupHotKey(modifiers: selectedModifiers, keyCode: keyCode)
    }
    
    private func resetToDefault() {
        selectedModifiers = [.control, .shift]
        selectedKey = "Z"
        applyHotkey()
    }
    
    private func keyCodeForString(_ key: String) -> UInt16 {
        switch key {
        case "A": return 0
        case "B": return 11
        case "C": return 8
        case "D": return 2
        case "E": return 14
        case "F": return 3
        case "G": return 5
        case "H": return 4
        case "I": return 34
        case "J": return 38
        case "K": return 40
        case "L": return 37
        case "M": return 46
        case "N": return 45
        case "O": return 31
        case "P": return 35
        case "Q": return 12
        case "R": return 15
        case "S": return 1
        case "T": return 17
        case "U": return 32
        case "V": return 9
        case "W": return 13
        case "X": return 7
        case "Y": return 16
        case "Z": return 6
        case "Space": return 49
        case "Return": return 36
        default: return 15
        }
    }
}

struct HotkeyToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            configuration.label
                .foregroundColor(configuration.isOn ? .white : .primary)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 32, height: 24)
                .background(configuration.isOn ? Color.accentColor : Color.gray.opacity(0.2))
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
