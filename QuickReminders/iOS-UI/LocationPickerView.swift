//
//  LocationPickerView.swift
//  QuickReminders
//
//  Location picker UI for iOS
//

#if os(iOS)
import SwiftUI
import MapKit
import EventKit

struct LocationPickerView: View {
    @Binding var selectedLocation: MKMapItem?
    @Binding var locationProximity: EKAlarmProximity  // NEW: Bind proximity!
    @StateObject private var locationsManager = SavedLocationsManager()  // NEW: Access saved locations
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var selectedProximity: EKAlarmProximity

    init(selectedLocation: Binding<MKMapItem?>, locationProximity: Binding<EKAlarmProximity>) {
        self._selectedLocation = selectedLocation
        self._locationProximity = locationProximity
        // Initialize with current proximity
        _selectedProximity = State(initialValue: locationProximity.wrappedValue)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Show currently selected location at top if exists
                if let current = selectedLocation {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Currently Selected:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        HStack {
                            VStack(alignment: .leading) {
                                Text(current.name ?? "Unknown")
                                    .font(.headline)
                                if let address = current.address?.fullAddress {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button("Clear") {
                                selectedLocation = nil
                            }
                            .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // Proximity Selector - IMPROVED
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
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(selectedProximity == .enter ? .white : .blue)

                                Text("Arriving")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(selectedProximity == .enter ? .white : .primary)

                                Text("Get notified when\nyou arrive")
                                    .font(.caption2)
                                    .foregroundColor(selectedProximity == .enter ? .white.opacity(0.9) : .secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedProximity == .enter ? Color.blue : Color.secondary.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedProximity == .enter ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Leaving Button
                        Button(action: {
                            selectedProximity = .leave
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(selectedProximity == .leave ? .white : .orange)

                                Text("Leaving")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(selectedProximity == .leave ? .white : .primary)

                                Text("Get notified when\nyou leave")
                                    .font(.caption2)
                                    .foregroundColor(selectedProximity == .leave ? .white.opacity(0.9) : .secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedProximity == .leave ? Color.orange : Color.secondary.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedProximity == .leave ? Color.orange : Color.secondary.opacity(0.3), lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)

                TextField("Search for a place", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .onChange(of: searchText) {
                        performSearch(query: searchText)
                    }

                if isSearching {
                    ProgressView("Searching...")
                        .padding()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    Text("No results found")
                        .foregroundColor(.secondary)
                        .padding()
                } else if !searchResults.isEmpty {
                    List(searchResults, id: \.self) { item in
                        Button(action: {
                            selectLocation(item)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "Unknown")
                                    .font(.headline)
                                if let address = item.address?.fullAddress {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    // Show saved locations
                    if !locationsManager.savedLocations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Saved Locations")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top, 8)

                            List(locationsManager.savedLocations) { savedLoc in
                                Button(action: {
                                    selectSavedLocation(savedLoc)
                                }) {
                                    HStack {
                                        Image(systemName: savedLoc.proximity.icon)
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading) {
                                            Text(savedLoc.name)
                                                .font(.headline)
                                            if !savedLoc.address.isEmpty {
                                                Text(savedLoc.address)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        locationProximity = selectedProximity
                        dismiss()
                    }
                    .disabled(selectedLocation == nil)
                }
            }
        }
    }

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query

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

    private func selectLocation(_ item: MKMapItem) {
        selectedLocation = item
        locationProximity = selectedProximity

        // Auto-save to saved locations
        let savedLocation = SavedLocation(
            name: item.name ?? "Unknown",
            address: item.address?.fullAddress ?? "",
            latitude: item.location.coordinate.latitude,
            longitude: item.location.coordinate.longitude,
            proximity: selectedProximity
        )

        // Check if already exists
        if !locationsManager.savedLocations.contains(where: { $0.name == savedLocation.name }) {
            locationsManager.addLocation(savedLocation)
        }

        dismiss()
    }

    private func selectSavedLocation(_ savedLoc: SavedLocation) {
        // Create MKMapItem from saved location
        let location = CLLocation(latitude: savedLoc.latitude, longitude: savedLoc.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = savedLoc.name

        selectedLocation = mapItem
        selectedProximity = savedLoc.proximity
        locationProximity = savedLoc.proximity
        dismiss()
    }
}

struct LocationPickerButton: View {
    @Binding var selectedLocation: MKMapItem?
    @State private var showPicker = false

    var body: some View {
        Button(action: { showPicker = true }) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)
        }
        .sheet(isPresented: $showPicker) {
            LocationPickerView(selectedLocation: $selectedLocation, locationProximity: .constant(.enter))
        }
    }
}
#endif
