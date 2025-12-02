//
//  ModelManager.swift
//  WhisperType
//
//  Manages Whisper model downloads, storage, and switching.
//

import Foundation
import CryptoKit

// MARK: - Model Manager Errors

enum ModelManagerError: LocalizedError {
    case downloadFailed(String)
    case checksumMismatch(expected: String, actual: String)
    case fileOperationFailed(String)
    case modelNotDownloaded
    case downloadCancelled
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .checksumMismatch(let expected, let actual):
            return "Checksum verification failed. Expected: \(expected.prefix(16))..., Got: \(actual.prefix(16))..."
        case .fileOperationFailed(let reason):
            return "File operation failed: \(reason)"
        case .modelNotDownloaded:
            return "Model is not downloaded"
        case .downloadCancelled:
            return "Download was cancelled"
        case .networkError(let reason):
            return "Network error: \(reason)"
        }
    }
}

// MARK: - Download Progress

struct DownloadProgress: Equatable {
    let bytesWritten: Int64
    let totalBytes: Int64
    
    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesWritten) / Double(totalBytes)
    }
    
    var progressPercent: Int {
        Int(progress * 100)
    }
    
    var formattedProgress: String {
        let written = ByteCountFormatter.string(fromByteCount: bytesWritten, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        return "\(written) / \(total)"
    }
}


// MARK: - Model Manager

@MainActor
class ModelManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ModelManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var downloadStates: [WhisperModelType: ModelDownloadState] = [:]
    @Published private(set) var activeModel: WhisperModelType?
    @Published private(set) var isInitialized = false
    
    // MARK: - Private Properties
    
    private var downloadTasks: [WhisperModelType: URLSessionDownloadTask] = [:]
    private var downloadDelegates: [WhisperModelType: DownloadDelegate] = [:]
    private var urlSession: URLSession?
    
    // MARK: - Computed Properties
    
    var modelsDirectory: URL {
        Constants.Paths.models
    }
    
    var downloadedModels: [WhisperModelType] {
        WhisperModelType.allCases.filter { isModelDownloaded($0) }
    }
    
    var hasActiveModel: Bool {
        activeModel != nil && isModelDownloaded(activeModel!)
    }

    
    // MARK: - Initialization
    
    private init() {
        print("ModelManager: Initializing...")
        setupURLSession()
        loadDownloadedModels()
        loadActiveModel()
        isInitialized = true
        print("ModelManager: Initialized. Downloaded models: \(downloadedModels.map { $0.rawValue })")
    }
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600 // 1 hour for large models
        urlSession = URLSession(configuration: config)
    }
    
    // MARK: - Model Path Helpers
    
    func modelPath(for model: WhisperModelType) -> URL {
        modelsDirectory.appendingPathComponent(model.fileName)
    }
    
    func isModelDownloaded(_ model: WhisperModelType) -> Bool {
        let path = modelPath(for: model)
        let exists = FileManager.default.fileExists(atPath: path.path)
        
        // Also verify file is not empty
        if exists {
            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: path.path)
                let size = attrs[.size] as? Int64 ?? 0
                return size > 0
            } catch {
                return false
            }
        }
        return false
    }

    
    // MARK: - Load State
    
    func loadDownloadedModels() {
        print("ModelManager: Scanning for downloaded models...")
        
        for model in WhisperModelType.allCases {
            if isModelDownloaded(model) {
                downloadStates[model] = .downloaded
                print("ModelManager: Found downloaded model: \(model.rawValue)")
            } else {
                downloadStates[model] = .notDownloaded
            }
        }
    }
    
    func loadActiveModel() {
        let savedModelId = AppSettings.shared.activeModelId
        
        if let model = WhisperModelType.fromID(savedModelId) {
            if isModelDownloaded(model) {
                activeModel = model
                print("ModelManager: Loaded active model: \(model.rawValue)")
            } else {
                // Saved model not downloaded, try to find another
                if let firstDownloaded = downloadedModels.first {
                    activeModel = firstDownloaded
                    AppSettings.shared.activeModelId = firstDownloaded.rawValue
                    print("ModelManager: Saved model not downloaded. Switched to: \(firstDownloaded.rawValue)")
                } else {
                    activeModel = nil
                    print("ModelManager: No models downloaded")
                }
            }
        } else {
            activeModel = downloadedModels.first
            if let active = activeModel {
                AppSettings.shared.activeModelId = active.rawValue
            }
        }
    }

    
    // MARK: - Download Model
    
    func downloadModel(_ model: WhisperModelType) async throws {
        // Check if already downloading or downloaded
        if case .downloading = downloadStates[model] {
            print("ModelManager: Model \(model.rawValue) is already downloading")
            return
        }
        
        if isModelDownloaded(model) {
            print("ModelManager: Model \(model.rawValue) is already downloaded")
            downloadStates[model] = .downloaded
            return
        }
        
        print("ModelManager: Starting download for \(model.rawValue) from \(model.downloadURL)")
        
        // Set initial downloading state
        downloadStates[model] = .downloading(progress: 0)
        
        // Create download delegate for progress tracking
        let delegate = DownloadDelegate { [weak self] progress in
            Task { @MainActor in
                self?.downloadStates[model] = .downloading(progress: progress.progress)
            }
        }
        downloadDelegates[model] = delegate
        
        // Create dedicated session with delegate
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 7200 // 2 hours for large models
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        
        let request = URLRequest(url: model.downloadURL)
        let task = session.downloadTask(with: request)
        downloadTasks[model] = task
        
        // Start download and wait for completion
        delegate.startContinuation()
        task.resume()
        
        do {
            let (tempURL, response) = try await delegate.waitForCompletion()
            
            // Verify response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ModelManagerError.downloadFailed("Invalid response")
            }
            
            guard httpResponse.statusCode == 200 else {
                throw ModelManagerError.downloadFailed("HTTP \(httpResponse.statusCode)")
            }
            
            // Verify checksum if available
            if let expectedChecksum = model.sha256Checksum {
                print("ModelManager: Verifying checksum for \(model.rawValue)...")
                let actualChecksum = try computeSHA256(for: tempURL)
                
                if actualChecksum.lowercased() != expectedChecksum.lowercased() {
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: tempURL)
                    throw ModelManagerError.checksumMismatch(expected: expectedChecksum, actual: actualChecksum)
                }
                print("ModelManager: Checksum verified for \(model.rawValue)")
            }
            
            // Move to final location
            let finalPath = modelPath(for: model)
            
            // Remove existing file if any
            if FileManager.default.fileExists(atPath: finalPath.path) {
                try FileManager.default.removeItem(at: finalPath)
            }
            
            try FileManager.default.moveItem(at: tempURL, to: finalPath)
            
            // Update state
            downloadStates[model] = .downloaded
            downloadTasks.removeValue(forKey: model)
            downloadDelegates.removeValue(forKey: model)
            
            print("ModelManager: Successfully downloaded \(model.rawValue) to \(finalPath.path)")
            
            // If no active model, set this as active
            if activeModel == nil {
                setActiveModel(model)
            }
            
            // Post notification
            NotificationCenter.default.post(name: .modelDownloaded, object: model)
            
        } catch {
            // Clean up on error
            downloadTasks.removeValue(forKey: model)
            downloadDelegates.removeValue(forKey: model)
            
            if case ModelManagerError.downloadCancelled = error {
                downloadStates[model] = .notDownloaded
            } else {
                downloadStates[model] = .failed(error: error.localizedDescription)
            }
            
            throw error
        }
    }

    
    // MARK: - SHA256 Checksum
    
    private func computeSHA256(for fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        
        var hasher = SHA256()
        let bufferSize = 1024 * 1024 // 1MB chunks
        
        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: bufferSize)
            if data.count > 0 {
                hasher.update(data: data)
                return true
            }
            return false
        }) {}
        
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    
    // MARK: - Cancel Download
    
    func cancelDownload(_ model: WhisperModelType) {
        print("ModelManager: Cancelling download for \(model.rawValue)")
        
        // Cancel the task
        if let task = downloadTasks[model] {
            task.cancel()
        }
        
        // Signal cancellation to delegate
        downloadDelegates[model]?.cancel()
        
        // Clean up
        downloadTasks.removeValue(forKey: model)
        downloadDelegates.removeValue(forKey: model)
        
        // Update state
        downloadStates[model] = .notDownloaded
        
        print("ModelManager: Download cancelled for \(model.rawValue)")
    }
    
    // MARK: - Delete Model
    
    func deleteModel(_ model: WhisperModelType) throws {
        let path = modelPath(for: model)
        
        guard FileManager.default.fileExists(atPath: path.path) else {
            print("ModelManager: Model \(model.rawValue) not found at \(path.path)")
            downloadStates[model] = .notDownloaded
            return
        }
        
        // If this is the active model, switch to another
        if activeModel == model {
            let otherModels = downloadedModels.filter { $0 != model }
            if let newActive = otherModels.first {
                setActiveModel(newActive)
            } else {
                activeModel = nil
                AppSettings.shared.activeModelId = ""
            }
        }
        
        // Delete the file
        try FileManager.default.removeItem(at: path)
        
        // Update state
        downloadStates[model] = .notDownloaded
        
        print("ModelManager: Deleted model \(model.rawValue)")
        
        // Post notification
        NotificationCenter.default.post(name: .modelDeleted, object: model)
    }

    
    // MARK: - Set Active Model
    
    func setActiveModel(_ model: WhisperModelType) {
        guard isModelDownloaded(model) else {
            print("ModelManager: Cannot set active model - \(model.rawValue) is not downloaded")
            return
        }
        
        let previousModel = activeModel
        activeModel = model
        AppSettings.shared.activeModelId = model.rawValue
        
        print("ModelManager: Active model changed from \(previousModel?.rawValue ?? "none") to \(model.rawValue)")
        
        // Post notification for other components (e.g., WhisperWrapper to reload)
        NotificationCenter.default.post(
            name: .activeModelChanged,
            object: model,
            userInfo: ["previousModel": previousModel as Any]
        )
    }
    
    // MARK: - Retry Failed Download
    
    func retryDownload(_ model: WhisperModelType) async throws {
        // Reset state and try again
        downloadStates[model] = .notDownloaded
        try await downloadModel(model)
    }
    
    // MARK: - Storage Info
    
    func modelFileSize(_ model: WhisperModelType) -> Int64? {
        let path = modelPath(for: model)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: path.path)
            return attrs[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    var totalStorageUsed: Int64 {
        downloadedModels.compactMap { modelFileSize($0) }.reduce(0, +)
    }
    
    var totalStorageFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalStorageUsed, countStyle: .file)
    }
}


// MARK: - Download Delegate

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    
    private let progressHandler: (DownloadProgress) -> Void
    private var continuation: CheckedContinuation<(URL, URLResponse), Error>?
    private var isCancelled = false
    
    init(progressHandler: @escaping (DownloadProgress) -> Void) {
        self.progressHandler = progressHandler
        super.init()
    }
    
    func startContinuation() {
        // Will be set when waitForCompletion is called
    }
    
    func waitForCompletion() async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }
    
    func cancel() {
        isCancelled = true
        continuation?.resume(throwing: ModelManagerError.downloadCancelled)
        continuation = nil
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, 
                    didFinishDownloadingTo location: URL) {
        guard !isCancelled else { return }
        
        guard let response = downloadTask.response else {
            continuation?.resume(throwing: ModelManagerError.downloadFailed("No response"))
            continuation = nil
            return
        }
        
        // Copy to temp location before continuation resumes (file will be deleted)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".bin")
        
        do {
            try FileManager.default.copyItem(at: location, to: tempURL)
            continuation?.resume(returning: (tempURL, response))
        } catch {
            continuation?.resume(throwing: ModelManagerError.fileOperationFailed(error.localizedDescription))
        }
        continuation = nil
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard !isCancelled else { return }
        
        let progress = DownloadProgress(
            bytesWritten: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite
        )
        progressHandler(progress)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, 
                    didCompleteWithError error: Error?) {
        guard !isCancelled else { return }
        
        if let error = error {
            if (error as NSError).code == NSURLErrorCancelled {
                continuation?.resume(throwing: ModelManagerError.downloadCancelled)
            } else {
                continuation?.resume(throwing: ModelManagerError.networkError(error.localizedDescription))
            }
            continuation = nil
        }
    }
}


// MARK: - Notification Names

extension Notification.Name {
    static let modelDownloaded = Notification.Name("com.whispertype.modelDownloaded")
    static let modelDeleted = Notification.Name("com.whispertype.modelDeleted")
    static let activeModelChanged = Notification.Name("com.whispertype.activeModelChanged")
}
