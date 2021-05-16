//
//  Jsum+Helpers.swift
//  
//
//  Created by Tanner Bennett on 5/10/21.
//

import Foundation

extension Jsum {
    //
    // This function is part of the Swift.org open source project
    //
    // Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
    // Licensed under Apache License v2.0 with Runtime Library Exception
    //
    // See https://swift.org/LICENSE.txt for license information
    // See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
    //
    // Taken from JSONEncoder.swift in the standard library
    /// Convert a given snake_case string to its camelCase equivalent.
    /// Exposed so you can use it as you see fit in a custom key decoder.
    public static func snakeCaseToCamelCase(_ stringKey: String) -> String {
        guard !stringKey.isEmpty else { return stringKey }
    
        // Find the first non-underscore character
        guard let firstNonUnderscore = stringKey.firstIndex(where: { $0 != "_" }) else {
            // Reached the end without finding an _
            return stringKey
        }
    
        // Find the last non-underscore character
        var lastNonUnderscore = stringKey.index(before: stringKey.endIndex)
        while lastNonUnderscore > firstNonUnderscore && stringKey[lastNonUnderscore] == "_" {
            stringKey.formIndex(before: &lastNonUnderscore)
        }
    
        let keyRange = firstNonUnderscore...lastNonUnderscore
        let leadingUnderscoreRange = stringKey.startIndex..<firstNonUnderscore
        let trailingUnderscoreRange = stringKey.index(after: lastNonUnderscore)..<stringKey.endIndex
    
        let components = stringKey[keyRange].split(separator: "_")
        let joinedString : String
        if components.count == 1 {
            // No underscores in key, leave the word as is - maybe already camel cased
            joinedString = String(stringKey[keyRange])
        } else {
            joinedString = ([components[0].lowercased()] + components[1...].map { $0.capitalized }).joined()
        }
    
        // Do a cheap isEmpty check before creating and appending potentially empty strings
        let result : String
        if (leadingUnderscoreRange.isEmpty && trailingUnderscoreRange.isEmpty) {
            result = joinedString
        } else if (!leadingUnderscoreRange.isEmpty && !trailingUnderscoreRange.isEmpty) {
            // Both leading and trailing underscores
            result = String(stringKey[leadingUnderscoreRange]) + joinedString + String(stringKey[trailingUnderscoreRange])
        } else if (!leadingUnderscoreRange.isEmpty) {
            // Just leading
            result = String(stringKey[leadingUnderscoreRange]) + joinedString
        } else {
            // Just trailing
            result = joinedString + String(stringKey[trailingUnderscoreRange])
        }
        return result
    }

extension Result {
    public var failed: Bool {
        if case .failure(_) = self {
            return true
        }
        
        return false
    }
    
    public var succeeded: Bool {
        if case .failure(_) = self {
            return false
        }
        
        return true
    }
    
    public var error: Failure? {
        if case .failure(let e) = self {
            return e
        }
        
        return nil
    }
}
