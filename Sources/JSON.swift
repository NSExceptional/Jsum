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
    
    public var asArray: [JSON] {
        switch self {
            case .null: return []
            case .array(let a): return a
            case .object(let o): return Array(o.values)
            default: return []
        }
    }
    
    public var asObject: [String: JSON] {
        switch self {
            case .null: return [:]
            case .object(let o): return o
            default: fatalError("Cannot convert non-objects to object")
        }
    }
}
