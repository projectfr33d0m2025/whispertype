//
//  WERCalculatorTests.swift
//  WhisperTypeTests
//
//  Unit tests for WERCalculator.
//

import XCTest
@testable import WhisperType

final class WERCalculatorTests: XCTestCase {
    
    // MARK: - Basic WER Tests
    
    func testPerfectMatch() {
        let reference = "The quick brown fox"
        let hypothesis = "The quick brown fox"
        
        let wer = WERCalculator.calculate(reference: reference, hypothesis: hypothesis)
        
        XCTAssertEqual(wer, 0.0, accuracy: 0.001, "Perfect match should have 0 WER")
    }
    
    func testCompletelyDifferent() {
        let reference = "The quick brown fox"
        let hypothesis = "A slow gray wolf"
        
        let wer = WERCalculator.calculate(reference: reference, hypothesis: hypothesis)
        
        XCTAssertEqual(wer, 1.0, accuracy: 0.001, "Completely different should have 1.0 WER")
    }
    
    func testPartialMatch() {
        let reference = "The quick brown fox"
        let hypothesis = "The slow brown dog"
        
        let wer = WERCalculator.calculate(reference: reference, hypothesis: hypothesis)
        
        // 2 substitutions out of 4 words = 0.5 WER
        XCTAssertEqual(wer, 0.5, accuracy: 0.001, "Two substitutions should have 0.5 WER")
    }
    
    func testCaseInsensitive() {
        let reference = "The Quick Brown Fox"
        let hypothesis = "the quick brown fox"
        
        let wer = WERCalculator.calculate(reference: reference, hypothesis: hypothesis)
        
        XCTAssertEqual(wer, 0.0, accuracy: 0.001, "Case differences should not affect WER")
    }
    
    func testPunctuationIgnored() {
        let reference = "Hello, world!"
        let hypothesis = "Hello world"
        
        let wer = WERCalculator.calculate(reference: reference, hypothesis: hypothesis)
        
        XCTAssertEqual(wer, 0.0, accuracy: 0.001, "Punctuation should be ignored")
    }
    
    // MARK: - Levenshtein Distance Tests
    
    func testLevenshteinIdentical() {
        let words = ["the", "quick", "brown"]
        
        let distance = WERCalculator.levenshteinDistance(words, words)
        
        XCTAssertEqual(distance, 0, "Identical arrays should have 0 distance")
    }
    
    func testLevenshteinSingleSubstitution() {
        let s1 = ["the", "quick", "brown"]
        let s2 = ["the", "slow", "brown"]
        
        let distance = WERCalculator.levenshteinDistance(s1, s2)
        
        XCTAssertEqual(distance, 1, "Single word difference is 1 edit")
    }
    
    func testLevenshteinInsertion() {
        let s1 = ["the", "brown", "fox"]
        let s2 = ["the", "quick", "brown", "fox"]
        
        let distance = WERCalculator.levenshteinDistance(s1, s2)
        
        XCTAssertEqual(distance, 1, "Single insertion is 1 edit")
    }
    
    func testLevenshteinDeletion() {
        let s1 = ["the", "quick", "brown", "fox"]
        let s2 = ["the", "brown", "fox"]
        
        let distance = WERCalculator.levenshteinDistance(s1, s2)
        
        XCTAssertEqual(distance, 1, "Single deletion is 1 edit")
    }
    
    func testLevenshteinEmpty() {
        let s1: [String] = []
        let s2 = ["hello", "world"]
        
        XCTAssertEqual(WERCalculator.levenshteinDistance(s1, s2), 2, "Empty to 2 words is 2 edits")
        XCTAssertEqual(WERCalculator.levenshteinDistance(s2, s1), 2, "2 words to empty is 2 edits")
        XCTAssertEqual(WERCalculator.levenshteinDistance(s1, s1), 0, "Empty to empty is 0 edits")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyReference() {
        let wer = WERCalculator.calculate(reference: "", hypothesis: "hello")
        XCTAssertEqual(wer, 1.0, "Empty reference with hypothesis should be 1.0")
    }
    
    func testEmptyHypothesis() {
        let wer = WERCalculator.calculate(reference: "hello world", hypothesis: "")
        XCTAssertEqual(wer, 1.0, "Reference with empty hypothesis should be 1.0")
    }
    
    func testBothEmpty() {
        let wer = WERCalculator.calculate(reference: "", hypothesis: "")
        XCTAssertEqual(wer, 0.0, "Both empty should be 0.0 WER")
    }
    
    // MARK: - Detailed Results Tests
    
    func testDetailedResult() {
        let reference = "The quick brown fox jumps"
        let hypothesis = "The slow brown dog"
        
        let result = WERCalculator.calculateDetailed(reference: reference, hypothesis: hypothesis)
        
        XCTAssertEqual(result.referenceWordCount, 5)
        XCTAssertEqual(result.hypothesisWordCount, 4)
        XCTAssertEqual(result.editDistance, 3) // slow, dog, -jumps
        XCTAssertFalse(result.isPassing) // > 20% WER
    }
    
    func testDetailedResultPassing() {
        let reference = "The quick brown fox"
        let hypothesis = "The quick brown dog"
        
        let result = WERCalculator.calculateDetailed(reference: reference, hypothesis: hypothesis)
        
        XCTAssertFalse(result.isPassing) // 25% WER, > 20% threshold
    }
    
    // MARK: - Tokenization Tests
    
    func testNormalizeAndTokenize() {
        let text = "Hello, World! This is a TEST."
        let tokens = WERCalculator.normalizeAndTokenize(text)
        
        XCTAssertEqual(tokens, ["hello", "world", "this", "is", "a", "test"])
    }
    
    func testNormalizePreservesContractions() {
        let text = "I'm don't won't"
        let tokens = WERCalculator.normalizeAndTokenize(text)
        
        XCTAssertEqual(tokens, ["i'm", "don't", "won't"])
    }
}
