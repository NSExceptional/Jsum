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
        /// A generic error was encountered during decoding.
        case couldNotDecode(String)
        /// Null was decoded for a non-optional field with `failOnNullNonOptionals` enabled.
        /// An attempt to find a default value is made before this error is used.
        case nullFoundOnNonOptional
        /// Null was decoded for a non-optional field and no default value could be found.
        /// This means that the parent type did not supply a default value for this key,
        /// and the type being decoded does not conform to `JSONCodable`.
        case nullFoundWithNoDefaultValue
        /// A key was missing from the payload with `failOnMissingKeys` enabled.
        /// With `failOnMissingKeys` enabled, this error is thrown regardless of the
        /// nullability of the type being decoded; it expects a value or `null`.
        case missingKey
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
    
    public init() {
        // Enable fractional seconds, which is the default for
        // JavaScript's Date.toJSON()
        self._iso8601Formatter.formatOptions = [
            self._iso8601Formatter.formatOptions,
            .withFractionalSeconds
        ]
    }
    
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
    /// JSON payload at all for a given property. If the key is just null,
    /// decoding will not fail. To fail on null, call `failOnNullNonOptionals()`.
    /// 
    /// By default, Jsum will attempt to synthesize a default value if the
    /// property conforms to `JSONCodable`, and _then_ fail if it doesn't.
    /// Setting this flag will cause Jsum to skip that step.
    /// Additionally, default values are ignored if this flag is set.
    /// Transformers are never invoked for missing keys.
    /// 
    /// - Note: The default behavior is the _opposite_ of the default
    /// parameter passed to this builder-function.
    public func failOnMissingKeys(_ flag: Bool = true) -> Self {
        self._failOnMissingKeys = flag
        return self
    }
    
    /// Set whether decoding should fail when null is decoded for a property
    /// with a non-optional type, iff no default value is supplied by the
    /// enclosing type. If the key is missing entirely, decoding will not fail.
    /// To fail on a missing key, call `failOnMissingKeys()`.
    /// 
    /// By default, Jsum will attempt to synthesize a default value if the
    /// property conforms to `JSONCodable`, and _then_ fail if it doesn't.
    /// Setting this flag will cause Jsum to skip that step.
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
    
    /// Decode the 
    public static func synthesize<T>(_: T.Type = T.self) throws -> T {
        let metadata = reflect(T.self)
        return try self.synthesize(type: metadata, asJSON: false) as! T
    }
    
    public static func synthesizeJSON(_ type: Any.Type) throws -> Any {
        let metadata = reflect(type)
        return try self.synthesize(type: metadata, asJSON: true)
    }
    
    // MARK: Private: decoding
    
    private func decode(type metadata: Metadata, from json: Any) throws -> Any {
        // Case: NSNull and not optional
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
                    return try Self.decodeBuiltinStruct(structure, from: json)
                } else {
                    return try self.decodeStruct(structure, from: json)
                }
            case .class:
                return try self.decodeClass(metadata as! ClassMetadata, from: json)
            case .enum:
                // Currently, we cannot initialize enums with raw values
                // by hand, so we have to call the decode method. In the
                // future, we will cast to RawRepresentable and call then
                // `init(rawValue:)` with `.defaultJSON.unwrapped` that way
                guard let codable = metadata.type as? JSONCodable.Type else {
                    throw Error.notYetImplemented
                }
                guard let jsonCodableValue = json as? JSONCodable else {
                    throw Error.notYetImplemented
                }
                
                return try codable.decode(from: jsonCodableValue.toJSON)
            case .optional:
                let optional = metadata as! EnumMetadata
                if json is NSNull {
                    let none = AnyExistentialContainer(nil: optional)
                    return none.toAny
                } else {
                    // let wrapped = optional.genericMetadata.first!
                    let value = try self.decode(type: optional.genericMetadata.first!, from: json)
                    if let emptiable = value as? Emptyable {
                    // if let codable = wrapped as? JSONCodable.Type, !codable.synthesizesDefaultJSON {
                        // TODO: runtime equatable check once existentials are unlocked
                        // For now, explicitly check for String, Int, and Array
                        if emptiable.isEmpty {
                            let none = AnyExistentialContainer(nil: optional)
                            return none.toAny
                        }
                    }
                    
                    return value
                }
            case .tuple:
                return try self.decodeTuple(metadata as! TupleMetadata, from: json)
            default:
                throw Error.decodingNotSupported(
                    "Cannot decode kind \(metadata.kind) (\(metadata.type)"
                )
        }
    }
    
    private static func synthesize(type metadata: Metadata, asJSON: Bool = false) throws -> Any {
        if let value = self.defaultJSONValue(for: metadata, synthesize: false) {
            return asJSON ? value : value.unwrapped
        }
        
        switch metadata.kind {
            case .struct:
                let structure = metadata as! StructMetadata
                if structure.isBuiltin {
                    assert(!asJSON) // Built-ins should all have a defaultJSON
                    return try self.decodeBuiltinStruct(structure, from: 0)
                } else {
                    let properties = try structure.fields.reduce(into: [String: Any]()) { (props, field) in
                        props[field.name] = try self.synthesize(type: field.type, asJSON: asJSON)
                    }
                    if asJSON {
                        return JSON.object(properties as! [String: JSON])
                    } else {
                        return structure.createInstance(props: properties)
                    }
                }
            case .class:
                let cls = metadata as! ClassMetadata
                let properties = try cls.fields.reduce(into: [String: Any]()) { (props, field) in
                    props[field.name] = try self.synthesize(type: field.type, asJSON: asJSON)
                }
                if asJSON {
                    return JSON.object(properties as! [String: JSON])
                } else {
                    return cls.createInstance(props: properties) as AnyObject
                }
            case .enum: fallthrough
            case .optional:
                // Currently, we cannot synthesize enums with raw values
                // by hand, so we have to call the decode method. In the
                // future, we will cast to RawRepresentable and call then
                // `init(rawValue:)` with `.defaultJSON.unwrapped` that way
                guard let codable = metadata.type as? JSONCodable.Type else {
                    throw Error.notYetImplemented
                }
                
                if asJSON {
                    return codable.defaultJSON
                } else {
                    return try codable.decode(from: codable.defaultJSON)
                }
            case .tuple:
                let tuple = metadata as! TupleMetadata
                return tuple.createInstance(elements: try tuple.elements.map {
                    try self.synthesize(type: $0.metadata, asJSON: asJSON)
                })
            default:
                throw Error.decodingNotSupported(
                    "Cannot decode kind \(metadata.kind) (\(metadata.type))"
                )
        }
    }
    
    /// Returns an error if null is encountered with `failOnNullNonOptionals` enabled,
    /// or if null is encountered and no default value can be generated at all.
    /// Or, if the type is optional, the value is returned whether or not it is null.
    private func unboxField(_ value: Any, type metadata: Metadata) -> Result<Any,Error> {
        if value is NSNull && metadata.kind != .optional {
            // Null found, user wants error thrown
            if self._failOnNullNonOptionals {
                return .failure(.nullFoundOnNonOptional)
            }
            // If the type we're given is JSONCodable, use the type's default value
            else if let codable = metadata.type as? JSONCodable.Type {
                // Results in fatalError if the type doesn't override `defaultJSON`
                return .success(codable.defaultJSON.unwrapped)
            }
            // It is not JSONCodable so there is no default value; throw an error
            else {
                return .failure(.nullFoundWithNoDefaultValue)
            }
        } else {
            // Value may be NSNull here, but if it is, the field type is optional
            return .success(value)
        }
    }
    
    /// Note that these will need to be decoded before assignment
    private static func defaultJSONValue(for type: Metadata, synthesize: Bool = true) -> JSON? {
        if let codable = type.type as? JSONCodable.Type {
            // Only unwrap if we aren't opting-out of synthesizing or
            // if the type does not synthesize the default JSON
            if synthesize || !codable.synthesizesDefaultJSON {
                return codable.defaultJSON
            }
        }
        
        return nil
    }
    
    private func decode<M: NominalType>(properties: [String: Any], forType metadata: M) throws -> [String: Any] {
        let (transformers, jsonMap, defaults) = metadata.jsonCodableInfoByProperty
        var decodedProps: [String: Any] = [:]
        
        /// This cannot be moved because it relies on local variable captures
        /// 
        /// Throws on invalid JSON key path (i.e. key path goes to a non-object
        /// somewhere before the end). The behavior for a missing key is
        /// defined by _failOnMissingKeys. If true, it will throw an error.
        func valueForProperty(_ propertyKey: String, _ type: Metadata) throws -> Any? {
            // Did the user specify a new key path for this property?
            if let jsonKeyPathForProperty = jsonMap[propertyKey] {
                if let optionalValue = try properties.jsum_value(for: jsonKeyPathForProperty) {
                    let unboxResult = unboxField(optionalValue, type: type)
                    
                    // Null found and property is non-optional, user wants error thrown
                    if case .failure(let unboxError) = unboxResult {
                        // Did we encounter null with `failOnNullNonOptionals` enabled?
                        if case .nullFoundOnNonOptional = unboxError {
                            // Yes, check if a default value was supplied
                            if defaults[propertyKey] != nil {
                                // Return nil to use default value later on
                                return nil
                            }
                        }
                        
                        // No, we encountered null after c
                        // TODO defaults?
                        throw unboxError
                    }
                    
                    // Value found; coerce NSNull to nil
                    return optionalValue is NSNull ? nil : optionalValue
                } else if self._failOnMissingKeys {
                    // Value not found, user wants error thrown
                    throw Error.missingKey
                } else {
                    // Value not found, user wants decoding to continue;
                    // if no default value is ever supplied, .missingKey
                    // will be thrown later on
                    return nil
                }
            }
            
            // User did not override the key path for this property
            let value = try? properties.jsum_value(for: propertyKey)
            if value == nil {
                if self._failOnMissingKeys {
                    // Value not found, user wants error thrown
                    throw Error.missingKey
                }
                // Value not found, user wants decoding to continue
                return nil
            }
            
            // Null found and property is non-optional, user wants error thrown
            if value is NSNull && self._failOnNullNonOptionals && type.kind != .optional {
                throw Error.nullFoundOnNonOptional
            }
            
            // value is not nil here; coerce NSNull to nil
            return value! is NSNull ? nil : value
        }
        
        for (key, type) in metadata.fields {
            // Throws on missing keys if _failOnMissingKeys = true.
            // Throws on null keys if _failOnNullNonOptionals = true.
            if var value = try valueForProperty(key, type) {
                assert(!(value is NSNull))
                
                // Transform value first, if desired
                if let transform = transformers[key] {
                    value = try transform.transform(forward: value)
                }
                
                // Perform decoding; if the transformed value already
                // matches the desired type, this should be a no-op
                decodedProps[key] = try self.decode(type: type, from: value)
            } else {
                // Check if a default value was supplied
                if let defaultValue = defaults[key] {
                    decodedProps[key] = defaultValue
                }
                // If the type we're given is JSONCodable, use the type's default value
                // TODO: should we just try to synthesize it instead?
                else if let defaultValue = Self.defaultJSONValue(for: type)?.unwrapped {
                    // Decode the default value to the expected type
                    decodedProps[key] = try self.decode(type: type, from: defaultValue)
                }
                // User didn't opt-into missing key errors early on, so we expected
                // them to supply a default value or use a JSONCodable type with
                // `defaultJSON` implemented, and we got neither, so here we are
                else {
                    throw Error.missingKey
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
            
            // Case: decoding a string/bool/number from an foundation type
            if let cast = try? metadata.dynamicCast(from: data) {
                return cast
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
    
    private static func decodeBuiltinStruct(_ metadata: StructMetadata, from json: Any) throws -> Any {
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
            
            return self.convert(number: nsnumber, to: metadata.type)
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
        for (e, value) in zip(metadata.elements, array) {
            try self.populate(element: e, ofTuple: tuple, with: value)
        }
    }
    
    private func populate(tuple: RawPointer, from dict: [String: Any], _ metadata: TupleMetadata) throws {
        // Copy each value of the dictionary to each tuple element with the same name at the specified offset
        for (e,name) in zip(metadata.elements, metadata.labels) {
            guard let value = dict[name] else {
                throw Error.couldNotDecode("Missing tuple label '\(name)' in payload")
            }
            
            try self.populate(element: e, ofTuple: tuple, with: value)
        }
    }
    
    private func populate(element e: TupleMetadata.Element, ofTuple tuple: RawPointer, with value: Any) throws {
        // Assert types match and perform nullability checks before decoding
        let unboxedValue = try self.unboxField(value, type: e.metadata).get()
        let decodedValue = try self.decode(type: e.metadata, from: unboxedValue)
        
        var valueBox = container(for: decodedValue)
        tuple.copyMemory(ofTupleElement: valueBox.getValueBuffer(), layout: e)
    }
}

