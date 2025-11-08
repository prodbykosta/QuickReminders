//
//  AnimationManager.swift
//  QuickReminders - Shared
//
//  Shared animation system for both macOS and iOS
//
#if os(iOS)
import SwiftUI
import Combine

// Status types for different animation states
enum AnimationStatus: Equatable {
    case hidden
    case processing(String)
    case success(String)
    case error(String)
    
    var message: String {
        switch self {
        case .hidden:
            return ""
        case .processing(let msg):
            return msg
        case .success(let msg):
            return msg
        case .error(let msg):
            return msg
        }
    }
    
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        default:
            return false
        }
    }
    
    var isError: Bool {
        switch self {
        case .error:
            return true
        default:
            return false
        }
    }
    
    var systemImageName: String {
        switch self {
        case .hidden:
            return ""
        case .processing:
            return "clock"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .hidden:
            return .clear
        case .processing:
            return .blue
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}

// Shared animation manager for QuickReminders
class AnimationManager: ObservableObject {
    @Published var currentStatus: AnimationStatus = .hidden
    @Published var shouldDismissAfterSuccess = true
    
    private var autoHideTimer: Timer?
    
    // MARK: - Animation Control Methods
    
    func showProcessing(_ message: String) {
        currentStatus = .processing(message)
        cancelAutoHide()
    }
    
    func showSuccess(_ message: String, autoDismissAfter seconds: Double = 2.0) {
        currentStatus = .success(message)
        
        if shouldDismissAfterSuccess && seconds > 0 {
            scheduleAutoHide(after: seconds)
        }
    }
    
    func showError(_ message: String, autoDismissAfter seconds: Double = 3.0) {
        currentStatus = .error(message)
        
        if seconds > 0 {
            scheduleAutoHide(after: seconds)
        }
    }
    
    func hide() {
        currentStatus = .hidden
        cancelAutoHide()
    }
    
    // MARK: - Auto-Hide Timer Management
    
    private func scheduleAutoHide(after seconds: Double) {
        cancelAutoHide()
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.hide()
            }
        }
    }
    
    private func cancelAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }
    
    // MARK: - Cleanup
    
    deinit {
        cancelAutoHide()
    }
}

// MARK: - SwiftUI View Components

// Shared status view component that works on both macOS and iOS
struct StatusAnimationView: View {
    @ObservedObject var animationManager: AnimationManager
    
    var body: some View {
        Group {
            if case .hidden = animationManager.currentStatus {
                EmptyView()
            } else {
                HStack(spacing: 12) {
                    // Animated icon
                    Image(systemName: animationManager.currentStatus.systemImageName)
                        .foregroundColor(animationManager.currentStatus.color)
                        .scaleEffect(1.1)
                        .animation(.easeInOut(duration: 0.3), value: animationManager.currentStatus.systemImageName)
                    
                    // Status message
                    Text(animationManager.currentStatus.message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(animationManager.currentStatus.color)
                        .animation(.easeInOut(duration: 0.2), value: animationManager.currentStatus.message)
                    
                    // Processing spinner for processing state
                    if case .processing = animationManager.currentStatus {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: animationManager.currentStatus.color))
                    }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                    removal: .opacity.combined(with: .scale(scale: 0.9))
                ))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animationManager.currentStatus.message)
            }
        }
    }
}

// iOS-specific overlay version (for keyboard extension)
struct StatusOverlayView: View {
    @ObservedObject var animationManager: AnimationManager
    
    var body: some View {
        Group {
            if case .hidden = animationManager.currentStatus {
                EmptyView()
            } else {
                VStack(spacing: 8) {
                    // Icon with larger scale for mobile
                    Image(systemName: animationManager.currentStatus.systemImageName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(animationManager.currentStatus.color)
                        .scaleEffect(1.2)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: animationManager.currentStatus.systemImageName)
                    
                    // Message
                    Text(animationManager.currentStatus.message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(animationManager.currentStatus.color)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .animation(.easeInOut(duration: 0.3), value: animationManager.currentStatus.message)
                    
                    // Processing indicator
                    if case .processing = animationManager.currentStatus {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: animationManager.currentStatus.color))
                            .scaleEffect(0.9)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(animationManager.currentStatus.color.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.7)).combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.8)).combined(with: .move(edge: .top))
                ))
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animationManager.currentStatus.message)
            }
        }
    }
}

// Extension for common reminder operations
extension AnimationManager {
    
    // Convenience methods for common QuickReminders operations
    func showCreatingReminder() {
        showProcessing("Creating reminder...")
    }
    
    func showReminderCreated() {
        showSuccess("✅ Reminder created successfully!")
    }
    
    func showReminderCreationFailed(_ error: String? = nil) {
        let message = error != nil ? "❌ Failed: \(error!)" : "❌ Failed to create reminder"
        showError(message)
    }
    
    func showDeletingReminder() {
        showProcessing("Deleting reminder...")
    }
    
    func showReminderDeleted() {
        showSuccess("✅ Reminder deleted successfully!")
    }
    
    func showMovingReminder() {
        showProcessing("Moving reminder...")
    }
    
    func showReminderMoved() {
        showSuccess("✅ Reminder moved successfully!")
    }
    
    func showSearchingReminder() {
        showProcessing("Searching for reminder...")
    }
    
    func showInvalidFormat(_ message: String? = nil) {
        let errorMsg = message ?? "Invalid reminder format"
        showError("❌ \(errorMsg)")
    }
    
    func showVoiceRecording() {
        showProcessing("🎤 Listening...")
    }
    
    func showVoiceProcessing() {
        showProcessing("🧠 Processing speech...")
    }
}

#endif
