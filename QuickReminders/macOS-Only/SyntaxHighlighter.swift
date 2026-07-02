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
            
            // Until keyword - DISABLED FOR NOW (not implemented yet)
            // ("\\buntil\\b", NSColor.systemGreen),
            // Years like 2025, 2026 (GREEN)
            ("\\b\\d{4}\\b", NSColor.systemGreen),
            
            // Connectors (PURPLE) - only when followed by temporal keywords
            ("\\bat\\s+(?=\\d{1,2}" + (timePeriodsEnabled ? "|morning|afternoon|evening|night|noon" : "") + ")", NSColor.systemPurple),
            ("\\bon\\s+(?=monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun|today|tomorrow|\\d{1,2}[./]\\d{1,2})", NSColor.systemPurple),
            ("\\bin\\s+(?=\\d+\\s+(?:day|days|week|weeks|month|months)" + (timePeriodsEnabled ? "|morning|afternoon|evening" : "") + ")", NSColor.systemPurple),
            // Note: "to" removed as it's not used in parser logic
            ("\\b(from|by)\\b", NSColor.systemPurple),
            
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
            
            // Hour/minute patterns (RED) - NEW
            ("\\bin\\s+\\d+\\s*(?:hours?|hrs?|h)\\b", NSColor.systemRed), // in 2 hours, in 2h
            ("\\bin\\s+\\d+\\s*(?:minutes?|mins?|min|m)\\b", NSColor.systemRed), // in 30 minutes, in 30min
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
                    // Guard against nil values to prevent crashes
                    guard match.range.location + match.range.length <= nsText.length else { continue }

                    attributedString.addAttribute(.foregroundColor, value: color, range: match.range)
                    // Preserve font attribute when setting color
                    if let font = NSFont.systemFont(ofSize: 16, weight: .medium) as NSFont? {
                        attributedString.addAttribute(.font, value: font, range: match.range)
                    }
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

    // Variable toggling support
    var parsedVariables: [ParsedVariable] = []
    var onVariableToggle: ((Int) -> Void)?
    var isEditingVariables: Bool = false

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

        // Add click gesture recognizer to intercept clicks BEFORE data detectors
        let clickRecognizer = NSClickGestureRecognizer(target: self, action: #selector(handleClickGesture(_:)))
        clickRecognizer.numberOfClicksRequired = 1
        clickRecognizer.delaysPrimaryMouseButtonEvents = false // Don't delay normal clicks
        self.addGestureRecognizer(clickRecognizer)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // Accept first mouse to receive clicks even when window is not key
        return true
    }

    override var acceptsFirstResponder: Bool {
        // Always accept first responder
        return true
    }

    @objc private func handleClickGesture(_ gesture: NSClickGestureRecognizer) {
        // Only handle clicks when in variable edit mode
        guard isEditingVariables else {
            return
        }

        // Get click location
        let clickPoint = gesture.location(in: self)

        // Wait a tiny bit for field editor to be ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let fieldEditor = self.currentEditor() as? NSTextView else {
                return
            }

            guard let layoutManager = fieldEditor.layoutManager,
                  let textContainer = fieldEditor.textContainer else {
                return
            }

            // Convert click point to text view coordinates
            let textViewPoint = fieldEditor.convert(clickPoint, from: self)

            // Get character index at click point
            let characterIndex = layoutManager.characterIndex(
                for: textViewPoint,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )

            // Check if click was inside a variable
            for (index, variable) in self.parsedVariables.enumerated() {
                let range = variable.range
                let rangeEnd = range.location + range.length

                // Check if click is within the range (inclusive start, exclusive end)
                if characterIndex >= range.location && characterIndex < rangeEnd {
                    self.onVariableToggle?(index)
                    return
                }
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
    
    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)

        // Disable data detectors on the field editor when editing starts
        if let fieldEditor = self.currentEditor() as? NSTextView {
            fieldEditor.isAutomaticDataDetectionEnabled = false
            fieldEditor.isAutomaticLinkDetectionEnabled = false
            fieldEditor.isAutomaticTextReplacementEnabled = false
            fieldEditor.isAutomaticDashSubstitutionEnabled = false
            fieldEditor.isAutomaticQuoteSubstitutionEnabled = false
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

    // Public method to manually refresh highlighting (e.g., when variables change)
    func refreshHighlighting() {
        applyHighlighting()
    }
    
    private func applyHighlighting() {
        // Only apply if not currently being updated by NSViewRepresentable
        // This prevents infinite constraint loops during window resize
        guard !isUpdatingInternally else { return }

        guard let textView = self.currentEditor() as? NSTextView else { return }

        let currentText = self.stringValue
        let selectedRange = textView.selectedRange

        isUpdatingInternally = true

        // Apply syntax highlighting
        let highlightedText = SyntaxHighlighter.highlightText(currentText, isEnabled: colorHelpersEnabled, shortcutsEnabled: shortcutsEnabled, timePeriodsEnabled: timePeriodsEnabled)

        // Convert to mutable string
        let mutableString = NSMutableAttributedString(attributedString: highlightedText)

        // Apply variable styling
        if !parsedVariables.isEmpty {
            for variable in parsedVariables {
                // Make sure range is valid
                guard variable.range.location >= 0 && variable.range.location + variable.range.length <= currentText.count else { continue }

                if variable.isOverriddenAsText {
                    // Overridden variables: RED UNDERLINE (will NOT be parsed)
                    mutableString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: variable.range)
                    mutableString.addAttribute(.underlineColor, value: NSColor.systemRed, range: variable.range)
                    // Keep original text color so it's readable
                } else if isEditingVariables {
                    // Active variables in edit mode: PURPLE background (clickable to toggle)
                    mutableString.addAttribute(.backgroundColor, value: NSColor.systemPurple.withAlphaComponent(0.2), range: variable.range)
                    mutableString.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: variable.range)
                }
                // If not in edit mode and not overridden, variable gets normal syntax highlighting
            }
        }

        // Update the text storage - guard against nil
        guard let textStorage = textView.textStorage else {
            isUpdatingInternally = false
            return
        }

        textStorage.setAttributedString(mutableString)

        // Restore cursor position
        textView.selectedRange = selectedRange

        isUpdatingInternally = false
    }

    private func colorForVariableType(_ type: ParsedVariable.VariableType) -> NSColor {
        switch type {
        case .date: return .systemBlue
        case .time: return .systemPurple
        case .number: return .systemOrange
        case .contact: return .systemGreen
        case .location: return .systemTeal
        case .recurrence: return .systemIndigo
        }
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

    // MARK: - Variable Toggling Support

    func setParsedVariables(_ variables: [ParsedVariable]) {
        parsedVariables = variables
        applyHighlighting()
    }

}#endif
