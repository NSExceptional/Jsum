//
//  File.swift
//  
//
//  Created by Tanner Bennett on 5/15/21.
//

import Foundation
import Echo

extension StructMetadata {
    var isSimpleType: Bool {
        if self.isBuiltin { return true }
        
        let desc = self.descriptor
        if self.type == String.self ||
            desc == KnownMetadata.array ||
            desc == KnownMetadata.dictionary {
            return true
        }
        
        return false
    }
}

protocol Emptyable {
    var isEmpty: Bool { get }
}

extension Array: Emptyable { }
extension String: Emptyable { }
extension Dictionary: Emptyable { }
extension Int: Emptyable {
    var isEmpty: Bool { self == 0 }
}
extension Double: Emptyable {
    var isEmpty: Bool { self == 0 }
}
extension UInt: Emptyable {
    var isEmpty: Bool { self == 0 }
}
