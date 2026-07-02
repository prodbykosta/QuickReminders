//
//  VariableHighlightedTextField.swift
//  QuickReminders
//
//  Text field with variable highlighting and tap-to-toggle functionality for iOS
//

#if os(iOS)
import SwiftUI
import UIKit

struct VariableHighlightedTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var parsedVariables: [ParsedVariable]
    var onVariableToggle: (Int) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 17)
        textView.isScrollEnabled = true
        textView.isEditable = true  // Make sure it's editable!
        textView.isUserInteractionEnabled = true  // Make sure user can interact!
        textView.backgroundColor = .clear  // Use clear background (parent view handles background)
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .yes
        textView.keyboardType = .default
        textView.returnKeyType = .default

        // Add tap gesture for variable toggling (but don't interfere with text selection)
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.delegate = context.coordinator
        textView.addGestureRecognizer(tapGesture)

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update if text actually changed (prevent infinite loop)
        guard textView.text != text else { return }

        // Store current cursor position
        let selectedRange = textView.selectedRange

        let attributedString = NSMutableAttributedString(string: text)

        // Add base font attribute
        attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 17), range: NSRange(location: 0, length: text.count))

        for variable in parsedVariables {
            // Make sure range is valid
            guard variable.range.location >= 0 && variable.range.location + variable.range.length <= text.count else { continue }

            let color: UIColor = variable.isOverriddenAsText ? .systemGray : colorForVariableType(variable.type)

            attributedString.addAttribute(.backgroundColor, value: color.withAlphaComponent(0.2), range: variable.range)
            attributedString.addAttribute(.foregroundColor, value: color, range: variable.range)

            if variable.isOverriddenAsText {
                attributedString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: variable.range)
            }
        }

        textView.attributedText = attributedString

        // Restore cursor position
        textView.selectedRange = selectedRange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func colorForVariableType(_ type: ParsedVariable.VariableType) -> UIColor {
        switch type {
        case .date: return .systemBlue
        case .time: return .systemPurple
        case .number: return .systemOrange
        case .contact: return .systemGreen
        case .location: return .systemTeal
        case .recurrence: return .systemIndigo
        }
    }

    class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        let parent: VariableHighlightedTextField

        init(_ parent: VariableHighlightedTextField) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            // Update parent binding when text changes
            DispatchQueue.main.async {
                self.parent.text = textView.text ?? ""
            }
        }

        // Allow gesture recognizer to work alongside text editing
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }

            let location = gesture.location(in: textView)
            let characterIndex = textView.layoutManager.characterIndex(
                for: location,
                in: textView.textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )

            // Only toggle if we tapped on a variable (not just editing cursor position)
            for (index, variable) in parent.parsedVariables.enumerated() {
                if NSLocationInRange(characterIndex, variable.range) {
                    parent.onVariableToggle(index)
                    return
                }
            }
        }
    }
}
#endif
