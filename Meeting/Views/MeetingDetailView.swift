//
//  MeetingDetailView.swift
//  WhisperType
//
//  Detail view for a single meeting with tabs for Summary, Transcript, and Action Items.
//

import SwiftUI
import MarkdownUI
import AVFoundation

// MARK: - Audio Player View Model

@MainActor
class AudioPlayerViewModel: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var currentlyPlayingURL: URL?
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    // Called by the view before it disappears to ensure clean cleanup
    func cleanup() {
        timer?.invalidate()
        timer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentlyPlayingURL = nil
    }
    
    func loadAudio(url: URL) {
        stop()
        errorMessage = nil
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            currentlyPlayingURL = url
        } catch {
            errorMessage = "Unable to load audio file: \(error.localizedDescription)"
            print("AudioPlayerViewModel: Failed to load audio - \(error)")
        }
    }
    
    func play() {
        guard let player = audioPlayer else { return }
        
        player.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        currentlyPlayingURL = nil
        stopTimer()
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    // MARK: - Private Methods
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            // Wrap in Task to avoid "Publishing changes from within view updates"
            Task { @MainActor in
                guard let self = self, let player = self.audioPlayer else { return }
                
                self.currentTime = player.currentTime
                
                // Auto-stop when finished
                if !player.isPlaying && self.isPlaying {
                    self.stop()
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Audio Player View

struct AudioPlayerView: View {
    let audioURL: URL
    let chunkName: String
    @ObservedObject var viewModel: AudioPlayerViewModel
    
    init(audioURL: URL, chunkName: String, viewModel: AudioPlayerViewModel) {
        self.audioURL = audioURL
        self.chunkName = chunkName
        self.viewModel = viewModel
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause button
            Button {
                if viewModel.currentlyPlayingURL != audioURL {
                    viewModel.loadAudio(url: audioURL)
                    viewModel.play()
                } else {
                    if viewModel.isPlaying {
                        viewModel.pause()
                    } else {
                        viewModel.play()
                    }
                }
            } label: {
                Image(systemName: (viewModel.currentlyPlayingURL == audioURL && viewModel.isPlaying) ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.errorMessage != nil)
            
            // Stop button
            Button {
                if viewModel.currentlyPlayingURL == audioURL {
                    viewModel.stop()
                }
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentlyPlayingURL != audioURL)
            
            VStack(alignment: .leading, spacing: 4) {
                // Chunk name
                Text(chunkName)
                    .font(.body)
                
                // Progress and time
                if viewModel.currentlyPlayingURL == audioURL {
                    HStack(spacing: 8) {
                        Text(formatTime(viewModel.currentTime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        
                        Slider(
                            value: Binding(
                                get: { viewModel.currentTime },
                                set: { viewModel.seek(to: $0) }
                            ),
                            in: 0...max(viewModel.duration, 1)
                        )
                        .controlSize(.small)
                        
                        Text(formatTime(viewModel.duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } else {
                    // Show duration when not playing
                    if let duration = getAudioDuration(url: audioURL) {
                        Text(formatTime(duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(viewModel.currentlyPlayingURL == audioURL ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
        )
        .overlay(
            Group {
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                }
            }
        )
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func getAudioDuration(url: URL) -> TimeInterval? {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            return player.duration
        } catch {
            return nil
        }
    }
}

// ... (existing code)


enum MeetingDetailTab: String, CaseIterable {
    case summary = "Summary"
    case transcript = "Transcript"
    case actionItems = "Action Items"
    case audio = "Audio"
    
    var icon: String {
        switch self {
        case .summary: return "doc.text"
        case .transcript: return "text.quote"
        case .actionItems: return "checklist"
        case .audio: return "waveform"
        }
    }
}

// MARK: - Meeting Detail View

struct MeetingDetailView: View {
    let meeting: MeetingRecord
    let onTitleChange: (String) -> Void
    let onDelete: () -> Void
    
    @State private var selectedTab: MeetingDetailTab = .summary
    @State private var isEditingTitle: Bool = false
    @State private var editedTitle: String = ""
    @State private var summaryContent: String = ""
    @State private var transcriptContent: String = ""
    @State private var actionItems: [MeetingActionItem] = []
    @State private var audioChunks: [URL] = []
    @State private var showingExportSheet: Bool = false
    @State private var copyFeedback: String?
    @StateObject private var audioPlayerViewModel = AudioPlayerViewModel()
    
    private let fileManager = MeetingFileManager.shared
    private let database = MeetingDatabase.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Tab picker
            tabPicker
            
            Divider()
            
            // Content
            tabContent
        }
        .onAppear {
            loadContent()
        }
        .onDisappear {
            // Clean up audio player BEFORE view is destroyed to prevent deinit crash
            audioPlayerViewModel.cleanup()
        }
        .onChange(of: meeting.id) { _ in
            loadContent()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title (editable)
            HStack {
                if isEditingTitle {
                    TextField("Meeting Title", text: $editedTitle, onCommit: {
                        saveTitle()
                    })
                    .textFieldStyle(.plain)
                    .font(.title2.bold())
                    
                    Button {
                        saveTitle()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        isEditingTitle = false
                        editedTitle = meeting.title
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(meeting.title)
                        .font(.title2.bold())
                    
                    Button {
                        editedTitle = meeting.title
                        isEditingTitle = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    // Copy button with feedback
                    Button {
                        copyToClipboard()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: copyFeedback != nil ? "checkmark" : "doc.on.doc")
                            if let feedback = copyFeedback {
                                Text(feedback)
                                    .font(.caption)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    // Export button
                    Button {
                        showingExportSheet = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    
                    // Delete button
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Metadata
            HStack(spacing: 16) {
                Label(meeting.formattedDate, systemImage: "calendar")
                Label(meeting.formattedDuration, systemImage: "clock")
                
                if meeting.speakerCount > 0 {
                    Label("\(meeting.speakerCount) speaker\(meeting.speakerCount == 1 ? "" : "s")", systemImage: "person.2")
                }
                
                if let template = meeting.templateUsed {
                    Label(template.capitalized, systemImage: "doc.text")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .fileExporter(
            isPresented: $showingExportSheet,
            document: MeetingExportDocument(meeting: meeting, summary: summaryContent, transcript: transcriptContent),
            contentType: .text,
            defaultFilename: "\(meeting.title).md"
        ) { result in
            switch result {
            case .success(let url):
                print("MeetingDetailView: Exported to \(url.path)")
            case .failure(let error):
                print("MeetingDetailView: Export failed - \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Tabs
    
    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(availableTabs, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                
                if tab != availableTabs.last {
                    Divider()
                        .frame(height: 20)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    // Only show audio tab if audio files are kept
    private var availableTabs: [MeetingDetailTab] {
        if meeting.audioKept {
            return MeetingDetailTab.allCases
        } else {
            return MeetingDetailTab.allCases.filter { $0 != .audio }
        }
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .summary:
            SummaryTabView(content: summaryContent)
        case .transcript:
            TranscriptTabView(content: transcriptContent)
        case .actionItems:
            ActionItemsTabView(items: $actionItems, database: database)
        case .audio:
            AudioTabView(audioChunks: audioChunks, viewModel: audioPlayerViewModel)
        }
    }
    
    // MARK: - Actions
    
    private func loadContent() {
        let sessionDir = URL(fileURLWithPath: meeting.sessionDirectory)
        
        // Load summary
        if let summaryFile = meeting.summaryFile {
            let summaryURL = sessionDir.appendingPathComponent(summaryFile)
            summaryContent = (try? String(contentsOf: summaryURL, encoding: .utf8)) ?? "No summary available."
        } else {
            summaryContent = "No summary available."
        }
        
        // Load transcript
        if let transcriptFile = meeting.transcriptFile {
            let transcriptURL = sessionDir.appendingPathComponent(transcriptFile)
            transcriptContent = (try? String(contentsOf: transcriptURL, encoding: .utf8)) ?? "No transcript available."
        } else {
            transcriptContent = "No transcript available."
        }
        
        // Load action items
        actionItems = (try? database.getActionItems(meetingId: meeting.id)) ?? []
        
        // Load audio chunks if available
        if meeting.audioKept {
            let audioDir = sessionDir.appendingPathComponent("audio")
            if FileManager.default.fileExists(atPath: audioDir.path) {
                let chunks = (try? FileManager.default.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil))
                    .map { $0.filter { $0.pathExtension == "wav" }.sorted { $0.lastPathComponent < $1.lastPathComponent } } ?? []
                audioChunks = chunks
            }
        }
    }
    
    private func saveTitle() {
        if !editedTitle.isEmpty && editedTitle != meeting.title {
            onTitleChange(editedTitle)
        }
        isEditingTitle = false
    }
    
    private func copyToClipboard() {
        let content: String
        switch selectedTab {
        case .summary:
            content = summaryContent
        case .transcript:
            content = transcriptContent
        case .actionItems:
            content = actionItems.map { "- \($0.actionText)" }.joined(separator: "\n")
        case .audio:
            content = "Audio files from this meeting"
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        
        copyFeedback = "Copied!"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copyFeedback = nil
        }
    }
}

// MARK: - Summary Tab View

// MARK: - Summary Tab View

struct SummaryTabView: View {
    let content: String
    
    var body: some View {
        ScrollView {
            Markdown(preprocess(content))
                .textSelection(.enabled)
                .markdownTheme(.whisperType)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private func preprocess(_ text: String) -> String {
        return text.replacingOccurrences(of: "\n", with: "  \n")
    }
}

// MARK: - Transcript Tab View

struct TranscriptTabView: View {
    let content: String
    
    var body: some View {
        ScrollView {
            Markdown(preprocess(content))
                .textSelection(.enabled)
                .markdownTheme(.whisperType)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private func preprocess(_ text: String) -> String {
        return text.replacingOccurrences(of: "\n", with: "  \n")
    }
}

// MARK: - Action Items Tab View

struct ActionItemsTabView: View {
    @Binding var items: [MeetingActionItem]
    let database: MeetingDatabase
    
    var body: some View {
        if items.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "checklist")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Action Items")
                    .font(.headline)
                Text("No action items were extracted from this meeting.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach($items) { $item in
                    ActionItemRow(item: $item) { completed in
                        try? database.updateActionItemCompletion(id: item.id, completed: completed)
                    }
                }
            }
        }
    }
}

// MARK: - Action Item Row

struct ActionItemRow: View {
    @Binding var item: MeetingActionItem
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                item.completed.toggle()
                onToggle(item.completed)
            } label: {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.completed ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.actionText)
                    .strikethrough(item.completed)
                    .foregroundStyle(item.completed ? .secondary : .primary)
                
                HStack(spacing: 8) {
                    if let assignee = item.assignee, !assignee.isEmpty {
                        Label(assignee, systemImage: "person")
                    }
                    if let dueDate = item.dueDate, !dueDate.isEmpty {
                        Label(dueDate, systemImage: "calendar")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Audio Tab View

struct AudioTabView: View {
    let audioChunks: [URL]
    @ObservedObject var viewModel: AudioPlayerViewModel
    
    var body: some View {
        if audioChunks.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "waveform.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Audio Files")
                    .font(.headline)
                Text("Audio files were not preserved for this meeting.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Image(systemName: "waveform")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recorded Audio")
                                .font(.headline)
                            Text("\(audioChunks.count) chunk\(audioChunks.count == 1 ? "" : "s"), \(totalDuration)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 8)
                    
                    // Audio chunks
                    ForEach(Array(audioChunks.enumerated()), id: \.offset) { index, url in
                        AudioPlayerView(
                            audioURL: url,
                            chunkName: chunkName(for: index, url: url),
                            viewModel: viewModel
                        )
                    }
                }
                .padding()
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
    
    // MARK: - Helpers
    
    private var totalDuration: String {
        var total: TimeInterval = 0
        for url in audioChunks {
            if let player = try? AVAudioPlayer(contentsOf: url) {
                total += player.duration
            }
        }
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        return String(format: "%d:%02d total", minutes, seconds)
    }
    
    private func chunkName(for index: Int, url: URL) -> String {
        let chunkNumber = index + 1
        let startTime = index * 30 // Assuming 30 second chunks
        let endTime = startTime + 30
        return String(format: "Chunk %d: %02d:%02d - %02d:%02d", 
                     chunkNumber,
                     startTime / 60, startTime % 60,
                     endTime / 60, endTime % 60)
    }
}

// MARK: - Export Document

struct MeetingExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.text, .plainText] }
    
    let meeting: MeetingRecord
    let summary: String
    let transcript: String
    
    init(meeting: MeetingRecord, summary: String, transcript: String) {
        self.meeting = meeting
        self.summary = summary
        self.transcript = transcript
    }
    
    init(configuration: ReadConfiguration) throws {
        meeting = MeetingRecord(
            id: "",
            title: "",
            createdAt: Date(),
            durationSeconds: 0,
            audioSource: "",
            speakerCount: 0,
            status: .complete,
            errorMessage: nil,
            sessionDirectory: "",
            transcriptFile: nil,
            summaryFile: nil,
            audioKept: false,
            summaryPreview: nil,
            templateUsed: nil
        )
        summary = ""
        transcript = ""
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let content = MeetingExporter.shared.exportToMarkdown(
            meeting: meeting,
            summary: summary,
            transcript: transcript
        )
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - UTType Extension

import UniformTypeIdentifiers

// MARK: - Preview

#Preview {
    MeetingDetailView(
        meeting: MeetingRecord(
            id: "preview",
            title: "Preview Meeting",
            createdAt: Date(),
            durationSeconds: 1800,
            audioSource: "both",
            speakerCount: 2,
            status: .complete,
            errorMessage: nil,
            sessionDirectory: "/tmp",
            transcriptFile: nil,
            summaryFile: nil,
            audioKept: false,
            summaryPreview: "This is a preview of the summary...",
            templateUsed: "standard"
        ),
        onTitleChange: { _ in },
        onDelete: {}
    )
}

// MARK: - Custom Theme

extension Theme {
    static let whisperType = Theme.gitHub
        .text {
            FontSize(13)
        }
        .heading1 { configuration in
            VStack(alignment: .leading, spacing: 0) {
                configuration.label
                    .markdownMargin(top: 24, bottom: 16)
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(18)
                    }
                Divider()
            }
        }
        .heading2 { configuration in
            configuration.label
                .markdownMargin(top: 16, bottom: 8)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(15)
                }
        }
        .heading3 { configuration in
            configuration.label
                .markdownMargin(top: 16, bottom: 8)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(14)
                }
        }
}
