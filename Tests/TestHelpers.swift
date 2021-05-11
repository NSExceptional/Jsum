//
//  TestHelpers.swift
//  JsumTests
//
//  Created by Tanner Bennett on 5/11/21.
//

import Foundation

extension Date {
    var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    var ignoringTime: Date {
        let comps = Calendar.current.dateComponents([.day, .year], from: self)
        return Calendar.current.date(from: comps)!
    }
}

extension Result {
    var failed: Bool {
        if case .failure(_) = self {
            return true
        }
        
        return false
    }
    
    var succeeded: Bool {
        if case .failure(_) = self {
            return false
        }
        
        return true
    }
}
