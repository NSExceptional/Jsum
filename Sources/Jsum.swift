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

public struct Jsum {
    public enum Error: Swift.Error {
        case couldNotDecode(String)
        case decodingNotSupported(String)
        case notYetImplemented
        case other(Swift.Error)
    }
    
    public static func tryDecode<T>(from json: Any) -> Result<T, Jsum.Error> {
        return Self().tryDecode(from: json)
    }
    
    public static func decode<T>(from json: Any) throws -> T {
        return try Self().decode(from: json)
    }
    
    public func tryDecode<T>(from json: Any) -> Result<T, Jsum.Error> {
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
    
    // MARK: Built-in decoding
    
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

