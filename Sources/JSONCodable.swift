//
//  JSONCodable.swift
//  Jsum
//
//  Created by Tanner Bennett on 4/16/21.
//

import Foundation

public enum JSONDecodableError: Error {
    case decodingNotImplemented
}

public protocol JSONCodable {
    /// Encodes the conformer to JSON
    var toJSON: JSON { get }
    /// Sensible default used to coalesce the conformer from nil
    static var defaultJSON: JSON { get }
    /// A key path to a computed property to use to initialize
    /// the conformer or throw an error if the result is nil
    static var jsonKeyPathForDecoding: PartialKeyPath<JSON> { get }
    /// Initialize an instance of the conformer from JSON
    static func decode(from json: JSON) throws -> Self
}

extension JSONCodable {
    /// If neither this property nor decode() are implemented,
    /// `JSONDecodableError.decodingNotImplemented` will be thrown
    public static var jsonKeyPathForDecoding: PartialKeyPath<JSON> { \JSON.self }
    
    public static func decode(from json: JSON) throws -> Self {
        if let keyPath = self.jsonKeyPathForDecoding as? KeyPath<JSON,Self?> {
            guard let value = json[keyPath: keyPath] else {
                throw TransformError.notConvertible
            }
            
            return value
        }
        
        if let keyPath = self.jsonKeyPathForDecoding as? KeyPath<JSON,Self> {
            return json[keyPath: keyPath]
        }
        
        throw JSONDecodableError.decodingNotImplemented
    }
}

extension NSNull: JSONCodable {
    public var toJSON: JSON { .null }
    public static var defaultJSON: JSON { .null }
}

extension Optional: JSONCodable where Wrapped: JSONCodable {
    public var toJSON: JSON {
        switch self {
            case .none: return .null
            case .some(let v): return v.toJSON
        }
    }
    
    public static var defaultJSON: JSON { .null }
    
    public static func decode(from json: JSON) throws -> Self {
        switch json {
            case .null: return nil
            case .bool(let v): return v as? Wrapped
            case .int(let v): return v as? Wrapped
            case .float(let v): return v as? Wrapped
            case .string(let v): return v as? Wrapped
            case .array(let v): return v as? Wrapped
            case .object(let v): return v as? Wrapped
        }
    }
}

extension Bool: JSONCodable {
    public static var jsonKeyPathForDecoding: PartialKeyPath<JSON> = \.toBool
    public var toJSON: JSON { .bool(self) }
    public static var defaultJSON: JSON = .bool(false)
}

extension String: JSONCodable {
    public static var jsonKeyPathForDecoding: PartialKeyPath<JSON> = \.toString
    public var toJSON: JSON { .string(self) }
    public static var defaultJSON: JSON = .string("")
}

extension Int: JSONCodable {
    public static var jsonKeyPathForDecoding: PartialKeyPath<JSON> = \.toInt
    public var toJSON: JSON { .int(Int(self)) }
    public static var defaultJSON: JSON = .int(0)
}

extension Double: JSONCodable {
    public static var jsonKeyPathForDecoding: PartialKeyPath<JSON> = \.toFloat
    public var toJSON: JSON { .float(self) }
    public static var defaultJSON: JSON = .float(0)
}

extension Array: JSONCodable where Element: JSONCodable {
    public var toJSON: JSON { .array(self.map(\.toJSON)) }
    public static var defaultJSON: JSON { .array([]) }
    
    public static func decode(from json: JSON) throws -> Self {
        return try json.asArray.map(Element.decode(from:))
    }
}

extension Dictionary: JSONCodable where Key == String, Value: JSONCodable {
    public var toJSON: JSON { .object(self.mapValues(\.toJSON)) }
    public static var defaultJSON: JSON { .object([:]) }
    
    public static func decode(from json: JSON) throws -> Self {
        return try json.asObject.mapValues(Value.decode(from:))
    }
}
