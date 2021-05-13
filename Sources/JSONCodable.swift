//
//  JSONCodable.swift
//  Jsum
//
//  Created by Tanner Bennett on 4/16/21.
//

import Foundation
import Echo

public enum JSONDecodableError: Error {
    case decodingNotImplemented
}

typealias JSONCodableInfo = (
    transformers: [String: AnyTransformer],
    jsonKeyPaths: [String: String],
    defaults: [String: Any]
)

public protocol JSONCodable {
    /// Encodes the conformer to JSON
    var toJSON: JSON { get }
    /// Whether or not to opt-into synthesizing `defaultJSON` for nominal types
    static var synthesizesDefaultJSON: Bool { get }
    /// Sensible default used to coalesce the conformer from nil
    static var defaultJSON: JSON { get }
    /// A key path to a computed property to use to initialize
    /// the conformer or throw an error if the result is nil
    static var jsonKeyPathForDecoding: PartialKeyPath<JSON> { get }
    /// Transformers are never passed nil; use default values
    /// to coerce nil to something else. JSONCodable types
    /// provide default values automatically, too, so you
    /// only need to provide default values for those if you
    /// need a different default value than the one provided.
    static var transformersByProperty: [String: AnyTransformer] { get }
    /// A mapping of property names to JSON key paths. Useful for
    /// flattening the hierarchy of a particular JSON object.
    static var jsonKeyPathsByProperty: [String: String] { get }
    /// A mapping of property names to default values. Use this
    /// to supply a default value for a non-optional property.
    /// If the type of your property conforms to JSONCodable,
    /// that type may provide its own default value through
    /// `var defaultJSON`. This property will override that.
    static var defaultsByProperty: [String: Any] { get }
    /// Initialize an instance of the conformer from JSON
    static func decode(from json: JSON) throws -> Self
}

struct AnyJSONCodable {
    let wrapped: JSONCodable
    
    init(_ json: JSONCodable) {
        self.wrapped = json
    }
}

extension JSONCodable {
    private var existential: AnyExistentialContainer { container(for: self) }
    private var isClass: Bool { self.existential.metadata.kind.isObject }
    private static var existential: AnyExistentialContainer { container(for: self) }
    private static var instanceMetadata: Metadata {
        let metadata = self.existential.metadata as! MetatypeMetadata
        return metadata.instanceMetadata
    }
    static var isClass: Bool {
        return self.instanceMetadata.kind.isObject
    }
    static var isTuple: Bool {
        return self.instanceMetadata.kind == .tuple
    }
    
    public static var synthesizesDefaultJSON: Bool { false }
    
    public var toJSON: JSON {
        /// TODO: implement reverse decoding so that this works
        if self.isClass {
            return .object(["class": .string("\(type(of: self))")])
        }
        
        return .null
    }
    
    public static var defaultJSON: JSON {
        if self.synthesizesDefaultJSON {
            // TODO: make this use values from defaultJSON
            return try! Jsum.synthesizeJSON(Self.self) as! JSON
        }
        
        fatalError("defaultJSON not implemented for type")
    }
}

extension JSONCodable {
    /// If neither this property nor decode() are implemented,
    /// `JSONDecodableError.decodingNotImplemented` will be thrown
    public static var jsonKeyPathForDecoding: PartialKeyPath<JSON> { \JSON.self }
    public static var transformersByProperty: [String: AnyTransformer] { [:] }
    public static var jsonKeyPathsByProperty: [String: String] { [:] }
    public static var defaultsByProperty: [String: Any] { [:] }
    
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
    
    var asArray: [Any]? {
        return self as? [Any]
    }
    
    var asDictionary: [String: Any]? {
        return self as? [String: Any]
    }
    
    var any: AnyJSONCodable { AnyJSONCodable(self) }
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

extension NSString: JSONCodable {
    public static var jsonKeyPathForDecoding: PartialKeyPath<JSON> = \.toString
    public var toJSON: JSON { .string(self as String) }
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

extension NSNumber: JSONCodable {
    public static var jsonKeyPathForDecoding: PartialKeyPath<JSON> = \.toFloat
    public var toJSON: JSON {
        if self.isBool {
            return .bool(self.boolValue)
        }
        if self.isFloat {
            return .float(self.doubleValue)
        }
        return .int(self.intValue)
    }
    
    public static var defaultJSON: JSON = .float(0)
}

extension Date: JSONCodable {
    public static var jsonKeyPathForDecoding: PartialKeyPath<JSON> = \.toDate
    public var toJSON: JSON { return .float(self.timeIntervalSince1970) }
    public static var defaultJSON: JSON = .int(0)
}

extension Data: JSONCodable {
    public static var jsonKeyPathForDecoding: PartialKeyPath<JSON> = \.toData
    public var toJSON: JSON { return .string(self.base64EncodedString()) }
    public static var defaultJSON: JSON = .string("")
}

extension Array: JSONCodable where Element: JSONCodable {
    public var toJSON: JSON { .array(self.map(\.toJSON)) }
    public static var defaultJSON: JSON { .array([]) }
    
    public static func decode(from json: JSON) throws -> Self {
//        return json.asArray.map(\.unwrapped)
        return try json.asArray.map(Element.decode(from:))
    }
}

extension Dictionary: JSONCodable where Key == String, Value: JSONCodable {
    public var toJSON: JSON { .object(self.mapValues(\.toJSON)) }
    public static var defaultJSON: JSON { .object([:]) }
    
    public static func decode(from json: JSON) throws -> Self {
//        return json.asObject.mapValues(\.unwrapped)
        return try json.asObject.mapValues(Value.decode(from:))
    }
}

extension Dictionary where Key == String {
    func value(for jsonKeyPath: String) throws -> Any? {
        if jsonKeyPath.contains(".") {
            // Nested key paths must consist of at least "x.x"
            assert(jsonKeyPath.count > 2)
            
            // Get list of keys from key path, stop at the last key
            var keys = jsonKeyPath.split(separator: ".").map(String.init)
            let lastKey = keys.popLast()!
            
            // Iteratively get nested dictionaries until we reach the last key
            var dict = self
            for key in keys {
                if let subdict = dict[key] as? Self {
                    dict = subdict
                } else {
                    throw Jsum.Error.couldNotDecode("Invalid JSON key path '\(jsonKeyPath)'")
                }
            }
            
            return dict[lastKey]
        }
        
        return self[jsonKeyPath]
    }
}
