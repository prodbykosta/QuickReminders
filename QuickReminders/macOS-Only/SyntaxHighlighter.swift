//
//  SyntaxHighlighter.swift
//  QuickReminders
//
//  Created by QuickReminders on 04.10.2025.
//

#if os(macOS)
import SwiftUI
import AppKit

class SyntaxHighlighter {
    
    static func highlightText(_ text: String, isEnabled: Bool = true, shortcutsEnabled: Bool = true, timePeriodsEnabled: Bool = true) -> NSAttributedString {
        guard isEnabled else {
            // Return plain text with adaptive color if highlighting is disabled
            let attributedString = NSMutableAttributedString(string: text)
            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            attributedString.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
            attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 16, weight: .medium), range: fullRange)
            return attributedString
        }
        
        let attributedString = NSMutableAttributedString(string: text)
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        
        // Set default attributes with adaptive color
        attributedString.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: 16, weight: .medium), range: fullRange)
        
        // Define color patterns - ORDER MATTERS! More specific patterns should come first
        var patterns: [(pattern: String, color: NSColor)] = []
        
        // Commands (BLUE) - only at the start of text
        if shortcutsEnabled {
            patterns.append(("^(mv|rm|move|remove|delete|reschedule|list|ls)\\b", NSColor.systemBlue))
        } else {
            patterns.append(("^(move|remove|delete|reschedule|list)\\b", NSColor.systemBlue))
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
            
            // Connectors (PURPLE) - only when followed by temporal keywords
            ("\\bat\\s+(?=\\d{1,2}" + (timePeriodsEnabled ? "|morning|afternoon|evening|night|noon" : "") + ")", NSColor.systemPurple),
            ("\\bon\\s+(?=monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun|today|tomorrow|\\d{1,2}[./]\\d{1,2})", NSColor.systemPurple),
            ("\\bin\\s+(?=\\d+\\s+(?:day|days|week|weeks|month|months)" + (timePeriodsEnabled ? "|morning|afternoon|evening" : "") + ")", NSColor.systemPurple),
            ("\\b(to|from|by)\\b", NSColor.systemPurple),
            
            // Date patterns (YELLOW) - conditional shortcuts
            (shortcutsEnabled ? 
                "\\b(today|td|tomorrow|tm|monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)\\b" :
                "\\b(today|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\\b", 
             NSColor.systemYellow),
            ("\\b\\d{1,2}[./]\\d{1,2}\\.?\\b", NSColor.systemYellow), // 6.10, 6/10, 06/10
            
            // Month names (YELLOW)
            ("\\b(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)\\b", NSColor.systemYellow),
            
            // Day numbers with ordinal suffixes after months (RED)
            ("(?<=\\b(?:january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)\\s+)\\d{1,2}(?:st|nd|rd|th)?\\b", NSColor.systemRed),
            
            // Day numbers with ordinal suffixes before "of month" (RED)
            ("\\b\\d{1,2}(?:st|nd|rd|th)?(?=\\s+of\\s+(?:january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec|this\\s+month|next\\s+month))\\b", NSColor.systemRed),
            
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
        ])
        
        // Add time periods pattern only if enabled
        if timePeriodsEnabled {
            patterns.append(("\\b(morning|afternoon|evening|night|noon)\\b", NSColor.systemRed))
        }
        
        // Apply colors based on patterns
        for (pattern, color) in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
                
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
    var timePeriodsEnabled: Bool = true
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
        // Configure basic properties with emoji support
        self.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        self.focusRingType = .none
        self.isBordered = false
        self.backgroundColor = NSColor.clear
        self.allowsEditingTextAttributes = true
        
        // Enable emoji and Unicode support
        self.importsGraphics = false
        self.usesSingleLineMode = true
        
        // Ensure proper text encoding for emojis
        if let cell = self.cell as? NSTextFieldCell {
            cell.allowsUndo = true
        }
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
        let highlightedText = SyntaxHighlighter.highlightText(currentText, isEnabled: colorHelpersEnabled, shortcutsEnabled: shortcutsEnabled, timePeriodsEnabled: timePeriodsEnabled)
        
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
    
    func setTimePeriodsEnabled(_ enabled: Bool) {
        timePeriodsEnabled = enabled
        applyHighlighting()
    }
}#endif
