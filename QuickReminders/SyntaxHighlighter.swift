//
//  SyntaxHighlighter.swift
//  QuickReminders
//
//  Created by QuickReminders on 04.10.2025.
//

import SwiftUI
import AppKit

class SyntaxHighlighter {
    
    static func highlightText(_ text: String, isEnabled: Bool = true, shortcutsEnabled: Bool = true) -> NSAttributedString {
        guard isEnabled else {
            // Return plain white text if highlighting is disabled
            let attributedString = NSMutableAttributedString(string: text)
            let fullRange = NSRange(location: 0, length: text.count)
            attributedString.addAttribute(.foregroundColor, value: NSColor.white, range: fullRange)
            attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 16, weight: .medium), range: fullRange)
            return attributedString
        }
        
        let attributedString = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.count)
        
        // Set default attributes
        attributedString.addAttribute(.foregroundColor, value: NSColor.white, range: fullRange)
        attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 16, weight: .medium), range: fullRange)
        
        // Define color patterns - ORDER MATTERS! More specific patterns should come first
        var patterns: [(pattern: String, color: NSColor)] = []
        
        // Commands (BLUE) - conditional based on shortcuts setting
        if shortcutsEnabled {
            patterns.append(("\\b(mv|rm|move|remove|delete|reschedule|list|ls)\\b", NSColor.systemBlue))
        } else {
            patterns.append(("\\b(move|remove|delete|reschedule|list)\\b", NSColor.systemBlue))
        }
        
        // Add the rest of the patterns
        patterns.append(contentsOf: [
            
            // Recurring patterns (BROWN) - MOST SPECIFIC FIRST
            ("\\bevery\\s+\\d+\\s+days?\\b", NSColor.systemBrown),
            ("\\bevery\\s+\\d+\\s+weeks?\\b", NSColor.systemBrown), 
            ("\\bevery\\s+\\d+\\s+months?\\b", NSColor.systemBrown),
            ("\\bevery\\s+day\\b", NSColor.systemBrown),
            ("\\bevery\\s+week\\b", NSColor.systemBrown),
            ("\\bevery\\s+month\\b", NSColor.systemBrown),
            
            // Time period filters (ORANGE) - different from recurring
            ("\\bthis\\s+week\\b", NSColor.systemOrange),
            ("\\bthis\\s+month\\b", NSColor.systemOrange),
            ("\\bthis\\s+year\\b", NSColor.systemOrange),
            ("\\bnext\\s+week\\b", NSColor.systemOrange),
            ("\\bnext\\s+month\\b", NSColor.systemOrange),
            ("\\bnext\\s+year\\b", NSColor.systemOrange),
            
            // Specific day combinations (ORANGE) - conditional based on shortcuts
            (shortcutsEnabled ? 
                "\\bthis\\s+(monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)\\b" :
                "\\bthis\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\\b", 
             NSColor.systemOrange),
            (shortcutsEnabled ? 
                "\\bnext\\s+(monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)\\b" :
                "\\bnext\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\\b", 
             NSColor.systemOrange),
            
            // Relative time periods (ORANGE) - "in X days" patterns
            ("\\bin\\s+\\d+\\s+days?\\b", NSColor.systemOrange),
            ("\\bin\\s+\\d+\\s+weeks?\\b", NSColor.systemOrange),
            ("\\bin\\s+\\d+\\s+months?\\b", NSColor.systemOrange),
            
            // Until keyword and years (GREEN)
            ("\\buntil\\b", NSColor.systemGreen),
            ("\\b\\d{4}\\b", NSColor.systemGreen), // Years like 2025, 2026
            
            // Connectors (PURPLE) 
            ("\\b(at|on|to|from|by|in)\\b", NSColor.systemPurple),
            
            // Date patterns (YELLOW) - conditional shortcuts
            (shortcutsEnabled ? 
                "\\b(today|td|tomorrow|tm|monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)\\b" :
                "\\b(today|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\\b", 
             NSColor.systemYellow),
            ("\\b\\d{1,2}[./]\\d{1,2}\\.?\\b", NSColor.systemYellow), // 6.10, 6/10, 06/10
            
            // Time patterns (RED)
            ("(?<=\\bat\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "at" only
            ("(?<=\\btomorrow\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "tomorrow"
            ("(?<=\\btm\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "tm"
            ("(?<=\\btoday\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "today"  
            ("(?<=\\btd\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "td"
            ("(?<=\\bmonday\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "monday"
            ("(?<=\\bmon\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "mon"
            ("(?<=\\btuesday\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "tuesday"
            ("(?<=\\btue\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "tue"
            ("(?<=\\bwednesday\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "wednesday"
            ("(?<=\\bwed\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "wed"
            ("(?<=\\bthursday\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "thursday"
            ("(?<=\\bthu\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "thu"
            ("(?<=\\bfriday\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "friday"
            ("(?<=\\bfri\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "fri"
            ("(?<=\\bsaturday\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "saturday"
            ("(?<=\\bsat\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "sat"
            ("(?<=\\bsunday\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "sunday"
            ("(?<=\\bsun\\s)\\d{1,2}\\b", NSColor.systemRed), // numbers after "sun"
            ("\\b\\d{1,2}:\\d{2}\\s*(am|pm|AM|PM)?\\b", NSColor.systemRed), // 9:45pm, 21:30
            ("\\b\\d{1,2}\\s*(am|pm|AM|PM)\\b", NSColor.systemRed), // 9pm, 9AM
            ("\\b(morning|afternoon|evening|night|noon)\\b", NSColor.systemRed), // Time periods
        ])
        
        // Apply colors based on patterns
        for (pattern, color) in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
                
                for match in matches {
                    attributedString.addAttribute(.foregroundColor, value: color, range: match.range)
                    // Preserve font attribute when setting color
                    attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 16, weight: .medium), range: match.range)
                }
            } catch {
                // Silently continue if regex pattern fails
            }
        }
        
        return attributedString
    }
}

// Custom NSTextField that supports attributed strings and real-time highlighting
class HighlightedTextField: NSTextField {
    var colorHelpersEnabled: Bool = true
    var shortcutsEnabled: Bool = true
    var onTextChange: ((String) -> Void)?
    private var isUpdatingInternally = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTextField()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTextField()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextField()
    }
    
    private func setupTextField() {
        // Configure basic properties
        self.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        self.focusRingType = .none
        self.isBordered = false
        self.backgroundColor = NSColor.clear
        self.allowsEditingTextAttributes = true
    }
    
    override func textDidChange(_ notification: Notification) {
        guard !isUpdatingInternally else { return }
        
        super.textDidChange(notification)
        
        let currentText = self.stringValue
        
        applyHighlighting()
        
        // Notify delegate of text change
        onTextChange?(currentText)
    }
    
    private func applyHighlighting() {
        guard let textView = self.currentEditor() as? NSTextView else { return }
        
        let currentText = self.stringValue
        let selectedRange = textView.selectedRange
        
        isUpdatingInternally = true
        
        // Apply syntax highlighting
        let highlightedText = SyntaxHighlighter.highlightText(currentText, isEnabled: colorHelpersEnabled, shortcutsEnabled: shortcutsEnabled)
        
        // Update the text storage
        textView.textStorage?.setAttributedString(highlightedText)
        
        // Restore cursor position
        textView.selectedRange = selectedRange
        
        isUpdatingInternally = false
    }
    
    func updateText(_ text: String) {
        self.stringValue = text
        applyHighlighting()
    }
    
    func setColorHelpersEnabled(_ enabled: Bool) {
        colorHelpersEnabled = enabled
        applyHighlighting()
    }
    
    func setShortcutsEnabled(_ enabled: Bool) {
        shortcutsEnabled = enabled
        applyHighlighting()
    }
}