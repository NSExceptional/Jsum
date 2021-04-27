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
        switch metadata.kind {
//            case .class:
//                <#code#>
            case .struct:
                return try self.decodeStruct(metadata as! StructMetadata, from: json)
//            case .enum:
//                <#code#>
//            case .optional:
//                return nil
            case .tuple:
                return try self.decodeTuple(metadata as! TupleMetadata, from: json)
            default: throw Error.decodingNotSupported("Only tuples can be decoded as of now")
        }
    }
    
    private static func decodeFieldedType(_ type: TypeMetadata, from json: Any) throws -> RawPointer {
        throw Error.notYetImplemented
    }
    
    private static func decodeClass(_ metadata: ClassMetadata, from json: Any) throws -> RawPointer {
        throw Error.notYetImplemented
    }
    
    private static func decodeStruct(_ metadata: StructMetadata, from json: Any) throws -> RawPointer {
        if (metadata.isBuiltin) {
            // Types are identical: return the value itself
            if type(of: json) == metadata.type {
                return RawPointer(wrapping: json, withType: metadata)
            }
        }
        
        throw Error.notYetImplemented
    }
    
    private static func decodeTuple(_ tupleMetadata: TupleMetadata, from json: Any) throws -> RawPointer {
        // Allocate space for the tuple
        let boxBuffer = RawPointer.allocateBuffer(for: tupleMetadata)
        
        // Populate the tuple from an array or dictionary and return a copy of it
        if let array = json as? [JSONCodable] {
            return try self.populate(tuple: boxBuffer, from: array, tupleMetadata)
        }
        if let dictionary = json as? [String: Any] {
            return try self.populate(tuple: boxBuffer, from: dictionary, tupleMetadata)
        }
        
        // Error: we were not given an array or dictionary
        throw Error.decodingNotSupported("Tuples can only be decoded from arrays or dictionaries")
    }
    
    private static func populate(tuple: RawPointer, from array: [JSONCodable], _ metadata: TupleMetadata) throws -> RawPointer {
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
            tuple.storeBytes(ofTupleElement: UnsafeRawPointer(valueBuffer), layout: e)
        } else {
            var valueBox = container(for: value)
            tuple.storeBytes(ofTupleElement: valueBox.projectValue(), layout: e)
        }
    }
}

