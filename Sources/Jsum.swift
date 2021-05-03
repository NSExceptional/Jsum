//
//  Jsum.swift
//  Jsum
//
//  Created by Tanner Bennett on 4/16/21.
//  Copyright © 2021 Tanner Bennett. All rights reserved.
//

import Foundation
import Echo

public enum Jsum {
    public enum Error: Swift.Error {
        case couldNotDecode(String)
        case decodingNotSupported(String)
        case notYetImplemented
        case other(Swift.Error)
    }
    
    static func tryDecode<T>(from json: Any) -> Result<T, Jsum.Error> {
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

    static func decode<T>(from json: Any) throws -> T {
        let metadata = reflect(T.self)
        let box = try self.decode(type: metadata, from: json)
        return box as! T
    }
    
    private static func decode(type metadata: Metadata, from json: Any) throws -> Any {
        // Case: NSNull and not optional
        if json is NSNull && metadata.kind != .optional {
            throw Error.couldNotDecode(
                "Type '\(metadata.type)' cannot be converted from null"
            )
        }
        
        // Case: Strings, arrays of exact type, etc...
        guard metadata.type != type(of: json) else {
            // TODO: will this inadvertently execute for Array
            // when the generic parameters don't match up?
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
    
    private static func decode<M: NominalType>(properties: [String: Any], forType metadata: M) throws -> [String: Any] {
        let (transformers, jsonMap) = metadata.jsonCodableInfoByProperty
        var decodedProps: [String: Any] = [:]
        
        // TODO decode super props
        for (key, type) in metadata.fields {
            let jsonKeyPathForProperty = jsonMap[key] ?? key
            // TODO: propogate thrown errors
            if var value = try? properties.value(for: jsonKeyPathForProperty) {
                // Transform value fisrt, if desired
                if let transform = transformers[key] {
                    // Pass NSNull as nil to transformers
                    value = try transform.transform(forward: value is NSNull ? nil : value)
                }
                
                // Decode the value into a buffer, copy the buffer into
                // a new AnyExistentialContainer and return it as Any
                decodedProps[key] = try self.decode(type: type, from: value)
            } else {
                // If the type we're given is JSONCodable, use the type's default value
                if let type = type as? TypeMetadata, type.conforms(to: JSONCodable.self) {
                    let codable = type.type as! JSONCodable.Type
                    decodedProps[key] = codable.defaultJSON.unwrapped
                } else {
                    throw Error.couldNotDecode(
                        "Missing key '\(key)' with no default value for type '\(type.type)'"
                    )
                }
            }
        }
        
        return decodedProps
    }
    
    // MARK: Class decoding
    
    private static func decodeClass(_ metadata: ClassMetadata, from json: Any) throws -> AnyObject {
        guard let json = json as? [String: Any] else {
            throw Error.couldNotDecode("Cannot decode classes and most structs without a dictionary")
        }
        
        let decodedProps = try self.decode(properties: json, forType: metadata)
        return metadata.createInstance(props: decodedProps)
    }
    
    // MARK: Struct decoding
    
    private static func decodeStruct(_ metadata: StructMetadata, from json: Any) throws -> Any {
        assert(!metadata.isBuiltin)
        
        guard let json = json as? [String: Any] else {
            throw Error.couldNotDecode("Cannot decode classes and most structs without a dictionary")
        }
        
        let decodedProps = try self.decode(properties: json, forType: metadata)
        return metadata.createInstance(props: decodedProps)
    }
    
    // MARK: Built-in decoding
    
    private static func decodeBuiltinStruct(_ metadata: StructMetadata, from json: Any) throws -> Any {
        assert(metadata.isBuiltin)
        
        // Types are identical: return the value itself
        if type(of: json) == metadata.type {
            return json
        } else {
            let nsnumber = json as AnyObject as! NSNumber
            return self.convert(number: nsnumber, to: metadata.type)
        }
    }
    
    // MARK: Tuple decoding
    
    private static func decodeTuple(_ tupleMetadata: TupleMetadata, from json: Any) throws -> Any {
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
    
    private static func populate(tuple: RawPointer, from array: [Any], _ metadata: TupleMetadata) throws {
        guard array.count == metadata.elements.count else {
            throw Error.couldNotDecode("Array size must match number of elements in tuple type")
        }
        
        // Copy each element of the array to each tuple element at the specified offset
        for (e,value) in zip(metadata.elements, array) {
            let newValue = try self.decode(type: e.metadata, from: value)
            try self.populate(element: e, ofTuple: tuple, with: newValue)
        }
    }
    
    private static func populate(tuple: RawPointer, from dict: [String: Any], _ metadata: TupleMetadata) throws {
        // Copy each value of the dictionary to each tuple element with the same name at the specified offset
        for (e,name) in zip(metadata.elements, metadata.labels) {
            guard let value = dict[name] else {
                throw Error.couldNotDecode("Missing tuple label '\(name)' in payload")
            }
            
            let newValue = try self.decode(type: e.metadata, from: value)
            try self.populate(element: e, ofTuple: tuple, with: newValue)
        }
    }
    
    private static func populate(element e: TupleMetadata.Element, ofTuple tuple: RawPointer, with value: Any) throws {
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

