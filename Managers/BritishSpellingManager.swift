//
//  BritishSpellingManager.swift
//  FloRight
//
//  Manages conversion from American to British spelling using JSON dictionary
//

import Foundation

class BritishSpellingManager {
    private var dictionary: SpellingDictionary?
    private var conversions: [String: String] = [:]
    private var preservedWords: Set<String> = []
    
    init() {
        loadDictionary()
    }
    
    private func loadDictionary() {
        guard let url = Bundle.main.url(forResource: "BritishSpellingDictionary", withExtension: "json") else {
            print("[FloRight] Error: British spelling dictionary not found in bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            dictionary = try JSONDecoder().decode(SpellingDictionary.self, from: data)
            
            if let dict = dictionary {
                conversions = dict.conversions
                preservedWords = Set(dict.preservedWords)
                print("[FloRight] British spelling dictionary loaded: \(dict.metadata.totalConversions) conversions")
            }
        } catch {
            print("[FloRight] Error loading British spelling dictionary: \(error)")
        }
    }
    
    func convertToBritishSpelling(_ text: String) -> String {
        // Check if UK spelling is enabled
        guard AppSettings.shared.useUKSpelling else {
            print("[FloRight] UK Spelling flag: false")
            return text
        }
        
        print("[FloRight] UK Spelling flag: true")
        print("[FloRight] Starting British spelling transformation...")
        
        // If dictionary failed to load, return original text
        guard !conversions.isEmpty else {
            print("[FloRight] British spelling dictionary not available, using original text")
            return text
        }
        
        var result = text
        var conversionsApplied = 0
        
        // Split text into words, preserving spaces and punctuation
        let words = result.components(separatedBy: .whitespacesAndNewlines)
        var processedWords: [String] = []
        
        for word in words {
            let processedWord = processWord(word)
            processedWords.append(processedWord)
            
            // Count if conversion was applied
            if processedWord != word {
                conversionsApplied += 1
            }
        }
        
        result = processedWords.joined(separator: " ")
        
        print("[FloRight] British spelling transformation completed: \(conversionsApplied) conversions applied")
        return result
    }
    
    private func processWord(_ word: String) -> String {
        // Extract the core word by removing punctuation
        let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
        let lowercaseWord = cleanWord.lowercased()
        
        // Check if word is in preserved list first
        if preservedWords.contains(lowercaseWord) {
            return word // Return original word unchanged
        }
        
        // Check if conversion exists
        guard let britishSpelling = conversions[lowercaseWord] else {
            return word // No conversion found, return original
        }
        
        // Apply case sensitivity matching
        let convertedWord = applyCaseMatching(original: cleanWord, converted: britishSpelling)
        
        // Replace the core word while preserving surrounding punctuation
        return word.replacingOccurrences(of: cleanWord, with: convertedWord)
    }
    
    private func applyCaseMatching(original: String, converted: String) -> String {
        // If original is all uppercase
        if original == original.uppercased() {
            return converted.uppercased()
        }
        
        // If original is capitalized (first letter uppercase, rest lowercase)
        if original.prefix(1) == original.prefix(1).uppercased() && 
           original.dropFirst() == original.dropFirst().lowercased() {
            return converted.capitalized
        }
        
        // Default: return lowercase conversion
        return converted.lowercased()
    }
}
