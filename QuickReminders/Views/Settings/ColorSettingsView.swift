//
//  ColorSettingsView.swift
//  QuickReminders
//
//  Created by QuickReminders on 04.10.2025.
//

import SwiftUI

struct ColorSettingsView: View {
    @ObservedObject var colorTheme: ColorThemeManager
    
    var body: some View {
        PreferencesSection(title: "Color Theme") {
            VStack(alignment: .leading, spacing: 20) {
                Text("Customize the colors used throughout QuickReminders for success, error, and accent highlights.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Color preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preview")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 16) {
                        // Success preview
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorTheme.successColor)
                                .frame(width: 60, height: 40)
                            Text("Success")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Error preview
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorTheme.errorColor)
                                .frame(width: 60, height: 40)
                            Text("Error")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Primary preview
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorTheme.primaryColor)
                                .frame(width: 60, height: 40)
                            Text("Primary")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Divider()
                
                // Color pickers
                VStack(alignment: .leading, spacing: 16) {
                    Text("Custom Colors")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Success Color:")
                                .frame(width: 120, alignment: .leading)
                            ColorPicker("", selection: $colorTheme.successColor)
                                .labelsHidden()
                                .frame(width: 50)
                            Text("Used for successful operations and confirmations")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Error Color:")
                                .frame(width: 120, alignment: .leading)
                            ColorPicker("", selection: $colorTheme.errorColor)
                                .labelsHidden()
                                .frame(width: 50)
                            Text("Used for errors and warnings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Primary Color:")
                                .frame(width: 120, alignment: .leading)
                            ColorPicker("", selection: $colorTheme.primaryColor)
                                .labelsHidden()
                                .frame(width: 50)
                            Text("Used for highlights and accents")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                
                Divider()
                
                // Preset themes
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preset Themes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Choose from beautifully crafted color combinations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(ColorTheme.presets, id: \.name) { theme in
                            Button(action: { colorTheme.applyTheme(theme) }) {
                                VStack(spacing: 8) {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(theme.successColor)
                                            .frame(width: 16, height: 16)
                                        Circle()
                                            .fill(theme.errorColor)
                                            .frame(width: 16, height: 16)
                                        Circle()
                                            .fill(theme.primaryColor)
                                            .frame(width: 16, height: 16)
                                    }
                                    Text(theme.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(theme.primaryColor.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Divider()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Save Colors") {
                        colorTheme.saveColors()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Reset to Default") {
                        colorTheme.resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}