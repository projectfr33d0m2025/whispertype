//
//  MeetingDetailView.swift
//  WhisperType
//
//  Detail view for a single meeting with tabs for Summary, Transcript, and Action Items.
//

import SwiftUI

// MARK: - Detail Tab

enum MeetingDetailTab: String, CaseIterable {
    case summary = "Summary"
    case transcript = "Transcript"
    case actionItems = "Action Items"
    
    var icon: String {
        switch self {
        case .summary: return "doc.text"
        case .transcript: return "text.quote"
        case .actionItems: return "checklist"
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
    @State private var showingExportSheet: Bool = false
    @State private var copyFeedback: String?
    
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
            ForEach(MeetingDetailTab.allCases, id: \.self) { tab in
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
                
                if tab != MeetingDetailTab.allCases.last {
                    Divider()
                        .frame(height: 20)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
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

struct SummaryTabView: View {
    let content: String
    
    var body: some View {
        ScrollView {
            Text(content)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Transcript Tab View

struct TranscriptTabView: View {
    let content: String
    
    var body: some View {
        ScrollView {
            Text(content)
                .textSelection(.enabled)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(Color(nsColor: .textBackgroundColor))
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
