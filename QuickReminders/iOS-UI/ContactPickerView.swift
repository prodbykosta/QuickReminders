//
//  ContactPickerView.swift
//  QuickReminders
//
//  Contact picker UI for iOS
//

#if os(iOS)
import SwiftUI
import ContactsUI

struct ContactPickerView: UIViewControllerRepresentable {
    @Binding var selectedContact: CNContact?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerView

        init(_ parent: ContactPickerView) {
            self.parent = parent
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.selectedContact = contact
            parent.dismiss()
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.dismiss()
        }
    }
}

struct ContactPickerButton: View {
    @Binding var selectedContact: CNContact?
    @State private var showPicker = false

    var body: some View {
        Button(action: { showPicker = true }) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
        }
        .sheet(isPresented: $showPicker) {
            ContactPickerView(selectedContact: $selectedContact)
        }
    }
}
#endif
