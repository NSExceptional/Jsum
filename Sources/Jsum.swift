//
//  Jsum.swift
//  Jsum
//
//  Created by Tanner Bennett on 4/16/21.
//  Copyright © 2021 Tanner Bennett. All rights reserved.
//

import Foundation
import Echo
import CEcho

public class Jsum {
    public enum Error: Swift.Error {
        /// An error was encountered during decoding.
        case couldNotDecode(String)
        /// Decoding is not supported with the given type or arguments.
        case decodingNotSupported(String)
        /// Some other error was thrown during decoding.
        case other(Swift.Error)
        case notYetImplemented
    }
    
    //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    //  The following enums were adapted  ┃
    //  from the Swift Standard Library.  ┃
    //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
    
    /// The strategy to use for automatically changing the value of keys before decoding.
    public enum KeyDecodingStrategy {

        /// Use the names of the properties of the type. This is the default strategy.
        case usePropertyKeys

        /// Convert from "snake_case_keys" to "camelCaseKeys" before attempting
        /// to match a key with the one specified by the type.
        /// 
        /// The conversion to upper case uses `Locale.system`, also known as the
        /// ICU "root" locale. This means the result is consistent regardless of
        /// the current user's locale and language preferences.
        ///
        /// Converting from snake case to camel case:
        /// 1. Capitalizes the word starting after each `_`
        /// 2. Removes all `_`
        /// 3. Preserves starting and ending `_` (as these are often used to
        /// indicate private variables or other metadata).
        /// For example, `one_two_three` becomes `oneTwoThree`.
        /// `_one_two_three_` becomes `_oneTwoThree_`.
        ///
        /// - Note: Using a key decoding strategy has a nominal performance cost,
        /// as each string key has to be inspected for the `_` character.
        case convertFromSnakeCase

        /// Provide a custom conversion from the key in the encoded JSON to the
        /// property key of the decoded types. The last JSON key path component
        /// is passed to the provided closure. The returned key is used in place of
        /// the last component in the coding path before decoding. If the result of
        /// the conversion is a duplicate key, then only one value will be present
        /// in the container for the type to decode from. Which one is undefined.
        case custom((String) -> String)
    }
    
    /// The strategy to use for decoding `Date` values.
    public enum DateDecodingStrategy {

        /// Decode JSON numbers as UNIX timestamps, and strings
        /// as an ISO-8601-formatted strings. This is the default strategy.
        case bestGuess

        /// Decode the `Date` as a UNIX timestamp from a JSON number.
        case secondsSince1970

        /// Decode the `Date` as UNIX millisecond timestamp from a JSON number.
        case millisecondsSince1970

        /// Decode the `Date` as an ISO-8601-formatted string (in RFC 3339 format).
        @available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
        case iso8601

        /// Decode the `Date` as a string parsed by the given formatter.
        /// `DateFormatter` is expensive to create; you should cache it.
        case formatter(DateFormatter)

        /// Decode the `Date` as a custom value decoded by the given closure.
        /// Cast the input value to `String` or `Int` etc. as needed.
        case custom((Any) throws -> Date)
    }

    /// The strategy to use for decoding `Data` values.
    public enum DataDecodingStrategy {

        /// Decode the `Data` from a Base64-encoded string. This is the default strategy.
        case base64

        /// Decode the `Data` as a custom value decoded by the given closure.
        /// Cast the input value to `String` or `Int` etc. as needed. 
        case custom((Any) throws -> Data)
    }
    
    public init() { }
    
    private var _failOnMissingKeys: Bool = false
    private var _failOnNullNonOptionals: Bool = false
    private var _keyDecoding: KeyDecodingStrategy = .usePropertyKeys
    private var _dateDecoding: DateDecodingStrategy = .bestGuess
    private var _dataDecoding: DataDecodingStrategy = .base64
    private let _iso8601Formatter = ISO8601DateFormatter()
    
    private static let specialCaseStructs: [UnsafeRawPointer: OpaqueTransformer] = [
        KnownMetadata.url.ptr: OpaqueTransformer(forwardBlock: { (value) -> Any in
            guard let urlString = value! as? String else {
                throw Error.couldNotDecode("URL requires a string to be decoded")
            }
            
            guard let url = URL(string: urlString) else {
                throw Error.couldNotDecode("URL(string:) returned nil with string '\(urlString)'")
            }
            
            return url
        }),
    ]
    
    /// Set whether decoding should fail when no key is present in the
    /// JSON payload at all for a given property.
    /// 
    /// By default, Jsum will attempt to synthesize a default value if the
    /// property conforms to `JSONCodable`, and _then_ fail if it doesn't.
    /// Transformers are never invoked on missing keys.
    /// 
    /// - Note: The default behavior is the _opposite_ of the default
    /// parameter passed to this builder-function.
    public func failOnMissingKeys(_ flag: Bool = true) -> Self {
        self._failOnMissingKeys = flag
        return self
    }
    
    /// Set whether decoding should fail when null is decoded for a property
    /// with a non-optional type, iff no default value is supplied by the
    /// enclosing type.
    /// 
    /// By default, Jsum will attempt to synthesize a default value if the
    /// property conforms to `JSONCodable`, and _then_ fail if it doesn't.
    /// Transformers are never invoked on null keys.
    /// 
    /// - Note: The default behavior is the _opposite_ of the default
    /// parameter passed to this builder-function.
    public func failOnNullNonOptionals(_ flag: Bool = true) -> Self {
        self._failOnNullNonOptionals = flag
        return self
    }
    
    /// Change the key decoding strategy from the default `.useDefaultKeys`
    public func keyDecoding(strategy: KeyDecodingStrategy) -> Self {
        self._keyDecoding = strategy
        return self
    }
    
    /// Change the date decoding strategy from the default `.useDefaultKeys`
    public func dateDecoding(strategy: DateDecodingStrategy) -> Self {
        self._dateDecoding = strategy
        return self
    }
    
    /// Change the data decoding strategy from the default `.useDefaultKeys`
    public func dataDecoding(strategy: DataDecodingStrategy) -> Self {
        self._dataDecoding = strategy
        return self
    }
    
    /// Try to decode an instance of `T` from the given JSON object with the default options.
    public static func tryDecode<T>(_ type: T.Type = T.self, from json: Any) -> Result<T, Jsum.Error> {
        return Jsum().tryDecode(from: json)
    }
    
    /// Decode an instance of `T` from the given JSON object with the default options.
    public static func decode<T>(from json: Any) throws -> T {
        return try Jsum().decode(from: json)
    }
    
    /// Try to decode an instance of `T` from the given JSON object.
    public func tryDecode<T>(_ type: T.Type = T.self, from json: Any) -> Result<T, Jsum.Error> {
        do {
            let value: T = try self.decode(from: json)
            return .success(value)
        } catch {
            if let error = error as? Jsum.Error {
                return .failure(error)
            }
            
            return .failure(.other(error))
        }
    }

    /// Decode an instance of `T` from the given JSON object.
    public func decode<T>(from json: Any) throws -> T {
        let metadata = reflect(T.self)
        let box = try self.decode(type: metadata, from: json)
        return box as! T
    }
    
    private func decode(type metadata: Metadata, from json: Any) throws -> Any {
        // Case: NSNull and not optional
        // TODO: remove this check and allow all JSONCodable types to be defaulted from nil?
        if json is NSNull && metadata.kind != .optional {
            throw Error.couldNotDecode(
                "Type '\(metadata.type)' cannot be converted from null"
            )
        }
        
        // Case: Strings, arrays of exact type, etc...
        guard metadata.type != type(of: json) else {
            return json
        }
        
        switch metadata.kind {
            case .struct:
                let structure = metadata as! StructMetadata
                if structure.isBuiltin {
                    return try self.decodeBuiltinStruct(structure, from: json)
                } else {
                    return try self.decodeStruct(structure, from: json)
                }
            case .class:
                return try self.decodeClass(metadata as! ClassMetadata, from: json)
            case .enum:
                throw Error.notYetImplemented
            case .optional:
                let optional = metadata as! EnumMetadata
                if json is NSNull {
                    let none = AnyExistentialContainer(nil: optional)
                    return none.toAny
                } else {
                    return try self.decode(type: optional.genericMetadata.first!, from: json)
                }
            case .tuple:
                return try self.decodeTuple(metadata as! TupleMetadata, from: json)
            default:
                throw Error.decodingNotSupported(
                    "Cannot decode kind \(metadata.kind) (\(metadata.type)"
                )
        }
    }
    
    private func decode<M: NominalType>(properties: [String: Any], forType metadata: M) throws -> [String: Any] {
        let (transformers, jsonMap, defaults) = metadata.jsonCodableInfoByProperty
        var decodedProps: [String: Any] = [:]
        
        /// Throws on invalid JSON key path (i.e. key path goes to a non-object
        /// somewhere before the end), but just returns nil for missing keys.
        /// Missing keys are not errors, but invalid JSON key paths are.
        func valueForProperty(_ propertyKey: String) throws -> Any? {
            if let jsonKeyPathForProperty = jsonMap[propertyKey] {
                if let optionalValue = try properties.value(for: jsonKeyPathForProperty) {
                    return optionalValue
                }
            }
            
            // Don't throw an error on the property's own key
            // if it is missing from the payload
            return try? properties.value(for: propertyKey)
        }
        
        for (key, type) in metadata.fields {
            if var value = try valueForProperty(key) {
                // Transform value first, if desired
                if let transform = transformers[key] {
                    // Pass NSNull as nil to transformers
                    //
                    // TODO: there is an inconsistency with this logic. If `valueForProperty`
                    // above returns NSNull, this code executes and we try to transform it.
                    // However, if `valueForProperty` returns nil, we skip the transformer
                    // entirely. NSNull and nil should be treated the same. What is the
                    // right thing to do here? Require default values for non-JSONCodable
                    // types and never pass NSNull/nil to a transformer? That may require
                    // me to rethink how transformers work. (Or will it?)
                    // I could also just check for a transformer in both cases...?
                    // Or, do I want to treat missing keys the same as NSNull?
                    value = try transform.transform(forward: value is NSNull ? nil : value)
                }
                
                // Decode the value into a buffer, copy the buffer into
                // a new AnyExistentialContainer and return it as Any
                decodedProps[key] = try self.decode(type: type, from: value)
            } else {
                // Check if a default value was supplied
                if let defaultValue = defaults[key] {
                    decodedProps[key] = defaultValue
                }
                // If the type we're given is JSONCodable, use the type's default value
                else if let type = type as? TypeMetadata, type.conforms(to: JSONCodable.self),
                   let codable = type.type as? JSONCodable.Type {
                    // Decode the default value to the expected type
                    let defaultValue = codable.defaultJSON.unwrapped
                    decodedProps[key] = try self.decode(type: type, from: defaultValue)
                }
                else {
                    throw Error.couldNotDecode(
                        "Missing key '\(key)' with no default value for type '\(type.type)'"
                    )
                }
            }
        }
        
        return decodedProps
    }
    
    // MARK: Class decoding
    
    private func decodeClass(_ metadata: ClassMetadata, from json: Any) throws -> AnyObject {
        guard let json = json as? [String: Any] else {
            throw Error.couldNotDecode("Cannot decode classes and most structs without a dictionary")
        }
        
        let decodedProps = try self.decode(properties: json, forType: metadata)
        return metadata.createInstance(props: decodedProps)
    }
    
    // MARK: Struct decoding
    
    private func decodeStruct(_ metadata: StructMetadata, from data: Any) throws -> Any {
        assert(!metadata.isBuiltin)
        
        guard let json = data as? [String: Any] else {
            // Case: decoding an array
            if let array = data as? [Any], metadata.descriptor == KnownMetadata.array {
                let elementType = metadata.genericMetadata.first!
                let mapped = try array.map { try self.decode(type: elementType, from: $0) }
                return try metadata.dynamicCast(from: mapped)
            }
            
            // Case: decoding a Date or Data
            if metadata.isDateOrData {
                if metadata.descriptor == KnownMetadata.date {
                    return try self.decodeDate(from: data, strategy: _dateDecoding)
                } else {
                    return try self.decodeData(from: data, strategy: _dataDecoding)
                }
            }
            
            // Case: decoding another special-cased struct, i.e. URL
            if let transformer = Jsum.specialCaseStructs[metadata.descriptor.ptr] {
                return try transformer.transform(forward: data)
            }
            
            // Case: decoding a JSONCodable from another JSONCodable without a transformer
            if let convertedValue = try metadata.attemptJSONCodableConversion(value: data) {
                return convertedValue
            }
            
            throw Error.couldNotDecode("Cannot decode classes and most structs without a dictionary")
        }
        
        // Case: decoding a dictionary
        // TODO: Allow decoding from more complex dictionary types
        if metadata.descriptor == KnownMetadata.dictionary {
            let elementType = metadata.genericMetadata[1]
            let mapped = try json.mapValues { try self.decode(type: elementType, from: $0) }
            return try metadata.dynamicCast(from: mapped)
        }
        
        let decodedProps = try self.decode(properties: json, forType: metadata)
        return metadata.createInstance(props: decodedProps)
    }
    
    // MARK: Specialized decoding
    
    private func decodeBuiltinStruct(_ metadata: StructMetadata, from json: Any) throws -> Any {
        assert(metadata.isBuiltin)
        
        // Types are identical: return the value itself
        if type(of: json) == metadata.type {
            return json
        } else {
            guard let nsnumber = json as AnyObject as? NSNumber else {
                // We are trying to decode a number from something other than a number;
                // There is no transformer for whatever we're decoding, so try to
                // implicitly convert it if both types conform to JSONCodable
                if let convertedValue = try metadata.attemptJSONCodableConversion(value: json) {
                    return convertedValue
                }
                
                throw Error.couldNotDecode(
                    "Cannot convert non-JSONCodable type '\(metadata.type)' to a number"
                )
            }
            
            return Self.convert(number: nsnumber, to: metadata.type)
        }
    }
    
    private func decodeDate(from json: Any, strategy: DateDecodingStrategy) throws -> Any {
        switch strategy {
            case .bestGuess:
                if let stringyDate = json as? String {
                    return try self.decodeDate(from: stringyDate, strategy: .iso8601)
                }
                if let number = json as? NSNumber {
                    return try self.decodeDate(from: number, strategy: .secondsSince1970)
                }
                
                throw Error.couldNotDecode("Tried decoding Date but neither string nor number found")
                
            case .secondsSince1970:
                guard let number = json as? NSNumber else {
                    throw Error.couldNotDecode("Cannot decode non-number as UNIX timestamp Date")
                }
                
                return Date(timeIntervalSince1970: number.doubleValue)

            case .millisecondsSince1970:
                guard let number = json as? NSNumber else {
                    throw Error.couldNotDecode("Cannot decode non-number as UNIX timestamp Date")
                }
                
                return Date(timeIntervalSince1970: number.doubleValue / 1000.0)

            case .iso8601:
                if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
                    guard let stringyDate = json as? String else {
                        throw Error.couldNotDecode("DateDecodingStrategy.iso8601 requires a string")
                    }
                    guard let date = self._iso8601Formatter.date(from: stringyDate) else {
                        throw Error.couldNotDecode("Expected date string to be ISO8601-formatted")
                    }

                    return date
                }
                else {
                    fatalError("ISO8601DateFormatter is unavailable on this platform")
                }

            case .formatter(let formatter):
                guard let stringyDate = json as? String else {
                    throw Error.couldNotDecode("DateDecodingStrategy.formatter requires a string")
                }
                guard let date = formatter.date(from: stringyDate) else {
                    throw Error.couldNotDecode("Date string does not match expected format")
                }
                
                return date

            case .custom(let closure):
                return try closure(json)
        }
    }
    
    private func decodeData(from json: Any, strategy: DataDecodingStrategy) throws -> Any {
        switch strategy {
            case .base64:
                guard let base64EncodedData = json as? String else {
                    throw Error.couldNotDecode("DataDecodingStrategy.base64 expects a string")
                }
                guard let data = Data(base64Encoded: base64EncodedData) else {
                    throw Error.couldNotDecode("String was expected to be base 64 encoded")
                }
                
                return data
                
            case .custom(let closure):
                return try closure(json)
        }
    }
    
    // MARK: Tuple decoding
    
    private func decodeTuple(_ tupleMetadata: TupleMetadata, from json: Any) throws -> Any {
        // Allocate space for the tuple
        var box = AnyExistentialContainer(metadata: tupleMetadata)
        let boxBuffer = box.getValueBuffer()
        
        // Populate the tuple from an array or dictionary and return a copy of it
        if let array = json as? [Any] {
            try self.populate(tuple: boxBuffer, from: array, tupleMetadata)
            return box.toAny
        }
        if let dictionary = json as? [String: Any] {
            try self.populate(tuple: boxBuffer, from: dictionary, tupleMetadata)
            return box.toAny
        }
        
        // TODO: support converting structs / classes to tuples
        
        // Error: we were not given an array or dictionary
        throw Error.decodingNotSupported("Tuples can only be decoded from arrays or dictionaries")
    }
    
    private func populate(tuple: RawPointer, from array: [Any], _ metadata: TupleMetadata) throws {
        guard array.count == metadata.elements.count else {
            throw Error.couldNotDecode("Array size must match number of elements in tuple type")
        }
        
        // Copy each element of the array to each tuple element at the specified offset
        for (e,value) in zip(metadata.elements, array) {
            let newValue = try self.decode(type: e.metadata, from: value)
            try self.populate(element: e, ofTuple: tuple, with: newValue)
        }
    }
    
    private func populate(tuple: RawPointer, from dict: [String: Any], _ metadata: TupleMetadata) throws {
        // Copy each value of the dictionary to each tuple element with the same name at the specified offset
        for (e,name) in zip(metadata.elements, metadata.labels) {
            guard let value = dict[name] else {
                throw Error.couldNotDecode("Missing tuple label '\(name)' in payload")
            }
            
            let newValue = try self.decode(type: e.metadata, from: value)
            try self.populate(element: e, ofTuple: tuple, with: newValue)
        }
    }
    
    private func populate(element e: TupleMetadata.Element, ofTuple tuple: RawPointer, with value: Any) throws {
        // If the types do not match up, try decoding it again
        if e.type != type(of: value) {
            let decodedValue = try decode(type: e.metadata, from: value)
            var valueBox = container(for: decodedValue)
            tuple.copyMemory(ofTupleElement: valueBox.getValueBuffer(), layout: e)
        } else {
            var valueBox = container(for: value)
            tuple.copyMemory(ofTupleElement: valueBox.getValueBuffer(), layout: e)
        }
    }
}

