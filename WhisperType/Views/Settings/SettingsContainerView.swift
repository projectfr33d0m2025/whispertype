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
        case models = "Models"
        case hotkey = "Hotkey"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .processing: return "wand.and.stars"
            case .vocabulary: return "textformat.abc"
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

// MARK: - Preview

#Preview {
    SettingsContainerView()
}
