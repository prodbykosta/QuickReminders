//
//  SavedLocation.swift
//  QuickReminders
//
//  Saved location model for location management
//

import Foundation
import CoreLocation
import EventKit

public struct SavedLocation: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var address: String
    public var latitude: Double
    public var longitude: Double
    private var proximityValue: Int  // Store as Int for Codable

    public var proximity: EKAlarmProximity {
        get {
            return EKAlarmProximity(rawValue: proximityValue) ?? .enter
        }
        set {
            proximityValue = newValue.rawValue
        }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        proximity: EKAlarmProximity = .enter
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.proximityValue = proximity.rawValue
    }

    // Create from MKMapItem
    public init(name: String, latitude: Double, longitude: Double, address: String = "") {
        self.id = UUID()
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.proximityValue = EKAlarmProximity.enter.rawValue
    }
}

// Extension for UI helpers
extension EKAlarmProximity {
    public var displayName: String {
        switch self {
        case .enter: return "Arriving"
        case .leave: return "Leaving"
        case .none: return "None"
        @unknown default: return "Unknown"
        }
    }

    public var icon: String {
        switch self {
        case .enter: return "arrow.down.circle.fill"
        case .leave: return "arrow.up.circle.fill"
        case .none: return "circle"
        @unknown default: return "circle"
        }
    }
}
