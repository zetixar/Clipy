//
//  SearchService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Copilot on 2025/12/14.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import RealmSwift

final class SearchService {
    
    // MARK: - Properties
    private let realm = try! Realm()
    private let maxResults = 100
    
    // MARK: - Search Methods
    func search(query: String) -> [SearchResultItem] {
        var results: [SearchResultItem] = []
        
        if query.isEmpty {
            // Return all items when no search query
            results.append(contentsOf: getAllClips())
            results.append(contentsOf: getAllSnippets())
        } else {
            // Perform filtered search
            results.append(contentsOf: searchClips(query: query))
            results.append(contentsOf: searchSnippets(query: query))
        }
        
        // Sort by relevance score and limit results
        results.sort { $0.matchScore > $1.matchScore }
        return Array(results.prefix(maxResults))
    }
    
    // MARK: - Clip Search
    private func getAllClips() -> [SearchResultItem] {
        let clips = realm.objects(CPYClip.self)
            .sorted(byKeyPath: #keyPath(CPYClip.updateTime), ascending: false)
        
        return clips.map { SearchResultItem(clip: $0) }
    }
    
    private func searchClips(query: String) -> [SearchResultItem] {
        let clips = realm.objects(CPYClip.self)
            .sorted(byKeyPath: #keyPath(CPYClip.updateTime), ascending: false)
        
        var results: [SearchResultItem] = []
        
        for clip in clips {
            if let score = calculateMatchScore(query: query, title: clip.title, content: clip.title) {
                results.append(SearchResultItem(clip: clip, score: score))
            }
        }
        
        return results
    }
    
    // MARK: - Snippet Search
    private func getAllSnippets() -> [SearchResultItem] {
        let snippets = realm.objects(CPYSnippet.self)
            .filter("enable == true")
            .sorted(byKeyPath: #keyPath(CPYSnippet.index), ascending: true)
        
        return snippets.map { SearchResultItem(snippet: $0) }
    }
    
    private func searchSnippets(query: String) -> [SearchResultItem] {
        let snippets = realm.objects(CPYSnippet.self)
            .filter("enable == true")
            .sorted(byKeyPath: #keyPath(CPYSnippet.index), ascending: true)
        
        var results: [SearchResultItem] = []
        
        for snippet in snippets {
            if let score = calculateMatchScore(query: query, title: snippet.title, content: snippet.content) {
                results.append(SearchResultItem(snippet: snippet, score: score))
            }
        }
        
        return results
    }
    
    // MARK: - Scoring Algorithm
    private func calculateMatchScore(query: String, title: String, content: String) -> Float? {
        let lowercaseQuery = query.lowercased()
        let lowercaseTitle = title.lowercased()
        let lowercaseContent = content.lowercased()
        
        var score: Float = 0.0
        var hasMatch = false
        
        // Exact title match gets highest score
        if lowercaseTitle == lowercaseQuery {
            score += 100.0
            hasMatch = true
        }
        // Title starts with query gets high score
        else if lowercaseTitle.hasPrefix(lowercaseQuery) {
            score += 80.0
            hasMatch = true
        }
        // Title contains query gets medium-high score
        else if lowercaseTitle.contains(lowercaseQuery) {
            score += 60.0
            hasMatch = true
        }
        // Content starts with query gets medium score
        else if lowercaseContent.hasPrefix(lowercaseQuery) {
            score += 40.0
            hasMatch = true
        }
        // Content contains query gets lower score
        else if lowercaseContent.contains(lowercaseQuery) {
            score += 20.0
            hasMatch = true
        }
        
        // Fuzzy matching for partial matches
        if !hasMatch {
            let fuzzyScore = calculateFuzzyScore(query: lowercaseQuery, text: lowercaseTitle)
            if fuzzyScore > 0.5 {
                score += fuzzyScore * 30.0
                hasMatch = true
            } else {
                let contentFuzzyScore = calculateFuzzyScore(query: lowercaseQuery, text: lowercaseContent)
                if contentFuzzyScore > 0.5 {
                    score += contentFuzzyScore * 15.0
                    hasMatch = true
                }
            }
        }
        
        // Boost score for shorter strings (better matches)
        if hasMatch {
            let lengthFactor = Float(query.count) / Float(max(title.count, 1))
            score *= (1.0 + lengthFactor * 0.5)
        }
        
        return hasMatch ? score : nil
    }
    
    // Simple fuzzy matching algorithm
    private func calculateFuzzyScore(query: String, text: String) -> Float {
        guard !query.isEmpty && !text.isEmpty else { return 0.0 }
        
        let queryChars = Array(query)
        let textChars = Array(text)
        
        var matches = 0
        var textIndex = 0
        
        for queryChar in queryChars {
            // Find the character in the remaining text
            while textIndex < textChars.count && textChars[textIndex] != queryChar {
                textIndex += 1
            }
            
            if textIndex < textChars.count {
                matches += 1
                textIndex += 1
            }
        }
        
        return Float(matches) / Float(queryChars.count)
    }
    
    // MARK: - Search by Category
    func searchClipsOnly(query: String) -> [SearchResultItem] {
        if query.isEmpty {
            return getAllClips()
        } else {
            return searchClips(query: query)
        }
    }
    
    func searchSnippetsOnly(query: String) -> [SearchResultItem] {
        if query.isEmpty {
            return getAllSnippets()
        } else {
            return searchSnippets(query: query)
        }
    }
    
    // MARK: - Utility Methods
    func getRecentClips(limit: Int = 10) -> [SearchResultItem] {
        let clips = realm.objects(CPYClip.self)
            .sorted(byKeyPath: #keyPath(CPYClip.updateTime), ascending: false)
            .prefix(limit)
        
        return clips.map { SearchResultItem(clip: $0) }
    }
    
    func getFrequentlyUsedSnippets(limit: Int = 10) -> [SearchResultItem] {
        // For now, just return by index order
        // In the future, we could track usage frequency
        let snippets = realm.objects(CPYSnippet.self)
            .filter("enable == true")
            .sorted(byKeyPath: #keyPath(CPYSnippet.index), ascending: true)
            .prefix(limit)
        
        return snippets.map { SearchResultItem(snippet: $0) }
    }
}