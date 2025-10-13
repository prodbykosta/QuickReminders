//
//  HelpSettingsView.swift
//  QuickReminders
//
//  Created by QuickReminders on 05.10.2025.
//

import SwiftUI

struct HelpSettingsView: View {
    @ObservedObject var colorTheme: ColorThemeManager
    
    var body: some View {
        PreferencesSection(title: "Help & Usage") {
            // App Overview
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("How to Use QuickReminders")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("QuickReminders uses natural language to create reminders. Just type what you want to be reminded about and when!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Basic Usage Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Basic Examples:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ExampleRow(
                                command: "Buy groceries tomorrow at 3pm",
                                description: "Creates a reminder for tomorrow at 3:00 PM"
                            )
                            
                            ExampleRow(
                                command: "Call mom friday 9:30am",
                                description: "Creates a reminder for Friday at 9:30 AM"
                            )
                            
                            ExampleRow(
                                command: "Doctor appointment 6.10 at 2:15pm",
                                description: "Creates a reminder for October 6th at 2:15 PM"
                            )
                            
                            ExampleRow(
                                command: "Meeting on monday 10am",
                                description: "Creates a reminder for Monday at 10:00 AM"
                            )
                            
                            ExampleRow(
                                command: "Refund in 2 days",
                                description: "Creates a reminder 2 days from now at 9:00 AM"
                            )
                            
                            ExampleRow(
                                command: "Recycling out Tuesday evening",
                                description: "Creates a reminder for Tuesday at 6:00 PM"
                            )
                            
                            ExampleRow(
                                command: "Bills tomorrow at 9:15 every month",
                                description: "Creates monthly recurring reminder starting tomorrow"
                            )
                            
                            ExampleRow(
                                command: "Take out trash in 3 days at 9:34 every 3 days",
                                description: "Creates recurring reminder starting in 3 days, then every 3 days"
                            )
                            
                            ExampleRow(
                                command: "Meeting tm at 2pm every week",
                                description: "Creates weekly recurring reminder starting tomorrow"
                            )
                            
                            ExampleRow(
                                command: "Workout in 1 week at 6:30am every day",
                                description: "Creates daily recurring reminder starting in 1 week"
                            )
                            
                            ExampleRow(
                                command: "Medicine tomorrow at 8am every day",
                                description: "Creates daily recurring reminder starting tomorrow"
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Moving/Editing Reminders Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Moving & Editing Reminders:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ExampleRow(
                                command: "move Buy groceries to saturday 4pm",
                                description: "Moves the reminder to Saturday at 4:00 PM"
                            )
                            
                            ExampleRow(
                                command: "mv Doctor appointment to 9/15 11:30am",
                                description: "Moves the reminder to September 15th at 11:30 AM"
                            )
                            
                            ExampleRow(
                                command: "reschedule Meeting to tomorrow 2pm",
                                description: "Reschedules the reminder to tomorrow at 2:00 PM"
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Removing Reminders Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Removing Reminders:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ExampleRow(
                                command: "remove Buy groceries",
                                description: "Deletes the 'Buy groceries' reminder"
                            )
                            
                            ExampleRow(
                                command: "rm Doctor appointment",
                                description: "Deletes the 'Doctor appointment' reminder"
                            )
                            
                            ExampleRow(
                                command: "delete Meeting",
                                description: "Deletes the 'Meeting' reminder"
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Viewing Reminders Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Viewing Reminders:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ExampleRow(
                                command: "list",
                                description: "Shows all active reminders in an expandable window"
                            )
                            
                            ExampleRow(
                                command: "ls today",
                                description: "Shows only today's reminders"
                            )
                            
                            ExampleRow(
                                command: "list scheduled",
                                description: "Shows all upcoming scheduled reminders"
                            )
                            
                            ExampleRow(
                                command: "ls overdue",
                                description: "Shows overdue reminders"
                            )
                            
                            ExampleRow(
                                command: "list completed",
                                description: "Shows completed reminders"
                            )
                            
                            ExampleRow(
                                command: "ls reminders",
                                description: "Shows reminders from a specific list (by list name)"
                            )
                            
                            ExampleRow(
                                command: "ls this week",
                                description: "Shows reminders for this week"
                            )
                            
                            ExampleRow(
                                command: "list this month",
                                description: "Shows reminders for this month"
                            )
                            
                            ExampleRow(
                                command: "ls next week",
                                description: "Shows reminders for next week"
                            )
                            
                            ExampleRow(
                                command: "list next month",
                                description: "Shows reminders for next month"
                            )
                            
                            ExampleRow(
                                command: "ls monday",
                                description: "Shows reminders for any Monday"
                            )
                            
                            ExampleRow(
                                command: "list next friday",
                                description: "Shows reminders for next Friday specifically"
                            )
                            
                            ExampleRow(
                                command: "ls this monday",
                                description: "Shows reminders for this Monday"
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Supported Time Formats Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Supported Time & Date Formats:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FormatRow(title: "Days:", examples: "today, td, tomorrow, tm, monday, tue, wed, etc.")
                            FormatRow(title: "Times:", examples: "9am, 3:45pm, 21:30, 5:46, morning, evening, noon")
                            FormatRow(title: "Dates:", examples: "6.10, 6/10, 06/10, in 2 days, Tuesday evening")
                            FormatRow(title: "Recurring:", examples: "every day, every 2 weeks, every month, every 3 days")
                            FormatRow(title: "Time Periods:", examples: "in 3 days, next week, this month, this friday")
                            FormatRow(title: "Commands:", examples: "move, mv, remove, rm, delete, reschedule, list, ls")
                        }
                    }
                    
                    Divider()
                    
                    // Tips Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pro Tips:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TipRow(tip: "Use Cmd+Space (or your custom hotkey) to quickly open QuickReminders from anywhere")
                            TipRow(tip: "You can combine dates and times: '6.10 9:45am' or '9:45am 6.10'")
                            TipRow(tip: "Partial task names work for moving/removing: 'mv groceries to friday'")
                            TipRow(tip: "Enable Color Helpers in settings to see syntax highlighting while typing")
                            TipRow(tip: "Set your default AM/PM preference for ambiguous times like '5:46'")
                            TipRow(tip: "Use 'list' or 'ls' commands to view reminders: 'list today', 'ls scheduled', 'list overdue'")
                            TipRow(tip: "List by specific days: 'ls monday', 'list this friday', 'ls next tuesday'")
                            TipRow(tip: "Toggle shortcuts on/off in General settings - when off, 'rm' becomes normal text")
                            TipRow(tip: "Shortcuts include: mv/rm/ls for commands, tm/td/mon/tue/etc for days")
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
        }
    }
}

struct ExampleRow: View {
    let command: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\"")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .medium))
                
                // Apply syntax highlighting to command text
                SyntaxHighlightedText(command)
                
                Text("\"")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
            }
            
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.leading, 16)
        }
    }
}

struct SyntaxHighlightedText: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(highlightedComponents(), id: \.0) { component in
                Text(component.1)
                    .foregroundColor(component.2)
                    .font(.system(size: 14, weight: .medium))
            }
        }
    }
    
    private func highlightedComponents() -> [(Int, String, Color)] {
        var components: [(Int, String, Color)] = []
        var index = 0
        
        // Split text into words
        let words = text.split(separator: " ", omittingEmptySubsequences: true)
        
        for (wordIndex, word) in words.enumerated() {
            let wordStr = String(word)
            let color = getColorForWord(wordStr)
            components.append((index, wordStr, color))
            index += 1
            
            // Add space between words (except for last word)
            if wordIndex < words.count - 1 {
                components.append((index, " ", .primary))
                index += 1
            }
        }
        
        return components
    }
    
    private func getColorForWord(_ word: String) -> Color {
        let lowercased = word.lowercased()
        
        // Commands (blue)
        if ["move", "mv", "remove", "rm", "delete", "reschedule", "list", "ls"].contains(lowercased) {
            return .blue
        }
        
        // Connectors (purple)
        if ["to", "at", "on", "from", "by"].contains(lowercased) {
            return .purple
        }
        
        // Days (yellow)
        if ["today", "td", "tomorrow", "tm", "monday", "mon", "tuesday", "tue", "wednesday", "wed", "thursday", "thu", "friday", "fri", "saturday", "sat", "sunday", "sun"].contains(lowercased) {
            return .yellow
        }
        
        // Time patterns (red)
        if word.contains(":") || word.hasSuffix("am") || word.hasSuffix("pm") {
            return .red
        }
        
        // Until keyword and years (green)
        if lowercased == "until" {
            return .green
        }
        if word.count == 4 && word.allSatisfy({ $0.isNumber }) {
            return .green
        }
        
        // Recurring patterns (brown) - check for "every X days/weeks/months" patterns
        if lowercased == "every" {
            return .brown
        }
        // Check for time unit words - context matters!
        // For now, we'll color them brown (recurring) by default
        // In a perfect world, we'd check context to distinguish "in 3 days" (orange) vs "every 3 days" (brown)
        if ["day", "days", "week", "weeks", "month", "months"].contains(lowercased) {
            return .brown
        }
        
        // Time period filters (orange)
        if ["this", "next"].contains(lowercased) {
            return .orange
        }
        
        // Check for time period patterns (orange) - "in X days"
        if lowercased == "in" {
            return .orange
        }
        
        
        // Date patterns (yellow)
        if word.contains(".") && word.contains(where: { $0.isNumber }) {
            return .yellow
        }
        if word.contains("/") && word.contains(where: { $0.isNumber }) {
            return .yellow
        }
        
        // Default color
        return .primary
    }
}

struct FormatRow: View {
    let title: String
    let examples: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading) // Increased width
            
            if title == "Commands:" {
                // Show syntax highlighted commands
                HStack(spacing: 0) {
                    Text("move")
                        .foregroundColor(.blue)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("mv")
                        .foregroundColor(.blue)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("remove")
                        .foregroundColor(.blue)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("rm")
                        .foregroundColor(.blue)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("delete")
                        .foregroundColor(.blue)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("reschedule")
                        .foregroundColor(.blue)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("list")
                        .foregroundColor(.blue)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("ls")
                        .foregroundColor(.blue)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
            } else if title == "Recurring:" {
                // Show syntax highlighted recurring patterns
                HStack(spacing: 0) {
                    Text("every day")
                        .foregroundColor(.brown)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("every 2 weeks")
                        .foregroundColor(.brown)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("every month")
                        .foregroundColor(.brown)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("every 3 days")
                        .foregroundColor(.brown)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
            } else if title == "Days:" {
                // Show syntax highlighted days - wrap text properly
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 0) {
                        Text("today")
                            .foregroundColor(.yellow)
                            .font(.system(size: 13, weight: .medium))
                        Text(", ")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                        Text("td")
                            .foregroundColor(.yellow)
                            .font(.system(size: 13, weight: .medium))
                        Text(", ")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                        Text("tomorrow")
                            .foregroundColor(.yellow)
                            .font(.system(size: 13, weight: .medium))
                        Text(", ")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                        Text("tm")
                            .foregroundColor(.yellow)
                            .font(.system(size: 13, weight: .medium))
                        Text(", ")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                        Text("monday")
                            .foregroundColor(.yellow)
                            .font(.system(size: 13, weight: .medium))
                        Text(", ")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                        Text("tue")
                            .foregroundColor(.yellow)
                            .font(.system(size: 13, weight: .medium))
                        Text(", ")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                        Text("wed")
                            .foregroundColor(.yellow)
                            .font(.system(size: 13, weight: .medium))
                        Text(", etc.")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                        Spacer()
                    }
                }
            } else if title == "Times:" {
                // Show syntax highlighted times
                HStack(spacing: 0) {
                    Text("9am")
                        .foregroundColor(.red)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("3:45pm")
                        .foregroundColor(.red)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("21:30")
                        .foregroundColor(.red)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("5:46")
                        .foregroundColor(.red)
                        .font(.system(size: 13, weight: .medium))
                    Text(" (uses default AM/PM)")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Spacer()
                }
            } else if title == "Dates:" {
                // Show syntax highlighted dates
                HStack(spacing: 0) {
                    Text("6.10")
                        .foregroundColor(.yellow)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("6/10")
                        .foregroundColor(.yellow)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("06/10")
                        .foregroundColor(.yellow)
                        .font(.system(size: 13, weight: .medium))
                    Text(" (month.day or month/day)")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Spacer()
                }
            } else if title == "Time Periods:" {
                // Show syntax highlighted time periods
                HStack(spacing: 0) {
                    Text("in 3 days")
                        .foregroundColor(.orange)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("next week")
                        .foregroundColor(.orange)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("this month")
                        .foregroundColor(.orange)
                        .font(.system(size: 13, weight: .medium))
                    Text(", ")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                    Text("this friday")
                        .foregroundColor(.orange)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
            } else {
                Text(examples)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
    }
}

struct TipRow: View {
    let tip: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb")
                .foregroundColor(.yellow)
                .font(.system(size: 12))
                .padding(.top, 2)
            
            Text(tip)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}