//
//  AddressSearchView.swift
//  simpleDecision
//
//  Created by Transportation Recommendation System on 01/10/2025.
//

import SwiftUI
import MapKit
import Combine

/// View for searching and selecting addresses using MapKit
struct AddressSearchView: View {
    @StateObject private var searchCompleter = AddressSearchCompleter()
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    
    let onAddressSelected: (String, String, CLLocationCoordinate2D) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search for a place or address", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: searchText) { newValue in
                            searchCompleter.search(query: newValue)
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchCompleter.clearResults()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Results list
                if searchCompleter.isSearching {
                    ProgressView()
                        .padding()
                    Spacer()
                } else if searchCompleter.results.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No results found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try searching for a different address")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    Spacer()
                } else if searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "location.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("Search for a destination")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Enter an address, place name, or landmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    Spacer()
                } else {
                    List(searchCompleter.results, id: \.id) { result in
                        Button(action: {
                            selectAddress(result)
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Add Destination")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func selectAddress(_ result: SearchResult) {
        let searchRequest = MKLocalSearch.Request(completion: result.completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let response = response,
                  let mapItem = response.mapItems.first else {
                return
            }
            
            let name = result.title
            let address = result.subtitle.isEmpty ? result.title : result.subtitle
            let coordinate = mapItem.placemark.coordinate
            
            onAddressSelected(name, address, coordinate)
            presentationMode.wrappedValue.dismiss()
        }
    }
}

/// MapKit search completer for address autocomplete
class AddressSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [SearchResult] = []
    @Published var isSearching = false
    
    private let completer = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
    
    func search(query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }
        
        isSearching = true
        completer.queryFragment = query
    }
    
    func clearResults() {
        results = []
        completer.queryFragment = ""
    }
    
    // MARK: - MKLocalSearchCompleterDelegate
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results.map { SearchResult(completion: $0) }
            self.isSearching = false
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.results = []
            self.isSearching = false
            print("Address search error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Search Result Wrapper

struct SearchResult: Hashable, Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let completion: MKLocalSearchCompletion
    
    init(completion: MKLocalSearchCompletion) {
        self.completion = completion
        self.title = completion.title
        self.subtitle = completion.subtitle
    }
    
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
