//
//  SettingsContainerView.swift
//  WhisperType
//
//  Main settings window container with tab-based navigation.
//

import SwiftUI

struct SettingsContainerView: View {
    
    private enum SettingsTab: String, CaseIterable {
        case general = "General"
        case processing = "Processing"
        case vocabulary = "Vocabulary"
        case appRules = "App Rules"
        case meetings = "Meetings"
        case models = "Models"
        case hotkey = "Hotkey"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .processing: return "wand.and.stars"
            case .vocabulary: return "textformat.abc"
            case .appRules: return "app.badge.checkmark"
            case .meetings: return "person.3.fill"
            case .models: return "cpu"
            case .hotkey: return "keyboard"
            }
        }
    }
    
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label(SettingsTab.general.rawValue, systemImage: SettingsTab.general.icon)
                }
                .tag(SettingsTab.general)
            
            ProcessingSettingsView()
                .tabItem {
                    Label(SettingsTab.processing.rawValue, systemImage: SettingsTab.processing.icon)
                }
                .tag(SettingsTab.processing)
            
            VocabularySettingsView()
                .tabItem {
                    Label(SettingsTab.vocabulary.rawValue, systemImage: SettingsTab.vocabulary.icon)
                }
                .tag(SettingsTab.vocabulary)
            
            AppRulesSettingsView()
                .tabItem {
                    Label(SettingsTab.appRules.rawValue, systemImage: SettingsTab.appRules.icon)
                }
                .tag(SettingsTab.appRules)
            
            MeetingsSettingsTabView()
                .tabItem {
                    Label(SettingsTab.meetings.rawValue, systemImage: SettingsTab.meetings.icon)
                }
                .tag(SettingsTab.meetings)
            
            ModelsSettingsTabView()
                .tabItem {
                    Label(SettingsTab.models.rawValue, systemImage: SettingsTab.models.icon)
                }
                .tag(SettingsTab.models)
            
            HotkeySettingsView()
                .tabItem {
                    Label(SettingsTab.hotkey.rawValue, systemImage: SettingsTab.hotkey.icon)
                }
                .tag(SettingsTab.hotkey)
        }
        .frame(width: 550, height: 520)
        .onReceive(NotificationCenter.default.publisher(for: .switchToVocabularyTab)) { _ in
            selectedTab = .vocabulary
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToAppRulesTab)) { _ in
            selectedTab = .appRules
        }
    }
}

// MARK: - Models Tab Wrapper

/// Wrapper view for ModelSettingsView to fit the settings tab layout
struct ModelsSettingsTabView: View {
    var body: some View {
        ModelSettingsView()
            .padding(.top, 8)
    }
}

/// Wrapper view for Meetings/Summary Templates settings
struct MeetingsSettingsTabView: View {
    @StateObject private var viewModel = MeetingsSettingsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Template selection section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary Templates")
                        .font(.headline)
                    
                    TemplateListView()
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Storage settings section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Storage Settings")
                        .font(.headline)
                    
                    Toggle(isOn: Binding(
                        get: { viewModel.keepAudioFiles },
                        set: { _ in viewModel.toggleKeepAudioFiles() }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Keep Audio Files")
                            Text("Audio chunks will be preserved after transcription. Disabling saves storage space.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text("Note: This setting applies to new recordings. Existing meetings are not affected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Meetings Settings View Model

@MainActor
class MeetingsSettingsViewModel: ObservableObject {
    @Published var keepAudioFiles: Bool
    
    init() {
        keepAudioFiles = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.meetingKeepAudioFiles)
    }
    
    func toggleKeepAudioFiles() {
        keepAudioFiles.toggle()
        UserDefaults.standard.set(keepAudioFiles, forKey: Constants.UserDefaultsKeys.meetingKeepAudioFiles)
    }
}

// MARK: - Preview

#Preview {
    SettingsContainerView()
}
