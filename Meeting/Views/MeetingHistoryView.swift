//
//  MeetingHistoryView.swift
//  WhisperType
//
//  Main view for displaying meeting history with search and filtering.
//

import SwiftUI

// MARK: - Meeting History View Model

@MainActor
class MeetingHistoryViewModel: ObservableObject {
    @Published var meetings: [MeetingRecord] = []
    @Published var filteredMeetings: [MeetingRecord] = []
    @Published var searchText: String = "" {
        didSet {
            filterMeetings()
        }
    }
    @Published var isLoading: Bool = false
    @Published var storageInfo: StorageInfo?
    @Published var selectedMeeting: MeetingRecord?
    @Published var showingDeleteConfirmation: Bool = false
    @Published var meetingToDelete: MeetingRecord?
    
    private let database = MeetingDatabase.shared
    private let fileManager = MeetingFileManager.shared
    
    init() {
        loadMeetings()
        loadStorageInfo()
        
        // Listen for new meetings
        NotificationCenter.default.addObserver(
            forName: .meetingProcessingComplete,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("MeetingHistoryViewModel: New meeting available, reloading...")
            self?.loadMeetings()
            self?.loadStorageInfo()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func loadMeetings() {
        isLoading = true
        
        do {
            meetings = try database.getAllMeetings()
            filterMeetings()
        } catch {
            print("MeetingHistoryViewModel: Failed to load meetings - \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func loadStorageInfo() {
        do {
            storageInfo = try fileManager.calculateStorageUsage()
        } catch {
            print("MeetingHistoryViewModel: Failed to calculate storage - \(error.localizedDescription)")
        }
    }
    
    func filterMeetings() {
        if searchText.isEmpty {
            filteredMeetings = meetings
        } else {
            filteredMeetings = meetings.filter { meeting in
                meeting.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    func deleteMeeting(_ meeting: MeetingRecord) {
        do {
            // Delete from database
            try database.deleteMeeting(id: meeting.id)
            
            // Delete files
            try fileManager.deleteSession(at: URL(fileURLWithPath: meeting.sessionDirectory))
            
            // Reload
            loadMeetings()
            loadStorageInfo()
        } catch {
            print("MeetingHistoryViewModel: Failed to delete meeting - \(error.localizedDescription)")
        }
    }
    
    func confirmDelete(_ meeting: MeetingRecord) {
        meetingToDelete = meeting
        showingDeleteConfirmation = true
    }
    
    func updateMeetingTitle(_ meeting: MeetingRecord, newTitle: String) {
        var updatedMeeting = meeting
        updatedMeeting.title = newTitle
        
        do {
            try database.updateMeeting(updatedMeeting)
            
            // Update selected meeting if it matches
            if selectedMeeting?.id == meeting.id {
                selectedMeeting = updatedMeeting
            }
            
            loadMeetings()
        } catch {
            print("MeetingHistoryViewModel: Failed to update title - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Grouping
    
    var groupedMeetings: [(String, [MeetingRecord])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: today)!
        
        var groups: [String: [MeetingRecord]] = [:]
        
        for meeting in filteredMeetings {
            let meetingDay = calendar.startOfDay(for: meeting.createdAt)
            
            let groupKey: String
            if meetingDay == today {
                groupKey = "Today"
            } else if meetingDay == yesterday {
                groupKey = "Yesterday"
            } else if meetingDay > lastWeek {
                groupKey = "Last 7 Days"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                groupKey = formatter.string(from: meeting.createdAt)
            }
            
            if groups[groupKey] == nil {
                groups[groupKey] = []
            }
            groups[groupKey]?.append(meeting)
        }
        
        // Sort groups by date (most recent first)
        let orderedKeys = ["Today", "Yesterday", "Last 7 Days"]
        var result: [(String, [MeetingRecord])] = []
        
        for key in orderedKeys {
            if let meetings = groups[key] {
                result.append((key, meetings))
                groups.removeValue(forKey: key)
            }
        }
        
        // Add remaining month groups sorted by date
        let sortedMonthKeys = groups.keys.sorted { key1, key2 in
            // Parse month/year and compare
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            let date1 = formatter.date(from: key1) ?? Date.distantPast
            let date2 = formatter.date(from: key2) ?? Date.distantPast
            return date1 > date2
        }
        
        for key in sortedMonthKeys {
            if let meetings = groups[key] {
                result.append((key, meetings))
            }
        }
        
        return result
    }
}

// MARK: - Meeting History View

struct MeetingHistoryView: View {
    @StateObject private var viewModel = MeetingHistoryViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar with meeting list
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $viewModel.searchText)
                    .padding()
                
                // Meeting list
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredMeetings.isEmpty {
                    emptyStateView
                } else {
                    meetingList
                }
                
                // Storage info footer
                if let storage = viewModel.storageInfo {
                    storageFooter(storage)
                }
            }
            .navigationTitle("Meeting History")
            .frame(minWidth: 300)
        } detail: {
            // Detail view
            if let meeting = viewModel.selectedMeeting {
                MeetingDetailView(
                    meeting: meeting,
                    onTitleChange: { newTitle in
                        viewModel.updateMeetingTitle(meeting, newTitle: newTitle)
                    },
                    onDelete: {
                        viewModel.confirmDelete(meeting)
                    }
                )
                .id(meeting.id) // Force view recreation when meeting changes
            } else {
                Text("Select a meeting to view details")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("Delete Meeting?", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let meeting = viewModel.meetingToDelete {
                    viewModel.deleteMeeting(meeting)
                    if viewModel.selectedMeeting?.id == meeting.id {
                        viewModel.selectedMeeting = nil
                    }
                }
            }
        } message: {
            if let meeting = viewModel.meetingToDelete {
                Text("Are you sure you want to delete '\(meeting.title)'? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var meetingList: some View {
        List(selection: $viewModel.selectedMeeting) {
            ForEach(viewModel.groupedMeetings, id: \.0) { group, meetings in
                Section(header: Text(group)) {
                    ForEach(meetings) { meeting in
                        MeetingRowView(meeting: meeting)
                            .tag(meeting)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    viewModel.confirmDelete(meeting)
                                }
                            }
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            if viewModel.searchText.isEmpty {
                Text("No Meetings Yet")
                    .font(.headline)
                Text("Start a meeting recording to see it here.")
                    .foregroundStyle(.secondary)
            } else {
                Text("No Results")
                    .font(.headline)
                Text("No meetings match '\(viewModel.searchText)'")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func storageFooter(_ storage: StorageInfo) -> some View {
        HStack {
            Image(systemName: "internaldrive")
                .foregroundStyle(.secondary)
            Text("\(viewModel.meetings.count) meetings • \(storage.totalFormatted) used")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search meetings...", text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Meeting Row View

struct MeetingRowView: View {
    let meeting: MeetingRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
                
                Text(meeting.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
                
                if meeting.status == .processing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            
            HStack(spacing: 8) {
                Text(meeting.formattedDuration)
                Text("•")
                Text(formatTime(meeting.createdAt))
                
                if meeting.speakerCount > 0 {
                    Text("•")
                    Text("\(meeting.speakerCount) speaker\(meeting.speakerCount == 1 ? "" : "s")")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            if let preview = meeting.summaryPreview, !preview.isEmpty {
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    MeetingHistoryView()
}
