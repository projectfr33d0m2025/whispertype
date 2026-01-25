//
//  StorageManagementView.swift
//  WhisperType
//
//  Storage usage and management UI for meeting recordings.
//

import SwiftUI

// MARK: - Storage Management View Model

@MainActor
class StorageManagementViewModel: ObservableObject {
    @Published var storageInfo: StorageInfo?
    @Published var meetingsBySize: [(MeetingRecord, Int64)] = []
    @Published var isLoading: Bool = false
    @Published var keepAudioFiles: Bool
    @Published var showingDeleteConfirmation: Bool = false
    @Published var meetingsToDelete: [MeetingRecord] = []
    
    private let database = MeetingDatabase.shared
    private let fileManager = MeetingFileManager.shared
    
    init() {
        keepAudioFiles = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.meetingKeepAudioFiles)
        loadData()
    }
    
    func loadData() {
        isLoading = true
        
        do {
            storageInfo = try fileManager.calculateStorageUsage()
            
            // Load meetings and calculate their sizes
            let meetings = try database.getAllMeetings()
            var sized: [(MeetingRecord, Int64)] = []
            
            for meeting in meetings {
                let sessionDir = URL(fileURLWithPath: meeting.sessionDirectory)
                let (total, _, _) = try fileManager.calculateSessionSize(at: sessionDir)
                sized.append((meeting, total))
            }
            
            // Sort by size descending
            meetingsBySize = sized.sorted { $0.1 > $1.1 }
        } catch {
            print("StorageManagementViewModel: Failed to load data - \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func toggleKeepAudioFiles() {
        keepAudioFiles.toggle()
        UserDefaults.standard.set(keepAudioFiles, forKey: Constants.UserDefaultsKeys.meetingKeepAudioFiles)
    }
    
    func deleteAudioForMeeting(_ meeting: MeetingRecord) {
        do {
            let sessionDir = URL(fileURLWithPath: meeting.sessionDirectory)
            try fileManager.deleteAudioFiles(from: sessionDir)
            
            // Update database
            var updated = meeting
            updated.audioKept = false
            try database.updateMeeting(updated)
            
            loadData()
        } catch {
            print("StorageManagementViewModel: Failed to delete audio - \(error.localizedDescription)")
        }
    }
    
    func deleteMeeting(_ meeting: MeetingRecord) {
        do {
            try database.deleteMeeting(id: meeting.id)
            try fileManager.deleteSession(at: URL(fileURLWithPath: meeting.sessionDirectory))
            loadData()
        } catch {
            print("StorageManagementViewModel: Failed to delete meeting - \(error.localizedDescription)")
        }
    }
    
    func confirmDeleteOldMeetings(olderThan days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        meetingsToDelete = meetingsBySize.compactMap { $0.0 }.filter { $0.createdAt < cutoffDate }
        
        if !meetingsToDelete.isEmpty {
            showingDeleteConfirmation = true
        }
    }
    
    func executeDeleteOldMeetings() {
        for meeting in meetingsToDelete {
            deleteMeeting(meeting)
        }
        meetingsToDelete = []
    }
    
    func cleanupOrphans() {
        do {
            let existingIds = Set(meetingsBySize.map { $0.0.id })
            let cleaned = try fileManager.cleanupOrphanSessions(existingIds: existingIds)
            if cleaned > 0 {
                loadData()
            }
        } catch {
            print("StorageManagementViewModel: Cleanup failed - \(error.localizedDescription)")
        }
    }
}

// MARK: - Storage Management View

struct StorageManagementView: View {
    @StateObject private var viewModel = StorageManagementViewModel()
    @State private var selectedDaysToDelete: Int = 30
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            Text("Storage Management")
                .font(.headline)
            
            // Storage overview
            if let info = viewModel.storageInfo {
                storageOverview(info)
            }
            
            Divider()
            
            // Settings
            settingsSection
            
            Divider()
            
            // Meetings by size
            meetingsSection
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400)
        .alert("Delete Old Meetings?", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete \(viewModel.meetingsToDelete.count) Meetings", role: .destructive) {
                viewModel.executeDeleteOldMeetings()
            }
        } message: {
            Text("This will permanently delete \(viewModel.meetingsToDelete.count) meeting(s) older than \(selectedDaysToDelete) days.")
        }
    }
    
    // MARK: - Storage Overview
    
    private func storageOverview(_ info: StorageInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "internaldrive")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading) {
                    Text("\(info.totalFormatted) Used")
                        .font(.title3.bold())
                    Text("\(info.meetingCount) meeting\(info.meetingCount == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Breakdown bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    if info.totalBytes > 0 {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * CGFloat(info.audioBytes) / CGFloat(info.totalBytes))
                        
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(info.transcriptBytes) / CGFloat(info.totalBytes))
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
            
            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                    Text("Audio: \(info.audioFormatted)")
                        .font(.caption)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text("Transcripts: \(info.transcriptFormatted)")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.subheadline.bold())
            
            Toggle(isOn: Binding(
                get: { viewModel.keepAudioFiles },
                set: { _ in viewModel.toggleKeepAudioFiles() }
            )) {
                VStack(alignment: .leading) {
                    Text("Keep Audio Files")
                    Text("Audio chunks will be preserved after transcription. Disabling saves storage.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                Text("Delete meetings older than:")
                
                Picker("", selection: $selectedDaysToDelete) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("1 year").tag(365)
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                
                Button("Delete...") {
                    viewModel.confirmDeleteOldMeetings(olderThan: selectedDaysToDelete)
                }
                .buttonStyle(.bordered)
            }
            
            Button("Clean Up Orphan Files") {
                viewModel.cleanupOrphans()
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Meetings Section
    
    private var meetingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meetings by Size")
                .font(.subheadline.bold())
            
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.meetingsBySize.isEmpty {
                Text("No meetings")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.meetingsBySize.prefix(10), id: \.0.id) { meeting, size in
                            meetingRow(meeting: meeting, size: size)
                        }
                        
                        if viewModel.meetingsBySize.count > 10 {
                            Text("... and \(viewModel.meetingsBySize.count - 10) more")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
    
    private func meetingRow(meeting: MeetingRecord, size: Int64) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(meeting.title)
                    .lineLimit(1)
                Text(meeting.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .foregroundStyle(.secondary)
            
            if meeting.audioKept {
                Button {
                    viewModel.deleteAudioForMeeting(meeting)
                } label: {
                    Image(systemName: "waveform.slash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Delete audio files")
            }
            
            Button(role: .destructive) {
                viewModel.deleteMeeting(meeting)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    StorageManagementView()
}
