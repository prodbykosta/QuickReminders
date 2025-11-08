//
//  PreferencesSection.swift
//  QuickReminders
//
//  Created by QuickReminders on 04.10.2025.
//

#if os(macOS)
import SwiftUI

struct PreferencesSection<Content>: View where Content: View {
    let title: String
    let content: () -> Content
    
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section header
                HStack {
                    Text(title)
                        .font(.title)
                        .fontWeight(.semibold)
                        .padding([.bottom, .top], 7.5)
                    Spacer()
                }
                
                // Section content
                HStack {
                    VStack(alignment: .leading, spacing: 16) {
                        content()
                    }
                    Spacer()
                }
                
                Spacer()
            }
            .padding(.leading, 20)
            .padding(.trailing, 20)
        }
    }
}
#endif