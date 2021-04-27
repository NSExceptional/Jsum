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
    }
    
    static func reflectAllPropsToJSON<T>(_ t: T) -> [String: Any] {
        return ["fake": "object"]
    }

    static func decode<T>(from json: Any) throws -> T {
        let metadata = reflect(T.self)
        let buffer = try self.decode(type: metadata, from: json)
        defer { buffer.deallocate() }
        return buffer.load(as: T.self)
    }
    
    private static func decode(type metadata: Metadata, from json: Any) throws -> RawPointer {
        // Case: Strings, arrays of exact type, etc...
        guard metadata.type != reflect(json).type else {
            // TODO: will this inadvertently execute for Array
            // when the generic parameters don't match up?
            return RawPointer(wrapping: json, withType: metadata)
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
//            case .enum:
//                <#code#>
//            case .optional:
//                return nil
            case .tuple:
                return try self.decodeTuple(metadata as! TupleMetadata, from: json)
            default: throw Error.decodingNotSupported("Only tuples can be decoded as of now")
        }
    }
    
    private static func decode<M: NominalType>(properties: [String: Any], forType metadata: M) throws -> [String: Any] {
        var props = properties
        for (key, type) in metadata.fields {
            if let value = props[key] {
                // Decode the value into a buffer, copy the buffer into
                // a new AnyExistentialContainer and return it as Any
                let newValue = try self.decode(type: type, from: value)
                var box = AnyExistentialContainer(metadata: type)
                box.store(value: newValue)
                props[key] = box.toAny
            } else {
                // If the type we're given is JSONCodable, use the type's default value
                if let type = type as? TypeMetadata, type.conforms(to: JSONCodable.self) {
                    // TODO: if optional, check if the optional's Wrapped type provides
                    // a default value and use that instead.
                    let codable = type as! JSONCodable.Type
                    props[key] = codable.defaultJSON.unwrapped
                } else {
                    throw Error.couldNotDecode(
                        "Missing key '\(key)' with no default value for type '\(type.type)'"
                    )
                }
            }
        }
        
        return props
    }
    
    // MARK: Class decoding
    
    private static func decodeClass(_ metadata: ClassMetadata, from json: Any) throws -> RawPointer {
        guard let json = json as? [String: Any] else {
            throw Error.couldNotDecode("Cannot decode classes and most structs without a dictionary")
        }
        
        let decodedProps = try self.decode(properties: json, forType: metadata)
        let obj: AnyObject = metadata.createInstance(props: decodedProps)
        return RawPointer(wrapping: Unmanaged.retainIfObject(obj), withType: metadata)
    }
    
    // MARK: Struct decoding
    
    private static func decodeStruct(_ metadata: StructMetadata, from json: Any) throws -> RawPointer {
        assert(!metadata.isBuiltin)
        
        guard let json = json as? [String: Any] else {
            throw Error.couldNotDecode("Cannot decode classes and most structs without a dictionary")
        }
        
        let decodedProps = try self.decode(properties: json, forType: metadata)
        
        let buffer = RawPointer.allocateBuffer(for: metadata)
        for (key, value) in decodedProps {
            // Retain object values as needed since they are not
            // retained when stored via this method and passed as Any
            Unmanaged.retainIfObject(value)
            metadata.set(value: value, forKey: key, pointer: buffer)
        }
        
        return buffer
    }
    
    // MARK: Built-in decoding
    
    private static func decodeBuiltinStruct(_ metadata: StructMetadata, from json: Any) throws -> RawPointer {
        assert(metadata.isBuiltin)
        
        // Types are identical: return the value itself
        if type(of: json) == metadata.type {
            return RawPointer(wrapping: json, withType: metadata)
        } else {
            let nsnumber = json as AnyObject as! NSNumber
            let number: Any = self.convert(number: nsnumber, to: metadata.type)
            return RawPointer(wrapping: number, withType: metadata)
        }
    }
    
    // MARK: Tuple decoding
    
    private static func decodeTuple(_ tupleMetadata: TupleMetadata, from json: Any) throws -> RawPointer {
        // Allocate space for the tuple
        let boxBuffer = RawPointer.allocateBuffer(for: tupleMetadata)
        
        // Populate the tuple from an array or dictionary and return a copy of it
        if let array = json as? [Any] {
            return try self.populate(tuple: boxBuffer, from: array, tupleMetadata)
        }
        if let dictionary = json as? [String: Any] {
            return try self.populate(tuple: boxBuffer, from: dictionary, tupleMetadata)
        }
        
        // TODO: support converting structs / classes to tuples
        
        // Error: we were not given an array or dictionary
        throw Error.decodingNotSupported("Tuples can only be decoded from arrays or dictionaries")
    }
    
    private static func populate(tuple: RawPointer, from array: [Any], _ metadata: TupleMetadata) throws -> RawPointer {
        guard array.count == metadata.elements.count else {
            throw Error.couldNotDecode("Array size must match number of elements in tuple type")
        }
        
        // Copy each element of the array to each tuple element at the specified offset
        for (e,value) in zip(metadata.elements, array) {
            try self.populate(element: e, ofTuple: tuple, with: value)
        }
        
        return tuple
    }
    
    private static func populate(tuple: RawPointer, from dict: [String: Any], _ metadata: TupleMetadata) throws -> RawPointer {
        // Copy each value of the dictionary to each tuple element with the same name at the specified offset
        for (e,name) in zip(metadata.elements, metadata.labels) {
            guard let value = dict[name] else {
                throw Error.couldNotDecode("Missing tuple label '\(name)' in payload")
            }
            
            try self.populate(element: e, ofTuple: tuple, with: value)
        }
        
        return tuple
    }
    
    private static func populate(element e: TupleMetadata.Element, ofTuple tuple: RawPointer, with value: Any) throws {
        // If the types do not match up, try decoding it again
        if e.type != type(of: value) {
            let valueBuffer = try decode(type: e.metadata, from: value)
            defer { valueBuffer.deallocate() }
            tuple.copyMemory(ofTupleElement: UnsafeRawPointer(valueBuffer), layout: e)
        } else {
            var valueBox = container(for: value)
            tuple.copyMemory(ofTupleElement: valueBox.projectValue(), layout: e)
        }
    }
}

