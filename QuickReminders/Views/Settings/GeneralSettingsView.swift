//
//  GeneralSettingsView.swift
//  QuickReminders
//
//  Created by QuickReminders on 04.10.2025.
//

import SwiftUI
import EventKit

struct GeneralSettingsView: View {
    @ObservedObject var reminderManager: ReminderManager
    @ObservedObject var colorTheme: ColorThemeManager
    
    var body: some View {
        PreferencesSection(title: "General") {
            // App Info
            VStack(alignment: .leading, spacing: 12) {
                Text("About QuickReminders")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .font(.title)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("QuickReminders")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Natural language reminders for macOS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // Reminder Permissions
            VStack(alignment: .leading, spacing: 12) {
                Text("Reminders Access")
                    .font(.headline)
                
                if reminderManager.hasAccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("✅ Reminders access granted")
                            .foregroundColor(.green)
                    }
                    Text("You can create, modify, and delete reminders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !reminderManager.availableLists.isEmpty {
                        Text("Available lists: \(reminderManager.availableLists.map { $0.title }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("⚠️ Reminders access needed")
                            .foregroundColor(.orange)
                    }
                    
                    Button("Grant Reminders Access") {
                        reminderManager.requestPermissionManually()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Text("Required to create and manage reminders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Accessibility Permissions
            VStack(alignment: .leading, spacing: 12) {
                Text("Global Hotkey Access")
                    .font(.headline)
                
                let trusted = AXIsProcessTrusted()
                
                if trusted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("✅ Accessibility permissions granted")
                            .foregroundColor(.green)
                    }
                    Text("Global hotkeys are enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("⚠️ Accessibility permissions needed for global hotkeys")
                            .foregroundColor(.orange)
                    }
                    
                    Button("Grant Accessibility Permissions") {
                        requestAccessibilityPermissions()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Text("Required for global hotkey to work from anywhere")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Default Time Settings
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Default Time Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default AM/PM for ambiguous times")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("When you create a reminder with a time like '5:46' (without AM/PM), this setting determines whether it defaults to morning or evening.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Default to:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 0) {
                                Button(action: { colorTheme.defaultAmPm = "AM" }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "sun.max")
                                            .font(.system(size: 16))
                                        Text("AM")
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                    .foregroundColor(colorTheme.defaultAmPm == "AM" ? .white : .blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        colorTheme.defaultAmPm == "AM" ? 
                                        Color.blue : Color.blue.opacity(0.1),
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
                                    .foregroundColor(colorTheme.defaultAmPm == "PM" ? .white : .blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        colorTheme.defaultAmPm == "PM" ? 
                                        Color.blue : Color.blue.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                            Text("Example: \"remind me at 5:46\" will create a reminder for 5:46 \(colorTheme.defaultAmPm)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Divider()
            
            // Date Format Settings
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Date Format Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date Input Format")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Choose how you want to enter dates like '10/26'. This helps prevent confusion between month/day and day/month formats.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Format:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 0) {
                                Button(action: { 
                                    colorTheme.dateFormat = .mmdd 
                                    colorTheme.saveColors()
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
                                    .foregroundColor(colorTheme.dateFormat == .mmdd ? .white : .blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        colorTheme.dateFormat == .mmdd ? 
                                        Color.blue : Color.blue.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { 
                                    colorTheme.dateFormat = .ddmm 
                                    colorTheme.saveColors()
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
                                    .foregroundColor(colorTheme.dateFormat == .ddmm ? .white : .blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        colorTheme.dateFormat == .ddmm ? 
                                        Color.blue : Color.blue.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                            Text(colorTheme.dateFormat.description)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Divider()
            
            // Color Helpers Setting
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "paintbrush")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Color Helpers")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Syntax Highlighting")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Enable color-coded text while typing to help identify different parts of your commands.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Toggle("Enable Color Helpers", isOn: $colorTheme.colorHelpersEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .onChange(of: colorTheme.colorHelpersEnabled) {
                                    colorTheme.saveColors()
                                }
                        }
                        
                        if colorTheme.colorHelpersEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Color Legend:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Commands")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("(mv, rm, move, remove, delete, reschedule)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("Connectors")
                                            .foregroundColor(.purple)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("(at, on, to, from, by)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("Dates")
                                            .foregroundColor(.yellow)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("(today, tomorrow, mon, tue, 6.10, 6/10)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("Times")
                                            .foregroundColor(.red)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("(9am, 3:45pm, 21:30)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("Recurring")
                                            .foregroundColor(.brown)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("(every 2 days, every week)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("Time Periods")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("(in 3 days, next week, this month)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.leading, 8)
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Divider()
            
            // Opening Animation Setting
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Opening Animation")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Window Appearance Effect")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Enable a smooth spring animation when the QuickReminders window opens.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Toggle("Enable Opening Animation", isOn: $colorTheme.openingAnimationEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .onChange(of: colorTheme.openingAnimationEnabled) {
                                    colorTheme.saveColors()
                                }
                        }
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                            Text(colorTheme.openingAnimationEnabled ? "Window will open with a smooth spring animation" : "Window will appear instantly")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Divider()
            
            // Command Scope Setting  
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "scope")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Command Search Scope")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Toggle("Search Only Current List", isOn: $colorTheme.searchOnlyCurrentList)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .onChange(of: colorTheme.searchOnlyCurrentList) {
                                colorTheme.saveColors()
                            }
                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        Text(colorTheme.searchOnlyCurrentList ? "mv/rm commands search only in currently selected list" : "mv/rm commands search across all reminder lists")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
            
            Divider()
            
            // Shortcuts Setting
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "command")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Command Shortcuts")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enable Shortcut Commands")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Turn off shortcuts like mv, rm, ls, tmr, td if you prefer not to use them. When disabled, these shortcuts won't be recognized in commands.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Toggle("Enable Shortcuts", isOn: $colorTheme.shortcutsEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .onChange(of: colorTheme.shortcutsEnabled) {
                                    colorTheme.saveColors()
                                }
                        }
                        
                        if colorTheme.shortcutsEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Available shortcuts:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("mv, move")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("- Move or reschedule reminders")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("rm, remove, delete")
                                            .foregroundColor(.red)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("- Delete reminders")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("ls, list")
                                            .foregroundColor(.purple)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("- List reminders")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("tmr, td")
                                            .foregroundColor(.yellow)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("- Tomorrow, today shortcuts")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.leading, 8)
                            }
                        } else {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 14))
                                Text("Shortcuts are disabled. Only full words will be recognized.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Divider()
            
            // Window Positioning Setting
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "rectangle.3.group")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Window Position")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("App Appearance Location")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Choose where the QuickReminders window appears on your screen when activated.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Position:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        // Grid of preset position options (excluding custom for now)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(WindowPosition.allCases.filter { $0 != .custom }, id: \.self) { position in
                                Button(action: {
                                    colorTheme.windowPosition = position
                                    // Set X/Y to preset coordinates when preset is selected
                                    let coords = position.coordinates
                                    colorTheme.windowPositionX = coords.x
                                    colorTheme.windowPositionY = coords.y
                                    colorTheme.saveColors()
                                }) {
                                    Text(position.displayName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(colorTheme.windowPosition == position ? .white : .blue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            colorTheme.windowPosition == position ? 
                                            Color.blue : Color.blue.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 6)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Custom position section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Button(action: {
                                    colorTheme.windowPosition = .custom
                                    colorTheme.saveColors()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.system(size: 14))
                                        Text("Custom Position")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(colorTheme.windowPosition == .custom ? .white : .blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        colorTheme.windowPosition == .custom ? 
                                        Color.blue : Color.blue.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                            }
                            
                            if colorTheme.windowPosition == .custom {
                                VStack(alignment: .leading, spacing: 16) {
                                    // X Position Slider
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("Horizontal Position")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("\(Int(colorTheme.windowPositionX * 100))%")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        HStack {
                                            Text("←")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                            
                                            Slider(value: $colorTheme.windowPositionX, in: 0...1)
                                                .accentColor(.blue)
                                                .onChange(of: colorTheme.windowPositionX) {
                                                    colorTheme.saveColors()
                                                }
                                            
                                            Text("→")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    // Y Position Slider
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("Vertical Position")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("\(Int(colorTheme.windowPositionY * 100))%")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        HStack {
                                            Text("↓")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                            
                                            Slider(value: $colorTheme.windowPositionY, in: 0...1)
                                                .accentColor(.blue)
                                                .onChange(of: colorTheme.windowPositionY) {
                                                    colorTheme.saveColors()
                                                }
                                            
                                            Text("↑")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.leading, 16)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                            if colorTheme.windowPosition == .custom {
                                Text("Custom position: \(Int(colorTheme.windowPositionX * 100))% horizontal, \(Int(colorTheme.windowPositionY * 100))% vertical")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Current: \(colorTheme.windowPosition.displayName)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private func requestAccessibilityPermissions() {
        // Requesting accessibility permissions
        
        let currentStatus = AXIsProcessTrusted()
        
        if currentStatus {
            // Accessibility permissions already granted
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "QuickReminders needs Accessibility permissions to work with global hotkeys. Click 'Open System Preferences' to grant permissions, then restart the app."
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
            
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
            AXIsProcessTrustedWithOptions(options)
        }
        
        // User needs to grant accessibility permissions manually
    }
}