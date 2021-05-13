//
//  NumericConversions.swift
//  Jsum
//
//  Created by Tanner Bennett on 4/26/21.
//

import Foundation

prefix operator ~
private prefix func ~<T>(target: Any) -> T {
    return target as! T
}

extension Jsum {
    static func convert(number: NSNumber, to desiredType: Any.Type) -> Any {        
        switch desiredType {
            case is Int8.Type:  return number.int8Value
            case is Int16.Type: return number.int16Value
            case is Int32.Type: return number.int32Value
            case is Int64.Type: return number.int64Value
            case is Int.Type:   return number.intValue
                
            case is UInt8.Type:  return number.uint8Value
            case is UInt16.Type: return number.uint16Value
            case is UInt32.Type: return number.uint32Value
            case is UInt64.Type: return number.uint64Value
            case is UInt.Type:   return number.uintValue
                
            case is Float32.Type: return Float32(number.floatValue)
            case is Float64.Type: return Float64(number.doubleValue)
            case is Float.Type:   return number.floatValue
            case is Double.Type:  return number.doubleValue
            
            default: fatalError("Unexpected type '\(desiredType)'")
        }
    }
}
