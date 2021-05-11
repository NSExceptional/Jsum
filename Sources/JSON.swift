//
//  JSON.swift
//  Jsum
//
//  Created by Tanner Bennett on 4/16/21.
//

import Foundation

public enum JSON: Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case float(Double)
    case string(String)
    case array([JSON])
    case object([String: JSON])
    
    public var unwrapped: Any {
        switch self {
            case .null: return NSNull()
            case .bool(let v): return v
            case .int(let v): return v
            case .float(let v): return v
            case .string(let v): return v
            case .array(let v): return v.map(\.unwrapped)
            case .object(let v): return v.mapValues(\.unwrapped)
        }
    }
    
    public var toBool: Bool {
        switch self {
            case .null: return false
            case .bool(let v): return v
            case .int(let v): return v != 0
            case .float(let v): return v != 0.0
            case .string(let v): return !v.isEmpty
            case .array(let v): return !v.isEmpty
            case .object(_): return true
        }
    }
    
    public var toInt: Int? {
        switch self {
            case .null: return 0
            case .bool(let v): return v ? 1 : 0
            case .int(let v): return v
            case .float(let v): return Int(v)
            case .string(let v): return Int(v) ?? nil
            case .array(_): return nil
            case .object(_): return nil
        }
    }
    
    /// Arrays and objects return nil.
    public var toFloat: Double? {
        switch self {
            case .null: return 0
            case .bool(let v): return v ? 1 : 0
            case .int(let v): return Double(v)
            case .float(let v): return v
            case .string(let v): return Double(v) ?? nil
            case .array(_): return nil
            case .object(_): return nil
        }
    }
    
    public var toString: String {
        switch self {
            case .null: return "null"
            case .bool(let v): return String(v)
            case .int(let v): return String(v)
            case .float(let v): return String(v)
            case .string(let v): return v
            case .array(_): fallthrough
            case .object(_):
                let obj = self.unwrapped
                let data = try! JSONSerialization.data(withJSONObject: obj, options: [])
                return String(data: data, encoding: .utf8)!
        }
    }
    
    /// Attempts to decode numbers as UNIX timestamps and strings as
    /// ISO8601 dates on macOS 10.12 and iOS 10 and beyond; this will
    /// not decode dates from strings on earlier versions of the OSes.
    public var toDate: Date? {
        switch self {
            case .int(let v): return Date(timeIntervalSince1970: Double(v))
            case .float(let v): return Date(timeIntervalSince1970: v)
            case .string(let v):
                if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
                    return ISO8601DateFormatter().date(from: v)
                } else {
                    return nil
                }
                
            default: return nil
        }
    }
    
    /// Attempts to decode strings as base-64 encoded data, and
    /// arrays and objects as JSON strings converted to data.
    public var toData: Data? {
        switch self {
            case .string(let v): return Data(base64Encoded: v)
            case .array(_): fallthrough
            case .object(_):
                let obj = self.unwrapped
                return try! JSONSerialization.data(withJSONObject: obj, options: [])
                
            default: return nil
        }
    }
    
    /// Null is returned as an empty array. Arrays are returned
    /// unmodified. Dictionaries are returned as their values
    /// alone. Everything else is an empty array.
    public var asArray: [JSON] {
        switch self {
            case .null: return []
            case .array(let a): return a
            case .object(let o): return Array(o.values)
            default: return []
        }
    }
    
    /// Null is returned as an empty dictionary. Dictionaries are
    /// returned ummodified. Everything else is a fatal error.
    public var asObject: [String: JSON] {
        switch self {
            case .null: return [:]
            case .object(let o): return o
            default: fatalError("Cannot convert non-objects to object")
        }
    }
}
