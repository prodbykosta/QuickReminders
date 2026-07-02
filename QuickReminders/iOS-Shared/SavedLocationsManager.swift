//
//  SavedLocationsManager.swift
//  QuickReminders
//
//  Manager for saved locations
//

import Foundation
import Combine
import SwiftUI

public class SavedLocationsManager: ObservableObject {
    @Published public var savedLocations: [SavedLocation] = []

    private let sharedDefaults: UserDefaults
    private let locationsKey = "SavedLocations"

    public init() {
        self.sharedDefaults = UserDefaults(suiteName: "group.com.martinkostelka.QuickReminders") ?? UserDefaults.standard
        loadLocations()
    }

    // MARK: - Load/Save

    private func loadLocations() {
        if let data = sharedDefaults.data(forKey: locationsKey),
           let decoded = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            savedLocations = decoded
        }
    }

    private func saveLocations() {
        if let encoded = try? JSONEncoder().encode(savedLocations) {
            sharedDefaults.set(encoded, forKey: locationsKey)
        }
    }

    // MARK: - CRUD Operations

    public func addLocation(_ location: SavedLocation) {
        savedLocations.append(location)
        saveLocations()
    }

    public func updateLocation(_ location: SavedLocation) {
        if let index = savedLocations.firstIndex(where: { $0.id == location.id }) {
            savedLocations[index] = location
            saveLocations()
        }
    }

    public func deleteLocation(_ location: SavedLocation) {
        savedLocations.removeAll { $0.id == location.id }
        saveLocations()
    }

    public func deleteLocations(at offsets: IndexSet) {
        savedLocations.remove(atOffsets: offsets)
        saveLocations()
    }

    // MARK: - Search

    public func findLocation(matching text: String) -> SavedLocation? {
        let lowercased = text.lowercased()
        return savedLocations.first { location in
            location.name.lowercased().contains(lowercased) ||
            location.address.lowercased().contains(lowercased)
        }
    }

    public func getAllLocationNames() -> [String] {
        return savedLocations.map { $0.name }
    }
}
