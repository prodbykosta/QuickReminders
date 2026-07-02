//
//  SavedLocationsView.swift
//  QuickReminders
//
//  UI for managing saved locations
//

import SwiftUI
import MapKit
import EventKit

// Note: MKPlacemark APIs are deprecated in macOS 26.0
// We're using them for backward compatibility until minimum deployment target is macOS 26.0
// TODO: Update to use MKMapItem's address properties when minimum deployment target is bumped

// Helper function for address formatting (backward compatibility)
@available(macOS, deprecated: 26.0, message: "Use formatAddress(from: MKMapItem) instead")
@available(iOS, deprecated: 26.0, message: "Use formatAddress(from: MKMapItem) instead")
fileprivate func formatAddress(from placemark: MKPlacemark) -> String? {
    var components: [String] = []

    if let thoroughfare = placemark.thoroughfare {
        components.append(thoroughfare)
    }
    if let subThoroughfare = placemark.subThoroughfare {
        components.append(subThoroughfare)
    }
    if let locality = placemark.locality {
        components.append(locality)
    }
    if let administrativeArea = placemark.administrativeArea {
        components.append(administrativeArea)
    }

    return components.isEmpty ? nil : components.joined(separator: ", ")
}

// Helper function for formatting address using new API
@available(macOS 26.0, iOS 26.0, *)
fileprivate func formatAddress(from mapItem: MKMapItem) -> String? {
    // Try to build address from MKAddress components
    guard let address = mapItem.address else { return nil }

    var components: [String] = []

    // Build address string from available components
    let mirror = Mirror(reflecting: address)
    for child in mirror.children {
        if let value = child.value as? String, !value.isEmpty {
            components.append(value)
        }
    }

    return components.isEmpty ? nil : components.joined(separator: ", ")
}

struct SavedLocationsView: View {
    @StateObject private var locationsManager = SavedLocationsManager()
    @State private var showingAddLocation = false
    @State private var editingLocation: SavedLocation?
    @State private var searchText = ""
    @State private var locationSearchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var selectedProximity: EKAlarmProximity = .enter

    var filteredLocations: [SavedLocation] {
        if searchText.isEmpty {
            return locationsManager.savedLocations
        } else {
            return locationsManager.savedLocations.filter { location in
                location.name.localizedCaseInsensitiveContains(searchText) ||
                location.address.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Saved Locations")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                if !showingAddLocation && editingLocation == nil {
                    Button(action: {
                        showingAddLocation = true
                        locationSearchText = ""
                        searchResults = []
                        selectedProximity = .enter
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Location")
                        }
                        .font(.body.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()

            Divider()

            // Main content area
            if showingAddLocation {
                // INLINE ADD VIEW
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Cancel button
                        HStack {
                            Button("Cancel") {
                                showingAddLocation = false
                                locationSearchText = ""
                                searchResults = []
                            }
                            .buttonStyle(.link)
                            Spacer()
                        }
                        .padding(.horizontal, 20)

                        // Search field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Search for a place")
                                .font(.headline)
                            TextField("Enter location name", text: $locationSearchText)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: locationSearchText) {
                                    performSearch()
                                }
                        }
                        .padding(.horizontal, 20)

                        // Proximity selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Remind me when:")
                                .font(.headline)

                            HStack(spacing: 12) {
                                // Arriving Button
                                Button(action: {
                                    selectedProximity = .enter
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.system(size: 20))
                                        Text("Arriving")
                                            .font(.body.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedProximity == .enter ? Color.blue : Color.secondary.opacity(0.1))
                                    .foregroundColor(selectedProximity == .enter ? .white : .primary)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)

                                // Leaving Button
                                Button(action: {
                                    selectedProximity = .leave
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 20))
                                        Text("Leaving")
                                            .font(.body.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedProximity == .leave ? Color.orange : Color.secondary.opacity(0.1))
                                    .foregroundColor(selectedProximity == .leave ? .white : .primary)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)

                        Divider()

                        // Search results
                        if isSearching {
                            HStack {
                                Spacer()
                                ProgressView("Searching...")
                                Spacer()
                            }
                            .padding()
                        } else if searchResults.isEmpty && !locationSearchText.isEmpty {
                            HStack {
                                Spacer()
                                Text("No results found")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding()
                        } else if !searchResults.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("Results")
                                    .font(.headline)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 8)

                                ForEach(searchResults, id: \.self) { item in
                                    Button(action: {
                                        addLocation(item)
                                    }) {
                                        HStack {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 20))

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(item.name ?? "Unknown")
                                                    .font(.body.weight(.medium))
                                                    .foregroundColor(.primary)

                                                if #available(macOS 26.0, iOS 26.0, *) {
                                                    if let address = formatAddress(from: item) {
                                                        Text(address)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                } else {
                                                    if let address = formatAddress(from: item.placemark) {
                                                        Text(address)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                            }

                                            Spacer()

                                            Image(systemName: "plus.circle")
                                                .foregroundColor(.blue)
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 20)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                    }
                    .padding(.top, 20)
                }
            } else if let location = editingLocation {
                // INLINE EDIT VIEW
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Cancel button
                        HStack {
                            Button("Cancel") {
                                editingLocation = nil
                            }
                            .buttonStyle(.link)
                            Spacer()
                        }
                        .padding(.horizontal, 20)

                        // Location details
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Location Details")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Location name", text: Binding(
                                    get: { location.name },
                                    set: { _ in }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .disabled(true)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Address")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(location.address)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 20)

                        // Proximity selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Remind me when:")
                                .font(.headline)

                            HStack(spacing: 12) {
                                // Arriving Button
                                Button(action: {
                                    updateLocationProximity(location, proximity: .enter)
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.system(size: 20))
                                        Text("Arriving")
                                            .font(.body.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(location.proximity == .enter ? Color.blue : Color.secondary.opacity(0.1))
                                    .foregroundColor(location.proximity == .enter ? .white : .primary)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)

                                // Leaving Button
                                Button(action: {
                                    updateLocationProximity(location, proximity: .leave)
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 20))
                                        Text("Leaving")
                                            .font(.body.weight(.medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(location.proximity == .leave ? Color.orange : Color.secondary.opacity(0.1))
                                    .foregroundColor(location.proximity == .leave ? .white : .primary)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)

                        Divider()

                        // Delete button
                        Button(action: {
                            locationsManager.deleteLocation(location)
                            editingLocation = nil
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Location")
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                }
            } else {
                // LOCATION LIST
                if locationsManager.savedLocations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No Saved Locations")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Add locations to quickly access them and enable natural language parsing.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredLocations) { location in
                            Button(action: {
                                editingLocation = location
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: location.proximity.icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(.blue)
                                        .frame(width: 40)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(location.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        if !location.address.isEmpty {
                                            Text(location.address)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }

                                        Text(location.proximity.displayName)
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            locationsManager.deleteLocations(at: offsets)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search locations")
        #else
        List {
            if locationsManager.savedLocations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("No Saved Locations")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Add locations to quickly access them and enable natural language parsing.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(filteredLocations) { location in
                    LocationRow(location: location) {
                        editingLocation = location
                    }
                }
                .onDelete { offsets in
                    locationsManager.deleteLocations(at: offsets)
                }
            }
        }
        .navigationTitle("Saved Locations")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $searchText, prompt: "Search locations")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddLocation = true
                }) {
                    Image(systemName: "plus")
                }
            }
            #else
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    showingAddLocation = true
                }) {
                    Image(systemName: "plus")
                }
            }
            #endif
        }
        .sheet(isPresented: $showingAddLocation) {
            AddLocationView(locationsManager: locationsManager)
        }
        .sheet(item: $editingLocation) { location in
            EditLocationView(location: location, locationsManager: locationsManager)
        }
        #endif
    }

    // MARK: - Helper Functions

    private func performSearch() {
        guard !locationSearchText.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = locationSearchText

            let search = MKLocalSearch(request: request)

            do {
                let response = try await search.start()
                await MainActor.run {
                    searchResults = response.mapItems
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    searchResults = []
                    isSearching = false
                }
            }
        }
    }

    private func addLocation(_ mapItem: MKMapItem) {
        if #available(macOS 26.0, iOS 26.0, *) {
            // Use new API
            let address = formatAddress(from: mapItem) ?? ""
            let coordinate = mapItem.location.coordinate
            let location = SavedLocation(
                name: mapItem.name ?? "Unknown",
                address: address,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                proximity: selectedProximity
            )
            locationsManager.addLocation(location)
        } else {
            // Use deprecated API for backward compatibility
            let placemark = mapItem.placemark
            let location = SavedLocation(
                name: mapItem.name ?? "Unknown",
                address: formatAddress(from: placemark) ?? "",
                latitude: placemark.coordinate.latitude,
                longitude: placemark.coordinate.longitude,
                proximity: selectedProximity
            )
            locationsManager.addLocation(location)
        }

        showingAddLocation = false
        locationSearchText = ""
        searchResults = []
    }

    private func updateLocationProximity(_ location: SavedLocation, proximity: EKAlarmProximity) {
        let updatedLocation = SavedLocation(
            id: location.id,
            name: location.name,
            address: location.address,
            latitude: location.latitude,
            longitude: location.longitude,
            proximity: proximity
        )
        locationsManager.updateLocation(updatedLocation)
        editingLocation = updatedLocation
    }
}

struct LocationRow: View {
    let location: SavedLocation
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                Image(systemName: location.proximity.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if !location.address.isEmpty {
                        Text(location.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Text(location.proximity.displayName)
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var locationsManager: SavedLocationsManager

    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var selectedProximity: EKAlarmProximity = .enter

    var body: some View {
        NavigationView {
            VStack {
                TextField("Search for a place", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: searchText) {
                        performSearch()
                    }

                // BIG CLEAR BUTTONS for arriving/leaving
                VStack(alignment: .leading, spacing: 12) {
                    Text("Remind me when:")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal)

                    HStack(spacing: 12) {
                        // Arriving Button
                        Button(action: {
                            selectedProximity = .enter
                        }) {
                            ProximityButtonContent(
                                icon: "arrow.down.circle.fill",
                                label: "Arriving",
                                isSelected: selectedProximity == .enter,
                                selectedColor: .blue
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Leaving Button
                        Button(action: {
                            selectedProximity = .leave
                        }) {
                            ProximityButtonContent(
                                icon: "arrow.up.circle.fill",
                                label: "Leaving",
                                isSelected: selectedProximity == .leave,
                                selectedColor: .orange
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                if isSearching {
                    ProgressView("Searching...")
                        .padding()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    Text("No results found")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(searchResults, id: \.self) { item in
                        Button(action: {
                            addLocation(item)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "Unknown")
                                    .font(.headline)

                                if #available(macOS 26.0, iOS 26.0, *) {
                                    if let address = formatAddress(from: item) {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    if let address = formatAddress(from: item.placemark) {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle("Add Location")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                #endif
            }
        }
        #if os(macOS)
        .frame(width: 600, height: 700)
        #endif
    }

    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchText

            let search = MKLocalSearch(request: request)

            do {
                let response = try await search.start()
                await MainActor.run {
                    searchResults = response.mapItems
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    searchResults = []
                    isSearching = false
                }
            }
        }
    }

    private func addLocation(_ mapItem: MKMapItem) {
        if #available(macOS 26.0, iOS 26.0, *) {
            // Use new API
            let address = formatAddress(from: mapItem) ?? ""
            let coordinate = mapItem.location.coordinate
            let location = SavedLocation(
                name: mapItem.name ?? "Unknown",
                address: address,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                proximity: selectedProximity
            )
            locationsManager.addLocation(location)
        } else {
            // Extract data from placemark for backward compatibility
            let placemark = mapItem.placemark
            let location = SavedLocation(
                name: mapItem.name ?? "Unknown",
                address: formatAddress(from: placemark) ?? "",
                latitude: placemark.coordinate.latitude,
                longitude: placemark.coordinate.longitude,
                proximity: selectedProximity
            )
            locationsManager.addLocation(location)
        }

        dismiss()
    }
}

struct EditLocationView: View {
    @Environment(\.dismiss) private var dismiss
    let location: SavedLocation
    @ObservedObject var locationsManager: SavedLocationsManager

    @State private var name: String
    @State private var proximity: EKAlarmProximity

    init(location: SavedLocation, locationsManager: SavedLocationsManager) {
        self.location = location
        self.locationsManager = locationsManager
        _name = State(initialValue: location.name)
        _proximity = State(initialValue: location.proximity)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Location Details") {
                    TextField("Name", text: $name)

                    HStack {
                        Text("Address")
                        Spacer()
                        Text(location.address)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Section("Reminder Settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Remind me when:")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)

                        HStack(spacing: 12) {
                            // Arriving Button
                            Button(action: {
                                proximity = .enter
                            }) {
                                ProximityButtonContent(
                                    icon: "arrow.down.circle.fill",
                                    label: "Arriving",
                                    isSelected: proximity == .enter,
                                    selectedColor: .blue
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Leaving Button
                            Button(action: {
                                proximity = .leave
                            }) {
                                ProximityButtonContent(
                                    icon: "arrow.up.circle.fill",
                                    label: "Leaving",
                                    isSelected: proximity == .leave,
                                    selectedColor: .orange
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Button("Delete Location", role: .destructive) {
                        locationsManager.deleteLocation(location)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Location")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let updatedLocation = SavedLocation(
                            id: location.id,
                            name: name,
                            address: location.address,
                            latitude: location.latitude,
                            longitude: location.longitude,
                            proximity: proximity
                        )
                        locationsManager.updateLocation(updatedLocation)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updatedLocation = SavedLocation(
                            id: location.id,
                            name: name,
                            address: location.address,
                            latitude: location.latitude,
                            longitude: location.longitude,
                            proximity: proximity
                        )
                        locationsManager.updateLocation(updatedLocation)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                #endif
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 600)
        #endif
    }
}

// Helper view to simplify button styling
struct ProximityButtonContent: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let selectedColor: Color

    var body: some View {
        let bgColor = isSelected ? selectedColor : Color.secondary.opacity(0.1)
        let strokeColor = isSelected ? selectedColor : Color.secondary.opacity(0.3)
        let iconColor = isSelected ? Color.white : selectedColor
        let textColor = isSelected ? Color.white : Color.primary

        return VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(iconColor)

            Text(label)
                .font(.body.weight(.medium))
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(bgColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(strokeColor, lineWidth: 2)
        )
    }
}
