//
//  NSNumber+Jsum.swift
//  Jsum
//
//  Created by Tanner Bennett on 5/13/21.
//

import Foundation

extension NSNumber {
    private func _objcTypeIsAny(of types: String) -> Bool {
        return types.contains(self._objcTypeChar)
    }
    
    private func _objcType(is type: String) -> Bool {
        return self.objCType.pointee == type.utf8CString.first
    }
    
    private var _objcTypeChar: Character {
        return Character(Unicode.Scalar(UInt8(self.objCType.pointee)))
    }
    
    var isInt: Bool {
        return self._objcTypeIsAny(of: "liscqLISCQ")
    }
    
    var isFloat: Bool {
        return self._objcTypeIsAny(of: "dfD")
    }
    
    var isBool: Bool {
        return self._objcType(is: "B")
    }
}
