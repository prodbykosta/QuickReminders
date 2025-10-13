//
//  ListSettingsView.swift
//  QuickReminders
//
//  Created by QuickReminders on 04.10.2025.
//

import SwiftUI
import EventKit

struct ListSettingsView: View {
    @ObservedObject var reminderManager: ReminderManager
    @ObservedObject var colorTheme: ColorThemeManager
    
    var body: some View {
        PreferencesSection(title: "Reminder Lists") {
            VStack(alignment: .leading, spacing: 20) {
                Text("Choose which reminder list to use by default and customize the interface colors.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !reminderManager.availableLists.isEmpty {
                    // Current selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Default List")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if let selectedList = reminderManager.selectedList {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(selectedList.cgColor))
                                    .frame(width: 20, height: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selectedList.title)
                                        .font(.system(size: 16, weight: .medium))
                                    Text("All new reminders will be added to this list")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(colorTheme.successColor)
                                    .font(.system(size: 18))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(selectedList.cgColor).opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(selectedList.cgColor).opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Available lists
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Lists")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Click on any list to set it as default")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(reminderManager.availableLists, id: \.calendarIdentifier) { list in
                                Button(action: { selectList(list) }) {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color(list.cgColor))
                                            .frame(width: 16, height: 16)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(list.title)
                                                .font(.system(size: 14, weight: .medium))
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
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        list == reminderManager.selectedList ? 
                                        Color(list.cgColor).opacity(0.08) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                list == reminderManager.selectedList ? 
                                                Color(list.cgColor).opacity(0.2) : Color.clear,
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Interface customization
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Interface Colors")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("The search bar border will adapt to your selected list's color")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Selected List Color:")
                                .frame(width: 140, alignment: .leading)
                            
                            if let selectedList = reminderManager.selectedList {
                                Circle()
                                    .fill(Color(selectedList.cgColor))
                                    .frame(width: 24, height: 24)
                                Text(selectedList.title)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 24, height: 24)
                                Text("No list selected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                } else {
                    // No lists available
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        Text("No Reminder Lists Available")
                            .font(.headline)
                        
                        Text("Make sure you have granted Reminders access and have at least one list in the Reminders app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Refresh Lists") {
                            Task {
                                await reminderManager.reloadReminderLists()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
        }
    }
    
    private func selectList(_ list: EKCalendar) {
        reminderManager.selectedList = list
        
        // Update the color theme to match the selected list
        if let cgColor = list.cgColor {
            colorTheme.selectedListColor = Color(cgColor)
            colorTheme.saveColors()
        }
        
        // Save the selected list to UserDefaults for persistence
        UserDefaults.standard.set(list.calendarIdentifier, forKey: "SelectedListIdentifier")
        
        // Selected list
    }
}