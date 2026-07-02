//
//  MacLocationPickerView.swift
//  QuickReminders
//
//  Location picker UI for macOS
//

#if os(macOS)
import SwiftUI
import MapKit
import EventKit
import CoreLocation
import Combine

// Note: MKPlacemark is deprecated in macOS 26.0
// We're using it for backward compatibility until minimum deployment target is macOS 26.0

// Helper function for address formatting (backward compatibility)
@available(macOS, deprecated: 26.0, message: "Use formatAddress(from: MKMapItem) instead")
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
@available(macOS 26.0, *)
fileprivate func formatAddress(from mapItem: MKMapItem) -> String? {
    // Try to build address from MKAddress components
    guard let address = mapItem.address else { return nil }

    var components: [String] = []

    // Build address string from available components using reflection
    let mirror = Mirror(reflecting: address)
    for child in mirror.children {
        if let value = child.value as? String, !value.isEmpty {
            components.append(value)
        }
    }

    return components.isEmpty ? nil : components.joined(separator: ", ")
}

struct MacLocationPickerView: View {
    @Binding var selectedLocation: MKMapItem?
    @Binding var locationProximity: EKAlarmProximity
    @Environment(\.dismiss) private var dismiss

    @StateObject private var locationsManager = SavedLocationsManager()
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            TextField("Search for a place", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding()
                .onChange(of: searchText) {
                    performSearch(query: searchText)
                }
                .onSubmit {
                    performSearch(query: searchText)
                }

            if isSearching {
                VStack {
                    ProgressView("Searching...")
                    Text("Finding locations...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Search Error")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                // Searched but found nothing
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No Results")
                        .font(.headline)
                    Text("Try searching for a specific place name or address")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !locationsManager.savedLocations.isEmpty || !searchResults.isEmpty {
                // Show list if there are saved locations OR search results
                List {
                    // Show saved locations first (when not searching)
                    if !locationsManager.savedLocations.isEmpty && searchText.isEmpty {
                        Section("Saved Locations") {
                            ForEach(locationsManager.savedLocations) { savedLocation in
                                Button(action: {
                                    // Convert SavedLocation to MKMapItem
                                    let coordinate = CLLocationCoordinate2D(
                                        latitude: savedLocation.latitude,
                                        longitude: savedLocation.longitude
                                    )
                                    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

                                    if #available(macOS 26.0, *) {
                                        // Use new API
                                        selectedLocation = MKMapItem(location: location, address: nil)
                                        selectedLocation?.name = savedLocation.name
                                    } else {
                                        // MKPlacemark deprecated in macOS 26.0 - using for backward compatibility
                                        let placemark = MKPlacemark(coordinate: coordinate)
                                        selectedLocation = MKMapItem(placemark: placemark)
                                        selectedLocation?.name = savedLocation.name
                                    }
                                    locationProximity = savedLocation.proximity
                                }) {
                                    HStack {
                                        Image(systemName: savedLocation.proximity == .enter ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                            .foregroundColor(savedLocation.proximity == .enter ? .blue : .orange)
                                        VStack(alignment: .leading) {
                                            Text(savedLocation.name)
                                                .font(.headline)
                                            if !savedLocation.address.isEmpty {
                                                Text(savedLocation.address)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // Show search results
                    if !searchResults.isEmpty {
                        Section(searchText.isEmpty ? "" : "Search Results") {
                            ForEach(searchResults, id: \.self) { item in
                                Button(action: {
                                    selectedLocation = item
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(item.name ?? "Unknown")
                                            .font(.headline)
                                        if #available(macOS 26.0, *) {
                                            if let address = formatAddress(from: item) {
                                                Text(address)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        } else {
                                            // Using placemark for backward compatibility with macOS < 26.0
                                            if let address = formatAddress(from: item.placemark) {
                                                Text(address)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            } else {
                // No saved locations and no search yet - show empty state
                VStack(spacing: 12) {
                    Image(systemName: "location.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Search for a Location")
                        .font(.headline)
                    Text("Enter a place name or address above")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Proximity selector (only show when location is selected)
            if selectedLocation != nil {
                Divider()
                    .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Alert when:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button(action: { locationProximity = .enter }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Arriving")
                            }
                            .foregroundColor(locationProximity == .enter ? .white : .blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(locationProximity == .enter ? Color.blue : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button(action: { locationProximity = .leave }) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Leaving")
                            }
                            .foregroundColor(locationProximity == .leave ? .white : .orange)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(locationProximity == .leave ? Color.orange : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            HStack {
                if selectedLocation != nil {
                    Button("Clear Selection") {
                        selectedLocation = nil
                    }
                }
                Spacer()
                Button(selectedLocation != nil ? "Done" : "Cancel") {
                    dismiss()
                }
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil
        searchResults = []

        Task {
            do {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.resultTypes = [.pointOfInterest, .address]

                let search = MKLocalSearch(request: request)
                let response = try await search.start()

                await MainActor.run {
                    self.searchResults = response.mapItems
                    self.isSearching = false
                    self.errorMessage = nil
                }
            } catch let error as NSError {
                await MainActor.run {
                    self.searchResults = []
                    self.isSearching = false
                    self.errorMessage = "Search failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct MacLocationPickerButton: View {
    @Binding var selectedLocation: MKMapItem?
    @Binding var locationProximity: EKAlarmProximity
    @State private var showPicker = false

    var body: some View {
        Button(action: { showPicker = true }) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 20))
        }
        .sheet(isPresented: $showPicker) {
            MacLocationPickerView(selectedLocation: $selectedLocation, locationProximity: $locationProximity)
        }
    }
}
#endif
