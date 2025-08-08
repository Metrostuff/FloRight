//
//  TonePreset.swift
//  FloRight
//
//  Defines the five unique tone presets that transform dictated text
//

import Foundation

enum TonePreset: String, CaseIterable, Identifiable {
    case neutral = "Neutral"
    case professional = "Professional"
    case friendly = "Friendly"
    case concise = "Concise"
    case empathetic = "Empathetic"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .neutral:
            return "Direct transcription with basic cleanup"
        case .professional:
            return "Formal language, expanded contractions"
        case .friendly:
            return "Conversational, warm tone"
        case .concise:
            return "Removes filler, tightens prose"
        case .empathetic:
            return "Adds emotional intelligence"
        }
    }
    
    var systemPrompt: String {
        switch self {
        case .neutral:
            return "Clean up this transcribed text, fixing grammar and punctuation while maintaining the original voice and intent. Keep contractions as they are."
            
        case .professional:
            return "Transform this transcribed text into professional, formal language. Expand all contractions, use formal vocabulary, and ensure clear, business-appropriate communication."
            
        case .friendly:
            return "Rewrite this transcribed text in a warm, conversational tone. Keep it approachable and friendly while maintaining clarity. Use contractions naturally."
            
        case .concise:
            return "Make this transcribed text more concise. Remove filler words, redundancies, and unnecessary phrases. Keep only the essential information while maintaining clarity."
            
        case .empathetic:
            return "Rewrite this transcribed text with emotional intelligence and empathy. Add warmth and understanding while being considerate of the reader's perspective."
        }
    }
    
    // Keyboard shortcut for quick switching
    var keyboardShortcut: String {
        switch self {
        case .neutral: return "1"
        case .professional: return "2"
        case .friendly: return "3"
        case .concise: return "4"
        case .empathetic: return "5"
        }
    }
}
