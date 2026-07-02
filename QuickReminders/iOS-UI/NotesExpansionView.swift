//
//  NotesExpansionView.swift
//  QuickReminders
//
//  Expandable notes field for iOS
//

#if os(iOS)
import SwiftUI

struct NotesExpansionView: View {
    @Binding var notes: String
    @Binding var isExpanded: Bool
    @EnvironmentObject var colorTheme: SharedColorThemeManager

    var body: some View {
        VStack(spacing: 12) {
            // Toggle Button - styled like the other feature buttons
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: isExpanded ? "note.text" : "note.text.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(colorTheme.boltColor)

                    Text(isExpanded ? "Hide Notes" : "Add Notes")
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Text Editor - styled like the main reminder text field
            if isExpanded {
                TextEditor(text: $notes)
                    .frame(height: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .font(.body)
                    .scrollContentBackground(.hidden)
            }
        }
        .padding(.horizontal, 20)
    }
}
#endif
