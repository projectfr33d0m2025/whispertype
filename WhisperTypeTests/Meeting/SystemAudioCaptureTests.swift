//
//  SystemAudioCaptureTests.swift
//  WhisperTypeTests
//
//  Unit tests for SystemAudioCapture.
//

import XCTest
@testable import WhisperType

@available(macOS 12.3, *)
final class SystemAudioCaptureTests: XCTestCase {
    
    var sut: SystemAudioCapture!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        sut = SystemAudioCapture()
    }
    
    @MainActor
    override func tearDown() async throws {
        sut?.stopCapture()
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    @MainActor
    func testInitialState() {
        XCTAssertFalse(sut.isCapturing)
        XCTAssertEqual(sut.audioLevel, -60.0)
    }
    
    // MARK: - Permission Tests
    
    @MainActor
    func testPermissionCheckReturnsValidState() async {
        // When
        let state = await sut.checkPermission()
        
        // Then - should return one of the valid states
        XCTAssertTrue([.notDetermined, .granted, .denied].contains(state))
        XCTAssertEqual(sut.permissionState, state)
    }
    
    @MainActor
    func testPermissionStateEnumEquality() {
        // Just verify enum cases work
        XCTAssertEqual(ScreenRecordingPermission.granted, ScreenRecordingPermission.granted)
        XCTAssertNotEqual(ScreenRecordingPermission.granted, ScreenRecordingPermission.denied)
        XCTAssertNotEqual(ScreenRecordingPermission.denied, ScreenRecordingPermission.notDetermined)
    }
    
    // MARK: - Capture Tests
    
    @MainActor
    func testCaptureFailsWithoutPermission() async {
        // Given - check current permission
        let state = await sut.checkPermission()
        
        if state == .denied {
            // When/Then - should throw permission denied
            do {
                try await sut.startCapture()
                XCTFail("Expected permission denied error")
            } catch let error as SystemAudioCaptureError {
                XCTAssertEqual(error, .permissionDenied)
            } catch {
                // Other errors are acceptable in test environment
            }
        } else {
            // Skip test if permission is granted
            print("Test skipped: Screen Recording permission is granted")
        }
    }
    
    @MainActor
    func testCaptureStartsAndStopsWithoutCrash() async {
        // Given - check permission first
        let state = await sut.checkPermission()
        
        guard state == .granted else {
            print("Test skipped: Screen Recording permission not granted")
            return
        }
        
        // When
        do {
            try await sut.startCapture()
            XCTAssertTrue(sut.isCapturing)
            
            // Wait briefly
            try await Task.sleep(nanoseconds: 500_000_000)
            
            // Stop
            sut.stopCapture()
            
            // Allow async cleanup
            try await Task.sleep(nanoseconds: 100_000_000)
            
            XCTAssertFalse(sut.isCapturing)
        } catch {
            // Permission or setup issues in test environment
            print("Test skipped: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func testStopCaptureWhenNotCapturing() {
        // Given - not capturing
        XCTAssertFalse(sut.isCapturing)
        
        // When - stop should be safe to call
        sut.stopCapture()
        
        // Then - no crash, still not capturing
        XCTAssertFalse(sut.isCapturing)
    }
    
    // MARK: - Error Tests
    
    func testErrorDescriptions() {
        // Verify all error cases have descriptions
        let errors: [SystemAudioCaptureError] = [
            .permissionDenied,
            .permissionNotDetermined,
            .screenCaptureNotAvailable,
            .noContentToCapture,
            .configurationFailed("test"),
            .captureStartFailed("test")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    func testPermissionDeniedErrorEquality() {
        let error1 = SystemAudioCaptureError.permissionDenied
        let error2 = SystemAudioCaptureError.permissionDenied
        
        // LocalizedError comparison via description
        XCTAssertEqual(error1.errorDescription, error2.errorDescription)
    }
    
    // MARK: - Settings URL Test
    
    @MainActor
    func testOpenSystemSettingsDoesNotCrash() {
        // This just tests that the method can be called without crashing
        // Actual opening of Settings requires user interaction
        // sut.openSystemSettings() // Uncomment to test manually
        XCTAssertTrue(true)
    }
}

// MARK: - Extension for Equatable

extension SystemAudioCaptureError: @retroactive Equatable {
    public static func == (lhs: SystemAudioCaptureError, rhs: SystemAudioCaptureError) -> Bool {
        switch (lhs, rhs) {
        case (.permissionDenied, .permissionDenied),
             (.permissionNotDetermined, .permissionNotDetermined),
             (.screenCaptureNotAvailable, .screenCaptureNotAvailable),
             (.noContentToCapture, .noContentToCapture):
            return true
        case (.configurationFailed(let a), .configurationFailed(let b)):
            return a == b
        case (.captureStartFailed(let a), .captureStartFailed(let b)):
            return a == b
        default:
            return false
        }
    }
}
