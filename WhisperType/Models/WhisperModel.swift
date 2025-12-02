//
//  WhisperModel.swift
//  WhisperType
//
//  Defines available Whisper models and their metadata.
//

import Foundation

// MARK: - Whisper Model Type

enum WhisperModelType: String, CaseIterable, Identifiable {

    // English-only models
    case tinyEn = "tiny.en"
    case baseEn = "base.en"
    case smallEn = "small.en"
    case mediumEn = "medium.en"

    // Multilingual models
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case large = "large-v3"

    var id: String { rawValue }

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .tinyEn: return "Tiny (English)"
        case .baseEn: return "Base (English)"
        case .smallEn: return "Small (English)"
        case .mediumEn: return "Medium (English)"
        case .tiny: return "Tiny (Multilingual)"
        case .base: return "Base (Multilingual)"
        case .small: return "Small (Multilingual)"
        case .medium: return "Medium (Multilingual)"
        case .large: return "Large V3 (Multilingual)"
        }
    }

    var fileName: String {
        switch self {
        case .tinyEn: return "ggml-tiny.en.bin"
        case .baseEn: return "ggml-base.en.bin"
        case .smallEn: return "ggml-small.en.bin"
        case .mediumEn: return "ggml-medium.en.bin"
        case .tiny: return "ggml-tiny.bin"
        case .base: return "ggml-base.bin"
        case .small: return "ggml-small.bin"
        case .medium: return "ggml-medium.bin"
        case .large: return "ggml-large-v3.bin"
        }
    }

    var downloadURL: URL {
        Constants.URLs.modelDownloadURL(filename: fileName)
    }

    // MARK: - File Size (approximate, in MB)

    var fileSizeMB: Int {
        switch self {
        case .tinyEn, .tiny: return 75
        case .baseEn, .base: return 142
        case .smallEn, .small: return 466
        case .mediumEn, .medium: return 1500
        case .large: return 3100
        }
    }

    var fileSizeFormatted: String {
        if fileSizeMB < 1000 {
            return "\(fileSizeMB) MB"
        } else {
            let gb = Double(fileSizeMB) / 1000.0
            return String(format: "%.1f GB", gb)
        }
    }

    // MARK: - Performance Ratings

    /// Speed rating: 1 (slowest) to 5 (fastest)
    var speedRating: Int {
        switch self {
        case .tinyEn, .tiny: return 5
        case .baseEn, .base: return 4
        case .smallEn, .small: return 3
        case .mediumEn, .medium: return 2
        case .large: return 1
        }
    }

    /// Accuracy rating: 1 (lowest) to 5 (highest)
    var accuracyRating: Int {
        switch self {
        case .tinyEn, .tiny: return 2
        case .baseEn, .base: return 3
        case .smallEn, .small: return 4
        case .mediumEn, .medium: return 4
        case .large: return 5
        }
    }

    var speedDescription: String {
        switch speedRating {
        case 5: return "Very Fast"
        case 4: return "Fast"
        case 3: return "Moderate"
        case 2: return "Slow"
        case 1: return "Very Slow"
        default: return "Unknown"
        }
    }

    var accuracyDescription: String {
        switch accuracyRating {
        case 5: return "Excellent"
        case 4: return "Good"
        case 3: return "Fair"
        case 2: return "Basic"
        case 1: return "Poor"
        default: return "Unknown"
        }
    }

    // MARK: - Description

    var description: String {
        let langInfo = isEnglishOnly ? "English only" : "74+ languages"
        let perfInfo = "\(speedDescription) • \(accuracyDescription) accuracy"
        return "\(langInfo) • \(fileSizeFormatted) • \(perfInfo)"
    }
    
    /// Short description for compact UI elements
    var shortDescription: String {
        let langInfo = isEnglishOnly ? "EN" : "Multi"
        return "\(langInfo) • \(fileSizeFormatted)"
    }

    var detailedDescription: String {
        let lang = isEnglishOnly ? "optimized for English" : "supports 74+ languages"
        return """
        \(displayName) is \(lang). It provides \(accuracyDescription.lowercased()) \
        accuracy with \(speedDescription.lowercased()) transcription speed. \
        Model size: \(fileSizeFormatted).
        """
    }

    // MARK: - Language Support

    var isEnglishOnly: Bool {
        switch self {
        case .tinyEn, .baseEn, .smallEn, .mediumEn:
            return true
        case .tiny, .base, .small, .medium, .large:
            return false
        }
    }

    var isMultilingual: Bool {
        return !isEnglishOnly
    }

    var supportedLanguages: String {
        isEnglishOnly ? "English" : "English, Spanish, French, German, Italian, Portuguese, Dutch, Russian, Chinese, Japanese, Korean, and 60+ more"
    }

    // MARK: - Recommendations

    /// Recommended use case for this model
    var recommendedFor: String {
        switch self {
        case .tinyEn, .tiny:
            return "Quick testing, low-end hardware, or when speed is critical"
        case .baseEn, .base:
            return "Balanced performance for everyday use"
        case .smallEn, .small:
            return "Good accuracy for most applications"
        case .mediumEn, .medium:
            return "High accuracy for professional use"
        case .large:
            return "Maximum accuracy for critical applications"
        }
    }

    // MARK: - System Requirements

    var minimumRAM: String {
        switch self {
        case .tinyEn, .tiny: return "2 GB"
        case .baseEn, .base: return "3 GB"
        case .smallEn, .small: return "6 GB"
        case .mediumEn, .medium: return "12 GB"
        case .large: return "16 GB"
        }
    }
    
    // MARK: - SHA256 Checksums
    
    /// SHA256 checksum for model file verification.
    /// Note: These checksums are from the ggerganov/whisper.cpp Hugging Face repository.
    /// If nil, checksum verification is skipped during download.
    /// TODO: Update checksums when model versions stabilize
    var sha256Checksum: String? {
        // Disabled for now - model files on Hugging Face are frequently updated
        // and checksums change. Re-enable once we pin to specific model versions.
        return nil
    }

    // MARK: - Helpers

    /// Get model by filename
    static func fromFileName(_ fileName: String) -> WhisperModelType? {
        return WhisperModelType.allCases.first { $0.fileName == fileName }
    }

    /// Get model by ID
    static func fromID(_ id: String) -> WhisperModelType? {
        return WhisperModelType(rawValue: id)
    }

    /// Recommended models for first-time users
    static var recommended: [WhisperModelType] {
        return [.baseEn, .base, .smallEn]
    }

    /// Fastest models (good for testing)
    static var fastest: [WhisperModelType] {
        return [.tinyEn, .tiny, .baseEn, .base]
    }

    /// Most accurate models
    static var mostAccurate: [WhisperModelType] {
        return [.large, .mediumEn, .medium]
    }
}

// MARK: - Model Download State

enum ModelDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double) // 0.0 to 1.0
    case downloaded
    case failed(error: String)

    var isDownloaded: Bool {
        if case .downloaded = self {
            return true
        }
        return false
    }

    var isDownloading: Bool {
        if case .downloading = self {
            return true
        }
        return false
    }

    var canDownload: Bool {
        switch self {
        case .notDownloaded, .failed:
            return true
        default:
            return false
        }
    }
}
