//
//  SpellingDictionary.swift
//  FloRight
//
//  Data model for British spelling dictionary JSON structure
//

import Foundation

struct SpellingDictionary: Codable {
    let metadata: Metadata
    let conversions: [String: String]
    let preservedWords: [String]
    let notes: [String: String]
    
    struct Metadata: Codable {
        let version: String
        let description: String
        let lastUpdated: String
        let totalConversions: Int
    }
}
