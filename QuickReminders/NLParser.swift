import Foundation
import EventKit

class NLParser {
    private var timeKeywords: [String: Int] {
        var keywords = [
            "tomorrow": 1, "today": 0,
            "monday": 2, "tuesday": 3, "wednesday": 4, 
            "thursday": 5, "friday": 6, "saturday": 7, "sunday": 1
        ]
        
        if colorTheme?.shortcutsEnabled == true {
            keywords["tm"] = 1
            keywords["td"] = 0
            keywords["mon"] = 2
            keywords["tue"] = 3
            keywords["wed"] = 4
            keywords["thu"] = 5
            keywords["fri"] = 6
            keywords["sat"] = 7
            keywords["sun"] = 1
        }
        
        return keywords
    }
    
    private let timePatterns = [
        "at (\\d{1,2}):?(\\d{0,2})\\s*(am|pm)?",
        "at (\\d{1,2})\\s*(am|pm)?",
        "(\\d{1,2}):(\\d{2})\\s*(am|pm)?",
        "(\\d{1,2})\\s*(am|pm)",
        "(\\d{1,2})(?!:)(?![a-z])",
        "\\b(\\d{1,2})\\b(?!:)"
    ]
    
    private let datePatterns = [
        "(\\d{1,2})[./](\\d{1,2})[./](\\d{4})\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm)?",
        "(\\d{1,2})[./](\\d{1,2})[./](\\d{4})\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm)?",
        "(\\d{1,2})[./](\\d{1,2})[./](\\d{4})",
        "(\\d{1,2})[./](\\d{1,2})\\.?\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm)?",
        "(\\d{1,2})[./](\\d{1,2})\\.?\\s+(\\d{1,2})\\s*(am|pm)",
        "(\\d{1,2})[./](\\d{1,2})\\.?\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm)?",
        "(\\d{1,2})[./](\\d{1,2})\\.?\\s+at\\s+(\\d{1,2})\\s*(am|pm)",
        "on\\s+(\\d{1,2})[./](\\d{1,2})\\.?\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm)?",
        "on\\s+(\\d{1,2})[./](\\d{1,2})\\.?\\s+(\\d{1,2})\\s*(am|pm)",
        "(\\d{1,2}):(\\d{2})\\s*(am|pm)?\\s+(\\d{1,2})[./](\\d{1,2})\\.?",
        "(\\d{1,2})\\s*(am|pm)\\s+(\\d{1,2})[./](\\d{1,2})\\.?",
        "at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm)?\\s+(\\d{1,2})[./](\\d{1,2})\\.?",
        "at\\s+(\\d{1,2})\\s*(am|pm)\\s+(\\d{1,2})[./](\\d{1,2})\\.?",
        "(\\d{1,2})[./](\\d{1,2})\\.?"
    ]
    
    private let relativeDatePatterns = [
        "\\bin\\s+(\\d+)\\s+(day|days|week|weeks|month|months)\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "\\bin\\s+(\\d+)\\s+(day|days|week|weeks|month|months)\\s+(?:at\\s+)?(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "\\bin\\s+(\\d+)\\s+(day|days|week|weeks|month|months)\\s+(?:at\\s+)?(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        
        "in\\s+(\\d+)\\s+(day|days|week|weeks|month|months)\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "in\\s+(\\d+)\\s+(day|days|week|weeks|month|months)\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "in\\s+(\\d+)\\s+(day|days|week|weeks|month|months)\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "in\\s+(\\d+)\\s+(day|days|week|weeks|month|months)\\s+(\\d{1,2})\\s*(am|pm|AM|PM)",
        "in\\s+(\\d+)\\s+(day|days)",
        
        // SPECIFIC: "in X weeks/months weekday" patterns (MUST come before general patterns)
        "in\\s+(\\d+)\\s+(weeks?|months?)\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "in\\s+(\\d+)\\s+(weeks?|months?)\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "in\\s+(\\d+)\\s+(weeks?|months?)\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "in\\s+(\\d+)\\s+(weeks?|months?)\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "in\\s+(\\d+)\\s+(weeks?|months?)\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        
        "in\\s+(\\d+)\\s+(weeks?|months?)\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "in\\s+(\\d+)\\s+(weeks?|months?)\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "in\\s+(\\d+)\\s+(weeks?|months?)\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "in\\s+(\\d+)\\s+(weeks?|months?)\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "in\\s+(\\d+)\\s+(weeks?|months?)\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)",

        "\\b(tomorrow|tm|today|td)\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "\\b(tomorrow|tm|today|td)\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "\\b(tomorrow|tm|today|td)\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "\\b(tomorrow|tm|today|td)\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "\\b(tomorrow|tm|today|td)\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",

        "(?:on\\s+)?\\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\b\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(?:on\\s+)?\\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\b\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(?:on\\s+)?\\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\b\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(?:on\\s+)?\\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\b\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(?:on\\s+)?\\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\b\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",

        "(\\d{1,2})[./](\\d{1,2})[./](\\d{4})\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(\\d{1,2})[./](\\d{1,2})[./](\\d{4})\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(\\d{1,2})[./](\\d{1,2})[./](\\d{4})\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(\\d{1,2})[./](\\d{1,2})\\.?\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(\\d{1,2})[./](\\d{1,2})\\.?\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(\\d{1,2})[./](\\d{1,2})\\.?\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(\\d{1,2})[./](\\d{1,2})\\.?\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(\\d{1,2})[./](\\d{1,2})\\.?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",

        "every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)\\s+(?:at\\s+)?(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)\\s+(?:at\\s+)?(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        
        // Week+weekday patterns with recurring
        "next\\s+week\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "next\\s+week\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "next\\s+week\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "next\\s+week\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "next\\s+week\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        
        "in\\s+(\\d+)\\s+weeks?\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "in\\s+(\\d+)\\s+weeks?\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "in\\s+(\\d+)\\s+weeks?\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "in\\s+(\\d+)\\s+weeks?\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "in\\s+(\\d+)\\s+weeks?\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        
        // Reverse order patterns: weekday + week specifier
        "(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+next\\s+week\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+next\\s+week\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+next\\s+week\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+next\\s+week\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+next\\s+week\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        
        "(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+weeks?\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+weeks?\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+weeks?\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+weeks?\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+weeks?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        
        // Week+weekday patterns without recurring  
        "next\\s+week\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "next\\s+week\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "next\\s+week\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "next\\s+week\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "next\\s+week\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)",
        
        "in\\s+(\\d+)\\s+weeks?\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "in\\s+(\\d+)\\s+weeks?\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "in\\s+(\\d+)\\s+weeks?\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "in\\s+(\\d+)\\s+weeks?\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "in\\s+(\\d+)\\s+weeks?\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)",
        
        // Reverse order patterns without recurring
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+next\\s+week\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+next\\s+week\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+next\\s+week\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+next\\s+week\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+next\\s+week",
        
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+weeks?\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+weeks?\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+weeks?\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+weeks?\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+weeks?",
        
        // Simple time patterns for week+weekday
        "next\\s+week\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "next\\s+week\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "next\\s+week\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "next\\s+week\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "next\\s+week\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        
        "next\\s+week\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "next\\s+week\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "next\\s+week\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "next\\s+week\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "next\\s+week",
        
        "(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\\s+(morning|noon|afternoon|evening|night)",
        "(mon|tue|wed|thu|fri|sat|sun)\\s+(morning|noon|afternoon|evening|night)",
        
        // Reverse order: "weekday in X weeks/months" patterns (WITHOUT recurring)
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+(weeks?|months?)\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+(weeks?|months?)\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+(weeks?|months?)\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+(weeks?|months?)\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+(weeks?|months?)",
        
        // Reverse order: "weekday in X weeks/months" patterns (WITH recurring)
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+(weeks?|months?)\\s+at\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+(weeks?|months?)\\s+at\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+(weeks?|months?)\\s+(\\d{1,2}):(\\d{2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+(weeks?|months?)\\s+(\\d{1,2})\\s*(am|pm|AM|PM)?\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)",
        "(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+(\\d+)\\s+(weeks?|months?)\\s+every\\s+(\\d+)\\s+(day|days|week|weeks|month|months)"
    ]

    weak var colorTheme: ColorThemeManager?
    
    func parseReminderText(_ text: String) -> ParsedReminder {
        // Validate input
        let validationResult = validateInput(text)
        if !validationResult.isValid {
            return ParsedReminder(
                title: extractTitle(from: text),
                dueDate: nil,
                isRecurring: false,
                recurrenceInterval: nil,
                recurrenceFrequency: nil,
                recurrenceEndDate: nil,
                isValid: false,
                errorMessage: validationResult.errorMessage
            )
        }
        
        let lowercaseText = text.lowercased()
        let title = extractTitle(from: text)
        let (dueDate, isRecurring, interval, frequency, endDate) = extractDueDateWithRecurrence(from: lowercaseText)
        
        // Validate parsed result
        let parsedValidation = validateParsedResult(title: title, dueDate: dueDate, isRecurring: isRecurring, interval: interval, frequency: frequency)
        
        return ParsedReminder(
            title: title,
            dueDate: dueDate,
            isRecurring: isRecurring,
            recurrenceInterval: interval,
            recurrenceFrequency: frequency,
            recurrenceEndDate: endDate,
            isValid: parsedValidation.isValid,
            errorMessage: parsedValidation.errorMessage
        )
    }
    
    private func validateInput(_ text: String) -> (isValid: Bool, errorMessage: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for empty input
        if trimmed.isEmpty {
            return (false, "Please enter a reminder")
        }
        
        // Check for minimum length
        if trimmed.count < 3 {
            return (false, "Reminder is too short")
        }
        
        // Check for maximum length
        if trimmed.count > 200 {
            return (false, "Reminder is too long (max 200 characters)")
        }
        
        // Check for invalid time formats like "34" hour
        if let invalidTimeError = validateTimeFormats(trimmed) {
            return (false, invalidTimeError)
        }
        
        // Check for malformed patterns
        if let malformedError = validatePatternFormats(trimmed) {
            return (false, malformedError)
        }
        
        return (true, nil)
    }
    
    private func validateTimeFormats(_ text: String) -> String? {
        let lowercaseText = text.lowercased()
        
        // Note: Removed overly broad invalid hour pattern that was incorrectly flagging valid dates like "10/26"
        // The more specific patterns below handle invalid hours in proper context
        
        // Check for invalid minutes (60-99)
        let invalidMinutePattern = "\\b\\d{1,2}:([6-9]\\d)\\b"
        if let regex = try? NSRegularExpression(pattern: invalidMinutePattern),
           regex.firstMatch(in: lowercaseText, range: NSRange(location: 0, length: lowercaseText.count)) != nil {
            return "Invalid minute format (minutes must be 00-59)"
        }
        
        // Check for standalone invalid numbers after time keywords
        let timeKeywordPattern = "\\b(at|on)\\s+(2[5-9]|[3-9]\\d)\\b"
        if let regex = try? NSRegularExpression(pattern: timeKeywordPattern),
           regex.firstMatch(in: lowercaseText, range: NSRange(location: 0, length: lowercaseText.count)) != nil {
            return "Invalid time format - use valid hours (1-24) with AM/PM or 24-hour format"
        }
        
        // Check for standalone invalid numbers after weekdays/time words
        let weekdayNumberPattern = "\\b(tomorrow|tm|today|td|monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)\\s+(2[5-9]|[3-9]\\d)\\b"
        if let regex = try? NSRegularExpression(pattern: weekdayNumberPattern),
           regex.firstMatch(in: lowercaseText, range: NSRange(location: 0, length: lowercaseText.count)) != nil {
            return "Invalid time format - use valid hours (1-24) with AM/PM or 24-hour format"
        }
        
        return nil
    }
    
    private func validatePatternFormats(_ text: String) -> String? {
        let lowercaseText = text.lowercased()
        
        // Check for incomplete "every" patterns
        if lowercaseText.contains("every") {
            let everyPattern = "\\bevery\\s+(?!\\d+\\s+(day|days|week|weeks|month|months)\\b|\\b(day|days|week|weeks|month|months)\\b)\\w+"
            if let regex = try? NSRegularExpression(pattern: everyPattern),
               regex.firstMatch(in: lowercaseText, range: NSRange(location: 0, length: lowercaseText.count)) != nil {
                return "Invalid recurring format - use 'every X days/weeks/months'"
            }
        }
        
        // Check for incomplete "in" patterns  
        if lowercaseText.contains(" in ") {
            let inPattern = "\\bin\\s+(?!\\d+\\s+(day|days|week|weeks|month|months)\\b)\\w+"
            if let regex = try? NSRegularExpression(pattern: inPattern),
               regex.firstMatch(in: lowercaseText, range: NSRange(location: 0, length: lowercaseText.count)) != nil {
                return "Invalid relative date format - use 'in X days/weeks/months'"
            }
        }
        
        // Check for nonsensical "in X days weekday" patterns
        if lowercaseText.contains(" in ") {
            let invalidDaysWeekdayPattern = "\\bin\\s+\\d+\\s+days?\\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\b"
            if let regex = try? NSRegularExpression(pattern: invalidDaysWeekdayPattern, options: .caseInsensitive),
               regex.firstMatch(in: lowercaseText, range: NSRange(location: 0, length: lowercaseText.count)) != nil {
                return "Invalid format - cannot use 'in X days' with weekdays. Use 'in X weeks/months weekday' or 'weekday in X weeks/months' instead."
            }
        }
        
        // Check for reverse nonsensical "weekday in X days" patterns  
        let invalidWeekdayDaysPattern = "\\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+in\\s+\\d+\\s+days?\\b"
        if let regex = try? NSRegularExpression(pattern: invalidWeekdayDaysPattern, options: .caseInsensitive),
           regex.firstMatch(in: lowercaseText, range: NSRange(location: 0, length: lowercaseText.count)) != nil {
            return "Invalid format - cannot use 'weekday in X days'. Use 'in X weeks/months weekday' or 'weekday in X weeks/months' instead."
        }
        
        // Check for invalid "in X weeks/months" + temporal words patterns
        if lowercaseText.contains(" in ") {
            let invalidWeeksTemporalPattern = "\\bin\\s+\\d+\\s+(weeks?|months?)\\s+(today|tomorrow|tm|td)\\b"
            if let regex = try? NSRegularExpression(pattern: invalidWeeksTemporalPattern, options: .caseInsensitive),
               regex.firstMatch(in: lowercaseText, range: NSRange(location: 0, length: lowercaseText.count)) != nil {
                return "Invalid format - cannot use 'in X weeks/months' with 'today/tomorrow'. Use just 'today/tomorrow' or 'in X weeks/months' alone."
            }
        }
        
        // Check for invalid "in X weeks/months" + date patterns  
        if lowercaseText.contains(" in ") {
            let invalidWeeksDatePattern = "\\bin\\s+\\d+\\s+(weeks?|months?)\\s+\\d{1,2}[./]\\d{1,2}\\b"
            if let regex = try? NSRegularExpression(pattern: invalidWeeksDatePattern, options: .caseInsensitive),
               regex.firstMatch(in: lowercaseText, range: NSRange(location: 0, length: lowercaseText.count)) != nil {
                return "Invalid format - cannot use 'in X weeks/months' with specific dates like '10.10'. Use just 'in X weeks/months' or the specific date alone."
            }
        }
        
        // Check for invalid date formats based on user's preference
        if let dateFormatError = validateDateFormats(lowercaseText) {
            return dateFormatError
        }
        
        return nil
    }
    
    private func validateDateFormats(_ text: String) -> String? {
        // Get the user's date format preference
        let dateFormat = colorTheme?.dateFormat ?? .mmdd
        
        // Find all date-like patterns in the text
        let datePattern = "\\b(\\d{1,2})[./](\\d{1,2})\\b"
        guard let regex = try? NSRegularExpression(pattern: datePattern, options: .caseInsensitive) else {
            return nil
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        
        for match in matches {
            guard let firstRange = Range(match.range(at: 1), in: text),
                  let secondRange = Range(match.range(at: 2), in: text),
                  let firstValue = Int(text[firstRange]),
                  let secondValue = Int(text[secondRange]) else {
                continue
            }
            
            // Check if this date combination is valid for the user's format preference
            let (month, day): (Int, Int)
            
            switch dateFormat {
            case .mmdd:
                month = firstValue
                day = secondValue
            case .ddmm:
                month = secondValue
                day = firstValue
            }
            
            // If month or day is invalid, reject this pattern
            if month < 1 || month > 12 || day < 1 || day > 31 {
                let formatName = dateFormat == .mmdd ? "MM/DD" : "DD/MM"
                return "Invalid date format: '\(firstValue)/\(secondValue)' doesn't work with \(formatName) format. Check your Date Format setting in preferences."
            }
            
            // Additional validation: check if day is valid for the specific month
            let calendar = Calendar.current
            var dateComponents = DateComponents()
            dateComponents.month = month
            dateComponents.day = day
            dateComponents.year = calendar.component(.year, from: Date())
            
            if calendar.date(from: dateComponents) == nil {
                let formatName = dateFormat == .mmdd ? "MM/DD" : "DD/MM"
                return "Invalid date: '\(firstValue)/\(secondValue)' with \(formatName) format results in an impossible date (e.g., February 30th)."
            }
        }
        
        return nil
    }
    
    private func validateParsedResult(title: String, dueDate: Date?, isRecurring: Bool, interval: Int?, frequency: EKRecurrenceFrequency?) -> (isValid: Bool, errorMessage: String?) {
        // Check for meaningful title
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (false, "No reminder content found")
        }
        
        // For recurring reminders, validate recurrence parameters
        if isRecurring {
            guard let interval = interval, interval > 0 else {
                return (false, "Invalid recurring interval")
            }
            
            guard frequency != nil else {
                return (false, "Invalid recurring frequency")
            }
            
            if interval > 365 && frequency == .daily {
                return (false, "Daily recurring interval too large (max 365 days)")
            }
            
            if interval > 52 && frequency == .weekly {
                return (false, "Weekly recurring interval too large (max 52 weeks)")
            }
            
            if interval > 24 && frequency == .monthly {
                return (false, "Monthly recurring interval too large (max 24 months)")
            }
        }
        
        return (true, nil)
    }
    
    private func extractTitle(from text: String) -> String {
        var cleanedText = text
        
        let timeRegex = try! NSRegularExpression(pattern: "\\s+(at|on|by)\\s+.*", options: .caseInsensitive)
        cleanedText = timeRegex.stringByReplacingMatches(in: cleanedText, options: [], range: NSRange(location: 0, length: cleanedText.count), withTemplate: "")
        
        let dayRegex = try! NSRegularExpression(pattern: "\\s+(tomorrow|tm|today|td|monday|mon|tuesday|tue|wednesday|wed|thursday|thu|friday|fri|saturday|sat|sunday|sun)\\b.*", options: .caseInsensitive)
        cleanedText = dayRegex.stringByReplacingMatches(in: cleanedText, options: [], range: NSRange(location: 0, length: cleanedText.count), withTemplate: "")
        
        let dateRegex = try! NSRegularExpression(pattern: "\\s+(on\\s+)?\\d{1,2}[./]\\d{1,2}([./]\\d{4})?\\.?.*", options: .caseInsensitive)
        cleanedText = dateRegex.stringByReplacingMatches(in: cleanedText, options: [], range: NSRange(location: 0, length: cleanedText.count), withTemplate: "")
        
        let relativeDateRegex = try! NSRegularExpression(pattern: "\\s+(in\\s+\\d+\\s+(day|days|week|weeks|month|months)).*", options: .caseInsensitive)
        cleanedText = relativeDateRegex.stringByReplacingMatches(in: cleanedText, options: [], range: NSRange(location: 0, length: cleanedText.count), withTemplate: "")
        
        let everyRegex = try! NSRegularExpression(pattern: "\\s+(every\\s+\\d+\\s+(day|days|week|weeks|month|months)).*", options: .caseInsensitive)
        cleanedText = everyRegex.stringByReplacingMatches(in: cleanedText, options: [], range: NSRange(location: 0, length: cleanedText.count), withTemplate: "")
        
        // Remove week+weekday patterns
        let nextWeekRegex = try! NSRegularExpression(pattern: "\\s+(next\\s+week).*", options: .caseInsensitive)
        cleanedText = nextWeekRegex.stringByReplacingMatches(in: cleanedText, options: [], range: NSRange(location: 0, length: cleanedText.count), withTemplate: "")
        
        let inWeeksRegex = try! NSRegularExpression(pattern: "\\s+(in\\s+\\d+\\s+weeks?).*", options: .caseInsensitive)
        cleanedText = inWeeksRegex.stringByReplacingMatches(in: cleanedText, options: [], range: NSRange(location: 0, length: cleanedText.count), withTemplate: "")
        
        let dayTimeRegex = try! NSRegularExpression(pattern: "\\s+((monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\\s+(morning|noon|afternoon|evening|night)).*", options: .caseInsensitive)
        cleanedText = dayTimeRegex.stringByReplacingMatches(in: cleanedText, options: [], range: NSRange(location: 0, length: cleanedText.count), withTemplate: "")
        
        let untilRegex = try! NSRegularExpression(pattern: "\\s+until\\s+\\d{1,2}[./]\\d{1,2}[./]\\d{4}.*", options: .caseInsensitive)
        cleanedText = untilRegex.stringByReplacingMatches(in: cleanedText, options: [], range: NSRange(location: 0, length: cleanedText.count), withTemplate: "")
        
        return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractDueDateWithRecurrence(from text: String) -> (Date?, Bool, Int?, EKRecurrenceFrequency?, Date?) {
        let processedText = text
            .replacingOccurrences(of: " every day", with: " every 1 day")
            .replacingOccurrences(of: " every week", with: " every 1 week")
            .replacingOccurrences(of: " every month", with: " every 1 month")

        let calendar = Calendar.current
        let now = Date()
        
        for (index, pattern) in relativeDatePatterns.enumerated() {
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(location: 0, length: processedText.count)
            
            if let match = regex.firstMatch(in: processedText, options: [], range: range) {

                if index >= 0 && index <= 2 {
                    guard let initialInterval = Int(String(processedText[Range(match.range(at: 1), in: processedText)!])) else { continue }
                    let initialUnit = String(processedText[Range(match.range(at: 2), in: processedText)!])
                    var hour = 9, minute = 0
                    let recurrenceGroups: (interval: Int, unit: Int)
                    
                    if index == 0 {
                        recurrenceGroups = (3, 4)
                    } else if index == 1 {
                        let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: 4, ampmGroup: 5)
                        hour = time.hour; minute = time.minute
                        recurrenceGroups = (6, 7)
                    } else {
                        let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: nil, ampmGroup: 4)
                        hour = time.hour; minute = time.minute
                        recurrenceGroups = (5, 6)
                    }

                    guard let recurringInterval = Int(String(processedText[Range(match.range(at: recurrenceGroups.interval), in: processedText)!])) else { continue }
                    let recurringUnit = String(processedText[Range(match.range(at: recurrenceGroups.unit), in: processedText)!])
                    
                    var dateComponent: Calendar.Component = .day
                    if initialUnit.contains("week") { dateComponent = .weekOfYear }
                    if initialUnit.contains("month") { dateComponent = .month }
                    
                    let startDate = calendar.date(byAdding: dateComponent, value: initialInterval, to: now) ?? now
                    var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                    startComponents.hour = hour
                    startComponents.minute = minute
                    
                    return (calendar.date(from: startComponents), true, recurringInterval, getFrequency(from: recurringUnit), nil)
                }
                // NEW: "in X weeks/months weekday" patterns (indices 8-17)
                else if index >= 8 && index <= 17 {
                    if index >= 8 && index <= 12 {
                        // "in X weeks/months weekday" patterns WITH recurring
                        guard let weeksOrMonths = Int(String(processedText[Range(match.range(at: 1), in: processedText)!])) else { continue }
                        let unit = String(processedText[Range(match.range(at: 2), in: processedText)!])
                        let weekdayString = String(processedText[Range(match.range(at: 3), in: processedText)!])
                        var hour = 9, minute = 0
                        let recurrenceGroups: (interval: Int, unit: Int)
                        
                        if index == 8 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: 5, ampmGroup: 6)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (7, 8)
                        } else if index == 9 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: nil, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (6, 7)
                        } else if index == 10 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: 5, ampmGroup: 6)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (7, 8)
                        } else if index == 11 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: nil, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (6, 7)
                        } else {
                            recurrenceGroups = (4, 5)
                        }
                        
                        guard let recurringInterval = Int(String(processedText[Range(match.range(at: recurrenceGroups.interval), in: processedText)!])) else { continue }
                        let recurringUnit = String(processedText[Range(match.range(at: recurrenceGroups.unit), in: processedText)!])
                        
                        if let targetWeekday = timeKeywords[weekdayString] {
                            let dateComponent: Calendar.Component = unit.contains("week") ? .weekOfYear : .month
                            let targetDate = calendar.date(byAdding: dateComponent, value: weeksOrMonths, to: now) ?? now
                            let daysToAdd = (targetWeekday - calendar.component(.weekday, from: targetDate) + 7) % 7
                            let startDate = calendar.date(byAdding: .day, value: daysToAdd, to: targetDate) ?? targetDate
                            var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                            startComponents.hour = hour
                            startComponents.minute = minute
                            
                            return (calendar.date(from: startComponents), true, recurringInterval, getFrequency(from: recurringUnit), nil)
                        }
                    } else if index >= 13 && index <= 17 {
                        // "in X weeks/months weekday" patterns WITHOUT recurring
                        guard let weeksOrMonths = Int(String(processedText[Range(match.range(at: 1), in: processedText)!])) else { continue }
                        let unit = String(processedText[Range(match.range(at: 2), in: processedText)!])
                        let weekdayString = String(processedText[Range(match.range(at: 3), in: processedText)!])
                        var hour = 9, minute = 0
                        
                        if index == 13 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: 5, ampmGroup: 6)
                            hour = time.hour; minute = time.minute
                        } else if index == 14 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: nil, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                        } else if index == 15 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: 5, ampmGroup: 6)
                            hour = time.hour; minute = time.minute
                        } else if index == 16 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: nil, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                        }
                        
                        if let targetWeekday = timeKeywords[weekdayString] {
                            let dateComponent: Calendar.Component = unit.contains("week") ? .weekOfYear : .month
                            let targetDate = calendar.date(byAdding: dateComponent, value: weeksOrMonths, to: now) ?? now
                            let daysToAdd = (targetWeekday - calendar.component(.weekday, from: targetDate) + 7) % 7
                            let startDate = calendar.date(byAdding: .day, value: daysToAdd, to: targetDate) ?? targetDate
                            var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                            startComponents.hour = hour
                            startComponents.minute = minute
                            
                            return (calendar.date(from: startComponents), false, nil, nil, nil)
                        }
                    }
                }
                else if index >= 18 && index <= 22 {
                    let keyword = String(processedText[Range(match.range(at: 1), in: processedText)!])
                    var hour = 9, minute = 0
                    let recurrenceGroups: (interval: Int, unit: Int)

                    if index == 18 {
                        let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: 3, ampmGroup: 4)
                        hour = time.hour; minute = time.minute
                        recurrenceGroups = (5, 6)
                    } else if index == 19 {
                        let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: nil, ampmGroup: 3)
                        hour = time.hour; minute = time.minute
                        recurrenceGroups = (4, 5)
                    } else if index == 20 {
                        let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: 3, ampmGroup: 4)
                        hour = time.hour; minute = time.minute
                        recurrenceGroups = (5, 6)
                    } else if index == 21 {
                        let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: nil, ampmGroup: 3)
                        hour = time.hour; minute = time.minute
                        recurrenceGroups = (4, 5)
                    } else {
                        recurrenceGroups = (2, 3)
                    }
                    
                    guard let recurringInterval = Int(String(processedText[Range(match.range(at: recurrenceGroups.interval), in: processedText)!])) else { continue }
                    let recurringUnit = String(processedText[Range(match.range(at: recurrenceGroups.unit), in: processedText)!])
                    let daysToAdd = (keyword == "tomorrow" || keyword == "tm") ? 1 : 0
                    let startDate = calendar.date(byAdding: .day, value: daysToAdd, to: now) ?? now
                    
                    var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                    startComponents.hour = hour
                    startComponents.minute = minute
                    
                    return (calendar.date(from: startComponents), true, recurringInterval, getFrequency(from: recurringUnit), nil)
                }
                else if index >= 23 && index <= 27 {
                    let weekdayString = String(processedText[Range(match.range(at: 1), in: processedText)!])
                    var hour = 9, minute = 0
                    let recurrenceGroups: (interval: Int, unit: Int)

                    if index == 23 {
                        let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: 3, ampmGroup: 4)
                        hour = time.hour; minute = time.minute
                        recurrenceGroups = (5, 6)
                    } else if index == 24 {
                        let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: nil, ampmGroup: 3)
                        hour = time.hour; minute = time.minute
                        recurrenceGroups = (4, 5)
                    } else if index == 25 {
                        let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: 3, ampmGroup: 4)
                        hour = time.hour; minute = time.minute
                        recurrenceGroups = (5, 6)
                    } else if index == 26 {
                        let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: nil, ampmGroup: 3)
                        hour = time.hour; minute = time.minute
                        recurrenceGroups = (4, 5)
                    } else {
                        recurrenceGroups = (2, 3)
                    }
                    
                    guard let recurringInterval = Int(String(processedText[Range(match.range(at: recurrenceGroups.interval), in: processedText)!])) else { continue }
                    let recurringUnit = String(processedText[Range(match.range(at: recurrenceGroups.unit), in: processedText)!])
                    
                    if let targetWeekday = timeKeywords[weekdayString] {
                        var daysUntilTarget = targetWeekday - calendar.component(.weekday, from: now)
                        if daysUntilTarget <= 0 { daysUntilTarget += 7 }
                        
                        let startDate = calendar.date(byAdding: .day, value: daysUntilTarget, to: now) ?? now
                        var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                        startComponents.hour = hour
                        startComponents.minute = minute
                        
                        return (calendar.date(from: startComponents), true, recurringInterval, getFrequency(from: recurringUnit), nil)
                    }
                }
                else if index >= 28 && index <= 35 {
                    if index >= 28 && index <= 30 {
                        guard let firstValue = Int(String(processedText[Range(match.range(at: 1), in: processedText)!])),
                              let secondValue = Int(String(processedText[Range(match.range(at: 2), in: processedText)!])),
                              let year = Int(String(processedText[Range(match.range(at: 3), in: processedText)!])) else { continue }
                        
                        guard let dateComponents = parseDateComponents(firstValue: firstValue, secondValue: secondValue) else { continue }
                        let month = dateComponents.month
                        let day = dateComponents.day
                        
                        var hour = 9, minute = 0
                        let recurrenceGroups: (interval: Int, unit: Int)
                        
                        if index == 28 {
                            recurrenceGroups = (4, 5)
                        } else if index == 29 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: 5, ampmGroup: 6)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (7, 8)
                        } else {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: 5, ampmGroup: 6)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (7, 8)
                        }
                        
                        guard let recurringInterval = Int(String(processedText[Range(match.range(at: recurrenceGroups.interval), in: processedText)!])) else { continue }
                        let recurringUnit = String(processedText[Range(match.range(at: recurrenceGroups.unit), in: processedText)!])
                        
                        let targetComponents = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
                        
                        return (calendar.date(from: targetComponents), true, recurringInterval, getFrequency(from: recurringUnit), nil)
                    } else {
                        if let firstValue = Int(String(processedText[Range(match.range(at: 1), in: processedText)!])),
                           let secondValue = Int(String(processedText[Range(match.range(at: 2), in: processedText)!])),
                           let dateComponents = parseDateComponents(firstValue: firstValue, secondValue: secondValue) {
                            
                            let month = dateComponents.month
                            let day = dateComponents.day
                            var hour = 9, minute = 0
                            let recurrenceGroups: (interval: Int, unit: Int)
                            
                            if index == 31 {
                                let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: 4, ampmGroup: 5)
                                hour = time.hour; minute = time.minute
                                recurrenceGroups = (6, 7)
                            } else if index == 32 {
                                let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: nil, ampmGroup: 4)
                                hour = time.hour; minute = time.minute
                                recurrenceGroups = (5, 6)
                            } else if index == 33 {
                                let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: 4, ampmGroup: 5)
                                hour = time.hour; minute = time.minute
                                recurrenceGroups = (6, 7)
                            } else if index == 34 {
                                let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: nil, ampmGroup: 4)
                                hour = time.hour; minute = time.minute
                                recurrenceGroups = (5, 6)
                            } else {
                                recurrenceGroups = (3, 4)
                            }
                            
                            guard let recurringInterval = Int(String(processedText[Range(match.range(at: recurrenceGroups.interval), in: processedText)!])) else { continue }
                            let recurringUnit = String(processedText[Range(match.range(at: recurrenceGroups.unit), in: processedText)!])
                            
                            var targetComponents = DateComponents(month: month, day: day, hour: hour, minute: minute)
                            targetComponents.year = calendar.component(.year, from: now)
                            if let targetDate = calendar.date(from: targetComponents), targetDate < now {
                                targetComponents.year! += 1
                            }
                            
                            return (calendar.date(from: targetComponents), true, recurringInterval, getFrequency(from: recurringUnit), nil)
                        }
                    }
                }
                // Week+weekday patterns with recurring (indices 26-29, 31-35)
                else if index >= 39 && index <= 48 {
                    if index >= 39 && index <= 42 {
                        // next week + weekday patterns
                        let weekdayString = String(processedText[Range(match.range(at: 1), in: processedText)!])
                        var hour = 9, minute = 0
                        let recurrenceGroups: (interval: Int, unit: Int)
                        
                        if index == 39 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: 3, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (5, 6)
                        } else if index == 40 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: nil, ampmGroup: 3)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (4, 5)
                        } else if index == 41 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: 3, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (5, 6)
                        } else if index == 42 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: nil, ampmGroup: 3)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (4, 5)
                        } else {
                            recurrenceGroups = (2, 3)
                        }
                        
                        guard let recurringInterval = Int(String(processedText[Range(match.range(at: recurrenceGroups.interval), in: processedText)!])) else { continue }
                        let recurringUnit = String(processedText[Range(match.range(at: recurrenceGroups.unit), in: processedText)!])
                        
                        if let targetWeekday = timeKeywords[weekdayString] {
                            let daysToAdd = 7 + (targetWeekday - calendar.component(.weekday, from: now))
                            let startDate = calendar.date(byAdding: .day, value: daysToAdd > 7 ? daysToAdd - 7 : daysToAdd, to: now) ?? now
                            var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                            startComponents.hour = hour
                            startComponents.minute = minute
                            
                            return (calendar.date(from: startComponents), true, recurringInterval, getFrequency(from: recurringUnit), nil)
                        }
                    } else if index >= 44 && index <= 48 {
                        // in X weeks + weekday patterns
                        guard let weeksAhead = Int(String(processedText[Range(match.range(at: 1), in: processedText)!])) else { continue }
                        let weekdayString = String(processedText[Range(match.range(at: 2), in: processedText)!])
                        var hour = 9, minute = 0
                        let recurrenceGroups: (interval: Int, unit: Int)
                        
                        if index == 44 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: 4, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (6, 7)
                        } else if index == 45 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: nil, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (5, 6)
                        } else if index == 46 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: 4, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (6, 7)
                        } else if index == 47 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: nil, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (5, 6)
                        } else {
                            recurrenceGroups = (3, 4)
                        }
                        
                        guard let recurringInterval = Int(String(processedText[Range(match.range(at: recurrenceGroups.interval), in: processedText)!])) else { continue }
                        let recurringUnit = String(processedText[Range(match.range(at: recurrenceGroups.unit), in: processedText)!])
                        
                        if let targetWeekday = timeKeywords[weekdayString] {
                            // Calculate X weeks from now, then find the target weekday
                            let targetWeekDate = calendar.date(byAdding: .weekOfYear, value: weeksAhead, to: now) ?? now
                            let daysToAdd = (targetWeekday - calendar.component(.weekday, from: targetWeekDate) + 7) % 7
                            let startDate = calendar.date(byAdding: .day, value: daysToAdd, to: targetWeekDate) ?? targetWeekDate
                            var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                            startComponents.hour = hour
                            startComponents.minute = minute
                            
                            return (calendar.date(from: startComponents), true, recurringInterval, getFrequency(from: recurringUnit), nil)
                        }
                    }
                }
                // Reverse order patterns: weekday + week specifier with recurring (indices 36-45)
                else if index >= 49 && index <= 58 {
                    if index >= 49 && index <= 53 {
                        // weekday + next week patterns
                        let weekdayString = String(processedText[Range(match.range(at: 1), in: processedText)!])
                        var hour = 9, minute = 0
                        let recurrenceGroups: (interval: Int, unit: Int)
                        
                        if index == 49 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: 3, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (5, 6)
                        } else if index == 50 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: nil, ampmGroup: 3)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (4, 5)
                        } else if index == 51 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: 3, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (5, 6)
                        } else if index == 52 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: nil, ampmGroup: 3)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (4, 5)
                        } else {
                            recurrenceGroups = (2, 3)
                        }
                        
                        guard let recurringInterval = Int(String(processedText[Range(match.range(at: recurrenceGroups.interval), in: processedText)!])) else { continue }
                        let recurringUnit = String(processedText[Range(match.range(at: recurrenceGroups.unit), in: processedText)!])
                        
                        if let targetWeekday = timeKeywords[weekdayString] {
                            let daysToAdd = 7 + (targetWeekday - calendar.component(.weekday, from: now))
                            let startDate = calendar.date(byAdding: .day, value: daysToAdd > 7 ? daysToAdd - 7 : daysToAdd, to: now) ?? now
                            var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                            startComponents.hour = hour
                            startComponents.minute = minute
                            
                            return (calendar.date(from: startComponents), true, recurringInterval, getFrequency(from: recurringUnit), nil)
                        }
                    } else if index >= 54 && index <= 58 {
                        // weekday + in X weeks patterns
                        let weekdayString = String(processedText[Range(match.range(at: 1), in: processedText)!])
                        guard let weeksAhead = Int(String(processedText[Range(match.range(at: 2), in: processedText)!])) else { continue }
                        var hour = 9, minute = 0
                        let recurrenceGroups: (interval: Int, unit: Int)
                        
                        if index == 54 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: 4, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (6, 7)
                        } else if index == 55 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: nil, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (5, 6)
                        } else if index == 56 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: 4, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (6, 7)
                        } else if index == 57 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: nil, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (5, 6)
                        } else {
                            recurrenceGroups = (3, 4)
                        }
                        
                        guard let recurringInterval = Int(String(processedText[Range(match.range(at: recurrenceGroups.interval), in: processedText)!])) else { continue }
                        let recurringUnit = String(processedText[Range(match.range(at: recurrenceGroups.unit), in: processedText)!])
                        
                        if let targetWeekday = timeKeywords[weekdayString] {
                            // Calculate X weeks from now, then find the target weekday
                            let targetWeekDate = calendar.date(byAdding: .weekOfYear, value: weeksAhead, to: now) ?? now
                            let daysToAdd = (targetWeekday - calendar.component(.weekday, from: targetWeekDate) + 7) % 7
                            let startDate = calendar.date(byAdding: .day, value: daysToAdd, to: targetWeekDate) ?? targetWeekDate
                            var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                            startComponents.hour = hour
                            startComponents.minute = minute
                            
                            return (calendar.date(from: startComponents), true, recurringInterval, getFrequency(from: recurringUnit), nil)
                        }
                    }
                }
                // Week+weekday patterns without recurring (indices 46-70)  
                else if index >= 59 && index <= 83 {
                    if index >= 59 && index <= 63 {
                        // next week + weekday patterns (no recurring)
                        let weekdayString = String(processedText[Range(match.range(at: 1), in: processedText)!])
                        var hour = 9, minute = 0
                        
                        if index == 59 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: 3, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                        } else if index == 60 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: nil, ampmGroup: 3)
                            hour = time.hour; minute = time.minute
                        } else if index == 61 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: 3, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                        } else if index == 62 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: nil, ampmGroup: 3)
                            hour = time.hour; minute = time.minute
                        }
                        
                        if let targetWeekday = timeKeywords[weekdayString] {
                            let daysToAdd = 7 + (targetWeekday - calendar.component(.weekday, from: now))
                            let startDate = calendar.date(byAdding: .day, value: daysToAdd > 7 ? daysToAdd - 7 : daysToAdd, to: now) ?? now
                            var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                            startComponents.hour = hour
                            startComponents.minute = minute
                            
                            return (calendar.date(from: startComponents), false, nil, nil, nil)
                        }
                    } else if index >= 64 && index <= 68 {
                        // in X weeks + weekday patterns (no recurring)
                        guard let weeksAhead = Int(String(processedText[Range(match.range(at: 1), in: processedText)!])) else { continue }
                        let weekdayString = String(processedText[Range(match.range(at: 2), in: processedText)!])
                        var hour = 9, minute = 0
                        
                        if index == 64 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: 4, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                        } else if index == 65 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: nil, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                        } else if index == 66 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: 4, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                        } else if index == 67 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: nil, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                        }
                        
                        if let targetWeekday = timeKeywords[weekdayString] {
                            // Calculate X weeks from now, then find the target weekday
                            let targetWeekDate = calendar.date(byAdding: .weekOfYear, value: weeksAhead, to: now) ?? now
                            let daysToAdd = (targetWeekday - calendar.component(.weekday, from: targetWeekDate) + 7) % 7
                            let startDate = calendar.date(byAdding: .day, value: daysToAdd, to: targetWeekDate) ?? targetWeekDate
                            var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                            startComponents.hour = hour
                            startComponents.minute = minute
                            
                            return (calendar.date(from: startComponents), false, nil, nil, nil)
                        }
                    } else if index >= 69 && index <= 73 {
                        // weekday + next week patterns (no recurring)
                        let weekdayString = String(processedText[Range(match.range(at: 1), in: processedText)!])
                        var hour = 9, minute = 0
                        
                        if index == 69 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: 3, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                        } else if index == 70 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: nil, ampmGroup: 3)
                            hour = time.hour; minute = time.minute
                        } else if index == 71 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: 3, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                        } else if index == 72 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 2, minuteGroup: nil, ampmGroup: 3)
                            hour = time.hour; minute = time.minute
                        }
                        
                        if let targetWeekday = timeKeywords[weekdayString] {
                            let daysToAdd = 7 + (targetWeekday - calendar.component(.weekday, from: now))
                            let startDate = calendar.date(byAdding: .day, value: daysToAdd > 7 ? daysToAdd - 7 : daysToAdd, to: now) ?? now
                            var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                            startComponents.hour = hour
                            startComponents.minute = minute
                            
                            return (calendar.date(from: startComponents), false, nil, nil, nil)
                        }
                    } else if index >= 74 && index <= 78 {
                        // weekday + in X weeks patterns (no recurring)
                        let weekdayString = String(processedText[Range(match.range(at: 1), in: processedText)!])
                        guard let weeksAhead = Int(String(processedText[Range(match.range(at: 2), in: processedText)!])) else { continue }
                        var hour = 9, minute = 0
                        
                        if index == 74 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: 4, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                        } else if index == 75 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: nil, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                        } else if index == 76 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: 4, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                        } else if index == 77 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: nil, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                        }
                        
                        if let targetWeekday = timeKeywords[weekdayString] {
                            // Calculate X weeks from now, then find the target weekday
                            let targetWeekDate = calendar.date(byAdding: .weekOfYear, value: weeksAhead, to: now) ?? now
                            let daysToAdd = (targetWeekday - calendar.component(.weekday, from: targetWeekDate) + 7) % 7
                            let startDate = calendar.date(byAdding: .day, value: daysToAdd, to: targetWeekDate) ?? targetWeekDate
                            var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                            startComponents.hour = hour
                            startComponents.minute = minute
                            
                            return (calendar.date(from: startComponents), false, nil, nil, nil)
                        }
                    } else if index >= 79 && index <= 83 {
                        // Simple time patterns for next week with recurring
                        var hour = 9, minute = 0
                        let recurrenceGroups: (interval: Int, unit: Int)
                        
                        if index == 79 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 1, minuteGroup: 2, ampmGroup: 3)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (4, 5)
                        } else if index == 80 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 1, minuteGroup: nil, ampmGroup: 2)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (3, 4)
                        } else if index == 81 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 1, minuteGroup: 2, ampmGroup: 3)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (4, 5)
                        } else if index == 82 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 1, minuteGroup: nil, ampmGroup: 2)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (3, 4)
                        } else {
                            recurrenceGroups = (1, 2)
                        }
                        
                        guard let recurringInterval = Int(String(processedText[Range(match.range(at: recurrenceGroups.interval), in: processedText)!])) else { continue }
                        let recurringUnit = String(processedText[Range(match.range(at: recurrenceGroups.unit), in: processedText)!])
                        
                        // Next week on same weekday as today
                        let startDate = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
                        var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                        startComponents.hour = hour
                        startComponents.minute = minute
                        
                        return (calendar.date(from: startComponents), true, recurringInterval, getFrequency(from: recurringUnit), nil)
                    }
                }
                // Simple next week patterns without recurring (indices 71-75)
                else if index >= 84 && index <= 88 {
                    var hour = 9, minute = 0
                    
                    if index == 84 {
                        let time = parseTime(from: processedText, match: match, hourGroup: 1, minuteGroup: 2, ampmGroup: 3)
                        hour = time.hour; minute = time.minute
                    } else if index == 85 {
                        let time = parseTime(from: processedText, match: match, hourGroup: 1, minuteGroup: nil, ampmGroup: 2)
                        hour = time.hour; minute = time.minute
                    } else if index == 86 {
                        let time = parseTime(from: processedText, match: match, hourGroup: 1, minuteGroup: 2, ampmGroup: 3)
                        hour = time.hour; minute = time.minute
                    } else if index == 87 {
                        let time = parseTime(from: processedText, match: match, hourGroup: 1, minuteGroup: nil, ampmGroup: 2)
                        hour = time.hour; minute = time.minute
                    }
                    
                    // Next week on same weekday as today
                    let startDate = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
                    var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                    startComponents.hour = hour
                    startComponents.minute = minute
                    
                    return (calendar.date(from: startComponents), false, nil, nil, nil)
                }
                // Reverse order patterns: "weekday in X weeks/months" (indices 76-85)
                else if index >= 92 && index <= 101 {
                    if index >= 92 && index <= 96 {
                        // "weekday in X weeks/months" patterns WITHOUT recurring
                        let weekdayString = String(processedText[Range(match.range(at: 1), in: processedText)!])
                        guard let weeksOrMonths = Int(String(processedText[Range(match.range(at: 2), in: processedText)!])) else { continue }
                        let unit = String(processedText[Range(match.range(at: 3), in: processedText)!])
                        var hour = 9, minute = 0
                        
                        if index == 92 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: 5, ampmGroup: 6)
                            hour = time.hour; minute = time.minute
                        } else if index == 93 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: nil, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                        } else if index == 94 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: 5, ampmGroup: 6)
                            hour = time.hour; minute = time.minute
                        } else if index == 95 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: nil, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                        }
                        
                        if let targetWeekday = timeKeywords[weekdayString] {
                            let dateComponent: Calendar.Component = unit.contains("week") ? .weekOfYear : .month
                            let targetDate = calendar.date(byAdding: dateComponent, value: weeksOrMonths, to: now) ?? now
                            let daysToAdd = (targetWeekday - calendar.component(.weekday, from: targetDate) + 7) % 7
                            let startDate = calendar.date(byAdding: .day, value: daysToAdd, to: targetDate) ?? targetDate
                            var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                            startComponents.hour = hour
                            startComponents.minute = minute
                            
                            return (calendar.date(from: startComponents), false, nil, nil, nil)
                        }
                    } else if index >= 97 && index <= 101 {
                        // "weekday in X weeks/months" patterns WITH recurring
                        let weekdayString = String(processedText[Range(match.range(at: 1), in: processedText)!])
                        guard let weeksOrMonths = Int(String(processedText[Range(match.range(at: 2), in: processedText)!])) else { continue }
                        let unit = String(processedText[Range(match.range(at: 3), in: processedText)!])
                        var hour = 9, minute = 0
                        let recurrenceGroups: (interval: Int, unit: Int)
                        
                        if index == 97 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: 5, ampmGroup: 6)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (7, 8)
                        } else if index == 98 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: nil, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (6, 7)
                        } else if index == 99 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: 5, ampmGroup: 6)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (7, 8)
                        } else if index == 100 {
                            let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: nil, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                            recurrenceGroups = (6, 7)
                        } else {
                            recurrenceGroups = (4, 5)
                        }
                        
                        guard let recurringInterval = Int(String(processedText[Range(match.range(at: recurrenceGroups.interval), in: processedText)!])) else { continue }
                        let recurringUnit = String(processedText[Range(match.range(at: recurrenceGroups.unit), in: processedText)!])
                        
                        if let targetWeekday = timeKeywords[weekdayString] {
                            let dateComponent: Calendar.Component = unit.contains("week") ? .weekOfYear : .month
                            let targetDate = calendar.date(byAdding: dateComponent, value: weeksOrMonths, to: now) ?? now
                            let daysToAdd = (targetWeekday - calendar.component(.weekday, from: targetDate) + 7) % 7
                            let startDate = calendar.date(byAdding: .day, value: daysToAdd, to: targetDate) ?? targetDate
                            var startComponents = calendar.dateComponents([.year, .month, .day], from: startDate)
                            startComponents.hour = hour
                            startComponents.minute = minute
                            
                            return (calendar.date(from: startComponents), true, recurringInterval, getFrequency(from: recurringUnit), nil)
                        }
                    }
                }
            }
        }
        
        for (index, pattern) in datePatterns.enumerated() {
            if let match = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive).firstMatch(in: processedText, options: [], range: NSRange(location: 0, length: processedText.count)) {
                if index <= 2 { // Date with year
                    guard let firstValue = Int(String(processedText[Range(match.range(at: 1), in: processedText)!])),
                          let secondValue = Int(String(processedText[Range(match.range(at: 2), in: processedText)!])),
                          let year = Int(String(processedText[Range(match.range(at: 3), in: processedText)!])) else { continue }
                    
                    guard let dateComponents = parseDateComponents(firstValue: firstValue, secondValue: secondValue) else { continue }
                    let month = dateComponents.month
                    let day = dateComponents.day
                    
                    var hour = 9, minute = 0
                    if index <= 1 { // Date with year and time
                        let time = parseTime(from: processedText, match: match, hourGroup: 4, minuteGroup: 5, ampmGroup: 6)
                        hour = time.hour; minute = time.minute
                    }
                    
                    let targetComponents = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
                    return (calendar.date(from: targetComponents), false, nil, nil, nil)
                } else { // Date without year
                    if let firstValue = Int(String(processedText[Range(match.range(at: 1), in: processedText)!])),
                       let secondValue = Int(String(processedText[Range(match.range(at: 2), in: processedText)!])),
                       let dateComponents = parseDateComponents(firstValue: firstValue, secondValue: secondValue) {
                        
                        let month = dateComponents.month
                        let day = dateComponents.day
                        
                        var hour = 9, minute = 0
                        if pattern.contains(":") {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: 4, ampmGroup: 5)
                            hour = time.hour; minute = time.minute
                        } else if pattern.contains("am") || pattern.contains("pm") {
                            let time = parseTime(from: processedText, match: match, hourGroup: 3, minuteGroup: nil, ampmGroup: 4)
                            hour = time.hour; minute = time.minute
                        }

                        var targetComponents = DateComponents(month: month, day: day, hour: hour, minute: minute)
                        targetComponents.year = calendar.component(.year, from: now)
                        if let targetDate = calendar.date(from: targetComponents), targetDate < now {
                            targetComponents.year! += 1
                        }
                        return (calendar.date(from: targetComponents), false, nil, nil, nil)
                    }
                }
            }
        }
        
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        var targetDay: Int?
        var targetTime: (hour: Int, minute: Int)?

        for (keyword, dayOffset) in timeKeywords {
            if processedText.contains(keyword) {
                if keyword == "today" || keyword == "td" { targetDay = 0 }
                else if keyword == "tomorrow" || keyword == "tm" { targetDay = 1 }
                else {
                    let currentWeekday = calendar.component(.weekday, from: now)
                    var daysUntilTarget = dayOffset - currentWeekday
                    if daysUntilTarget <= 0 { daysUntilTarget += 7 }
                    targetDay = daysUntilTarget
                }
                break
            }
        }

        for (index, pattern) in timePatterns.enumerated() {
            if let match = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive).firstMatch(in: processedText, options: [], range: NSRange(location: 0, length: processedText.count)) {
                if index == 0 || index == 2 {
                    targetTime = parseTime(from: processedText, match: match, hourGroup: 1, minuteGroup: 2, ampmGroup: 3)
                } else if index == 1 || index == 3 {
                    targetTime = parseTime(from: processedText, match: match, hourGroup: 1, minuteGroup: nil, ampmGroup: 2)
                } else {
                    // Patterns 4 and 5: standalone numbers, only have 1 group
                    targetTime = parseTime(from: processedText, match: match, hourGroup: 1, minuteGroup: nil, ampmGroup: nil)
                }
                break
            }
        }

        if targetDay != nil || targetTime != nil {
            if let day = targetDay {
                var date = now
                if day > 0 {
                    date = calendar.date(byAdding: .day, value: day, to: date)!
                }
                components = calendar.dateComponents([.year, .month, .day], from: date)
            }
            if let time = targetTime {
                components.hour = time.hour
                components.minute = time.minute
            } else {
                components.hour = 9
                components.minute = 0
            }
            return (calendar.date(from: components), false, nil, nil, nil)
        }
        
        return (nil, false, nil, nil, nil)
    }
    
    private func parseTime(from text: String, match: NSTextCheckingResult, hourGroup: Int, minuteGroup: Int?, ampmGroup: Int?) -> (hour: Int, minute: Int) {
        var hour = 9
        var minute = 0

        let hourRange = match.range(at: hourGroup)
        if hourRange.location != NSNotFound {
            hour = Int(String(text[Range(hourRange, in: text)!])) ?? 9
        }

        if let minuteGroup = minuteGroup {
            let minuteRange = match.range(at: minuteGroup)
            if minuteRange.location != NSNotFound, minuteRange.length > 0 {
                minute = Int(String(text[Range(minuteRange, in: text)!])) ?? 0
            }
        }

        if let ampmGroup = ampmGroup {
            let ampmRange = match.range(at: ampmGroup)
            if ampmRange.location != NSNotFound, ampmRange.length > 0 {
                let ampmString = String(text[Range(ampmRange, in: text)!]).lowercased()
                if ampmString == "pm" && hour != 12 { hour += 12 }
                else if ampmString == "am" && hour == 12 { hour = 0 }
            } else {
                let defaultAmPm = colorTheme?.defaultAmPm ?? "AM"
                if defaultAmPm == "PM" && hour != 12 { hour += 12 }
                else if defaultAmPm == "AM" && hour == 12 { hour = 0 }
            }
        }
        
        return (hour, minute)
    }

    private func parseDateComponents(firstValue: Int, secondValue: Int) -> (month: Int, day: Int)? {
        // Get the user's date format preference, defaulting to MM/DD if not available
        let dateFormat = colorTheme?.dateFormat ?? .mmdd
        
        let (month, day): (Int, Int)
        
        switch dateFormat {
        case .mmdd:
            // MM/DD format: first value is month, second value is day
            month = firstValue
            day = secondValue
        case .ddmm:
            // DD/MM format: first value is day, second value is month
            month = secondValue
            day = firstValue
        }
        
        // Validate the date components
        guard month >= 1 && month <= 12 && day >= 1 && day <= 31 else {
            return nil // Invalid date - reject it completely
        }
        
        // Additional validation: check if day is valid for the specific month
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.year = calendar.component(.year, from: Date()) // Use current year for validation
        
        guard calendar.date(from: dateComponents) != nil else {
            return nil // Invalid date (e.g., Feb 30th)
        }
        
        return (month: month, day: day)
    }

    private func getFrequency(from unit: String) -> EKRecurrenceFrequency {
        switch unit {
        case "day", "days": return .daily
        case "week", "weeks": return .weekly
        case "month", "months": return .monthly
        default: return .daily
        }
    }
    
}

struct ParsedReminder {
    let title: String
    let dueDate: Date?
    let isRecurring: Bool
    let recurrenceInterval: Int?
    let recurrenceFrequency: EKRecurrenceFrequency?
    let recurrenceEndDate: Date?
    let isValid: Bool
    let errorMessage: String?
    
    init(title: String, dueDate: Date?, isRecurring: Bool = false, recurrenceInterval: Int? = nil, recurrenceFrequency: EKRecurrenceFrequency? = nil, recurrenceEndDate: Date? = nil, isValid: Bool = true, errorMessage: String? = nil) {
        self.title = title
        self.dueDate = dueDate
        self.isRecurring = isRecurring
        self.recurrenceInterval = recurrenceInterval
        self.recurrenceFrequency = recurrenceFrequency
        self.recurrenceEndDate = recurrenceEndDate
        self.isValid = isValid
        self.errorMessage = errorMessage
    }
}