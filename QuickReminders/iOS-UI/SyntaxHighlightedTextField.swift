//
//  SyntaxHighlightedTextField.swift
//  QuickReminders - iOS
//
//  iOS syntax highlighting text field with same patterns as macOS
//

#if os(iOS)
import SwiftUI
import UIKit

// Custom UITextView with proper placeholder support
class PlaceholderTextView: UITextView {
    var placeholderText: String = "" {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var placeholderColor: UIColor = UIColor.placeholderText {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override var text: String! {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override var attributedText: NSAttributedString! {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        // Only show placeholder when text is empty
        if text.isEmpty && !placeholderText.isEmpty {
            let placeholderRect = CGRect(
                x: textContainerInset.left + textContainer.lineFragmentPadding,
                y: textContainerInset.top,
                width: rect.width - textContainerInset.left - textContainerInset.right - textContainer.lineFragmentPadding * 2,
                height: rect.height - textContainerInset.top - textContainerInset.bottom
            )
            
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: placeholderColor,
                .font: font ?? UIFont.systemFont(ofSize: 18, weight: .medium)
            ]
            
            placeholderText.draw(in: placeholderRect, withAttributes: attributes)
        }
    }
}

// Syntax highlighting helper for iOS
class IOSSyntaxHighlighter {
    
    static func highlightText(_ text: String, isEnabled: Bool = true, shortcutsEnabled: Bool = true, timePeriodsEnabled: Bool = true) -> NSAttributedString {
        guard isEnabled else {
            // Return plain text if highlighting is disabled
            let attributedString = NSMutableAttributedString(string: text)
            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
            attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 18, weight: .medium), range: fullRange)
            return attributedString
        }
        
        let attributedString = NSMutableAttributedString(string: text)
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        
        // Set default attributes
        attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
        attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 18, weight: .medium), range: fullRange)
        
        // Define color patterns - ORDER MATTERS! More specific patterns should come first
        var patterns: [(pattern: String, color: UIColor)] = []
        
        // Commands (BLUE) - only at the start of text
        if shortcutsEnabled {
            patterns.append(("^(mv|rm|move|remove|delete|reschedule|list|ls)\\b", UIColor.systemBlue))
        } else {
            patterns.append(("^(move|remove|delete|reschedule|list)\\b", UIColor.systemBlue))
        }
        
        // Add the rest of the patterns (same as macOS but with UIColor)
        patterns.append(contentsOf: [
            
            // Recurring patterns (BROWN)
            ("\\bevery\\s+\\d+\\s+days?\\b", UIColor.systemBrown),
            ("\\bevery\\s+\\d+\\s+weeks?\\b", UIColor.systemBrown), 
            ("\\bevery\\s+\\d+\\s+months?\\b", UIColor.systemBrown),
            ("\\bevery\\s+day\\b", UIColor.systemBrown),
            ("\\bevery\\s+week\\b", UIColor.systemBrown),
            ("\\bevery\\s+month\\b", UIColor.systemBrown),
            
            // Time period filters (ORANGE)
            ("\\bthis\\s+week\\b", UIColor.systemOrange),
            ("\\bthis\\s+month\\b", UIColor.systemOrange),
            ("\\bthis\\s+year\\b", UIColor.systemOrange),
            ("\\bnext\\s+week\\b", UIColor.systemOrange),
            ("\\bnext\\s+month\\b", UIColor.systemOrange),
            ("\\bnext\\s+year\\b", UIColor.systemOrange),
            
            // Specific day combinations (ORANGE)
            (shortcutsEnabled ? 
                "\\bthis\\s+(monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)\\b" :
                "\\bthis\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\\b", 
             UIColor.systemOrange),
            (shortcutsEnabled ? 
                "\\bnext\\s+(monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)\\b" :
                "\\bnext\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\\b", 
             UIColor.systemOrange),
            
            // Relative time periods (ORANGE)
            ("\\bin\\s+\\d+\\s+days?\\b", UIColor.systemOrange),
            ("\\bin\\s+\\d+\\s+weeks?\\b", UIColor.systemOrange),
            ("\\bin\\s+\\d+\\s+months?\\b", UIColor.systemOrange),
            
            // Until keyword and years (GREEN)
            ("\\buntil\\b", UIColor.systemGreen),
            ("\\b\\d{4}\\b", UIColor.systemGreen), // Years like 2025, 2026
            
            // Connectors (PURPLE)
            ("\\bat\\s+(?=\\d{1,2}" + (timePeriodsEnabled ? "|morning|afternoon|evening|night|noon" : "") + ")", UIColor.systemPurple),
            ("\\bon\\s+(?=monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun|today|tomorrow|\\d{1,2}[./]\\d{1,2})", UIColor.systemPurple),
            ("\\bin\\s+(?=\\d+\\s+(?:day|days|week|weeks|month|months)" + (timePeriodsEnabled ? "|morning|afternoon|evening" : "") + ")", UIColor.systemPurple),
            ("\\b(to|from|by)\\b", UIColor.systemPurple),
            
            // Date patterns (YELLOW)
            (shortcutsEnabled ? 
                "\\b(today|td|tomorrow|tm|monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)\\b" :
                "\\b(today|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\\b", 
             UIColor.systemYellow),
            ("\\b\\d{1,2}[./]\\d{1,2}\\.?\\b", UIColor.systemYellow), // 6.10, 6/10, 06/10
            
            // Month names (YELLOW)
            ("\\b(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)\\b", UIColor.systemYellow),
            
            // Time patterns (RED)
            ("(?<=\\bat\\s)\\d{1,2}\\b", UIColor.systemRed),
            ("(?<=\\btomorrow\\s)\\d{1,2}\\b", UIColor.systemRed),
            ("(?<=\\btm\\s)\\d{1,2}\\b", UIColor.systemRed),
            ("(?<=\\btoday\\s)\\d{1,2}\\b", UIColor.systemRed),
            ("(?<=\\btd\\s)\\d{1,2}\\b", UIColor.systemRed),
            ("\\b\\d{1,2}:\\d{2}\\s*(am|pm|AM|PM)?\\b", UIColor.systemRed), // 9:45pm, 21:30
            ("\\b\\d{1,2}\\s*(am|pm|AM|PM)\\b", UIColor.systemRed), // 9pm, 9AM
            
            // Hour/minute patterns (RED) - NEW
            ("\\bin\\s+\\d+\\s*(?:hours?|hrs?|h)\\b", UIColor.systemRed), // in 2 hours, in 2h
            ("\\bin\\s+\\d+\\s*(?:minutes?|mins?|min|m)\\b", UIColor.systemRed), // in 30 minutes, in 30min
        ])
        
        // Add time periods pattern only if enabled
        if timePeriodsEnabled {
            patterns.append(("\\b(morning|afternoon|evening|night|noon)\\b", UIColor.systemRed))
        }
        
        // Apply colors based on patterns
        for (pattern, color) in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
                
                for match in matches {
                    attributedString.addAttribute(.foregroundColor, value: color, range: match.range)
                    attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 18, weight: .medium), range: match.range)
                }
            } catch {
                // Silently continue if regex pattern fails
            }
        }
        
        return attributedString
    }
}

// Custom SwiftUI text field with syntax highlighting for iOS
struct SyntaxHighlightedTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var colorHelpersEnabled: Bool = true
    var shortcutsEnabled: Bool = true
    var timePeriodsEnabled: Bool = true
    var onSubmit: (() -> Void)?
    
    func makeUIView(context: Context) -> PlaceholderTextView {
        let textView = PlaceholderTextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        textView.backgroundColor = UIColor.secondarySystemBackground
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        textView.returnKeyType = .send
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        
        // Set placeholder using custom property - NEVER mixed with real text
        textView.placeholderText = placeholder
        textView.placeholderColor = UIColor.placeholderText
        
        return textView
    }
    
    func updateUIView(_ uiView: PlaceholderTextView, context: Context) {
        // EXACTLY like macOS: Only update when binding changes externally
        if text.isEmpty {
            uiView.text = ""  // Clear real text, placeholder will show automatically
        } else {
            // Always apply syntax highlighting when ANY setting changes (not just text)
            let highlightedText = IOSSyntaxHighlighter.highlightText(
                text,
                isEnabled: colorHelpersEnabled,
                shortcutsEnabled: shortcutsEnabled,
                timePeriodsEnabled: timePeriodsEnabled
            )
            
            // Only update attributed text if it's actually different to avoid cursor jumping
            if uiView.attributedText?.string != highlightedText.string || 
               uiView.text != text {
                let selectedRange = uiView.selectedRange
                uiView.attributedText = highlightedText
                uiView.selectedRange = selectedRange
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: SyntaxHighlightedTextField
        
        init(_ parent: SyntaxHighlightedTextField) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // EXACTLY like macOS: Always update binding with real text
            // PlaceholderTextView handles placeholder display separately
            parent.text = textView.text
            
            // Apply syntax highlighting only if we have real text
            if !textView.text.isEmpty {
                let highlightedText = IOSSyntaxHighlighter.highlightText(
                    textView.text,
                    isEnabled: parent.colorHelpersEnabled,
                    shortcutsEnabled: parent.shortcutsEnabled,
                    timePeriodsEnabled: parent.timePeriodsEnabled
                )
                
                let selectedRange = textView.selectedRange
                textView.attributedText = highlightedText
                textView.selectedRange = selectedRange
            }
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                parent.onSubmit?()
                return false
            }
            return true
        }
    }
}

#endif