//
//  ToneTransformer.swift
//  FloRight
//
//  Transforms transcribed text based on selected tone preset
//

import Foundation

class ToneTransformer {
    
    func transform(text: String, tone: TonePreset) async throws -> String {
        // For local processing, we'll implement rule-based transformations
        // In a production version, you might want to use an LLM API
        
        switch tone {
        case .neutral:
            return applyNeutralTone(to: text)
        case .professional:
            return applyProfessionalTone(to: text)
        case .friendly:
            return applyFriendlyTone(to: text)
        case .concise:
            return applyConciseTone(to: text)
        case .empathetic:
            return applyEmpatheticTone(to: text)
        }
    }
    
    private func applyNeutralTone(to text: String) -> String {
        // Basic cleanup: fix capitalization, basic punctuation
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure first letter is capitalized
        if let first = result.first {
            result = String(first).uppercased() + result.dropFirst()
        }
        
        // Ensure ends with punctuation
        if !result.hasSuffix(".") && !result.hasSuffix("!") && !result.hasSuffix("?") {
            result += "."
        }
        
        // UK spelling if enabled - COMMENTED OUT FOR TESTING
        // if AppSettings.shared.useUKSpelling {
        //     result = applyUKSpelling(to: result)
        // }
        
        return result
    }
    
    private func applyProfessionalTone(to text: String) -> String {
        var result = applyNeutralTone(to: text)
        
        // Expand contractions
        let contractions = [
            "don't": "do not",
            "won't": "will not",
            "can't": "cannot",
            "I'm": "I am",
            "you're": "you are",
            "we're": "we are",
            "they're": "they are",
            "it's": "it is",
            "that's": "that is",
            "here's": "here is",
            "there's": "there is",
            "I've": "I have",
            "you've": "you have",
            "we've": "we have",
            "they've": "they have",
            "I'll": "I will",
            "you'll": "you will",
            "we'll": "we will",
            "they'll": "they will",
            "isn't": "is not",
            "aren't": "are not",
            "wasn't": "was not",
            "weren't": "were not",
            "hasn't": "has not",
            "haven't": "have not",
            "hadn't": "had not",
            "doesn't": "does not",
            "didn't": "did not"
        ]
        
        for (contraction, expanded) in contractions {
            result = result.replacingOccurrences(of: contraction, with: expanded, options: .caseInsensitive)
        }
        
        // Replace casual phrases
        let casualToProfessional = [
            "yeah": "yes",
            "nope": "no",
            "gonna": "going to",
            "wanna": "want to",
            "gotta": "have to",
            "kinda": "kind of",
            "sorta": "sort of",
            "thanks": "thank you",
            "ok": "acceptable",
            "okay": "acceptable"
        ]
        
        for (casual, professional) in casualToProfessional {
            result = result.replacingOccurrences(of: "\\b\(casual)\\b", with: professional, options: [.regularExpression, .caseInsensitive])
        }
        
        return result
    }
    
    private func applyFriendlyTone(to text: String) -> String {
        var result = applyNeutralTone(to: text)
        
        // Add friendly openings if starting with certain patterns
        if result.lowercased().starts(with: "i need") || result.lowercased().starts(with: "i want") {
            result = "Hey there! " + result
        }
        
        // Keep contractions (opposite of professional)
        // Already in neutral form
        
        return result
    }
    
    private func applyConciseTone(to text: String) -> String {
        var result = applyNeutralTone(to: text)
        
        // Remove filler words
        let fillerWords = [
            "basically", "actually", "really", "very", "quite",
            "just", "like", "you know", "I mean", "sort of",
            "kind of", "pretty much", "more or less"
        ]
        
        for filler in fillerWords {
            result = result.replacingOccurrences(of: "\\b\(filler)\\b", with: "", options: [.regularExpression, .caseInsensitive])
        }
        
        // Clean up extra spaces
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return result
    }
    
    private func applyEmpatheticTone(to text: String) -> String {
        var result = applyNeutralTone(to: text)
        
        // Add empathetic phrases based on content
        if result.lowercased().contains("problem") || result.lowercased().contains("issue") {
            result = "I understand this might be frustrating. " + result
        }
        
        if result.lowercased().contains("help") {
            result = result + " I'm here to support you with this."
        }
        
        return result
    }
    
    private func applyUKSpelling(to text: String) -> String {
        var result = text
        
        let usToUK = [
            "color": "colour",
            "favor": "favour",
            "honor": "honour",
            "labor": "labour",
            "neighbor": "neighbour",
            "center": "centre",
            "fiber": "fibre",
            "theater": "theatre",
            "organize": "organise",
            "recognize": "recognise",
            "analyze": "analyse",
            "apologize": "apologise",
            "maximize": "maximise",
            "minimize": "minimise"
        ]
        
        for (us, uk) in usToUK {
            result = result.replacingOccurrences(of: "\\b\(us)\\b", with: uk, options: [.regularExpression, .caseInsensitive])
        }
        
        return result
    }
}

// MARK: - LLM Integration Option
/*
 For more sophisticated tone transformations, you could integrate an LLM API:
 
 ```swift
 func transformWithLLM(text: String, tone: TonePreset) async throws -> String {
     let prompt = tone.systemPrompt + "\n\nText: " + text
     
     // Call your preferred LLM API (OpenAI, Anthropic, etc.)
     // Return transformed text
 }
 ```
 
 This would provide much more nuanced transformations but requires:
 1. API key management
 2. Network requests
 3. Error handling for API failures
 4. Potentially higher latency
 */
