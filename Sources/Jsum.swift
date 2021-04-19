//
//  Jsum.swift
//  Jsum
//
//  Created by Tanner Bennett on 4/16/21.
//  Copyright © 2021 Tanner Bennett. All rights reserved.
//

import Echo

private typealias RawPointer = UnsafeMutableRawPointer

extension RawPointer {
    static func allocateBuffer(for type: Metadata) -> Self {
        return RawPointer.allocate(
            byteCount: type.vwt.size,
            alignment: type.vwt.flags.alignment
        )
    }
    
    func storeBytes(ofTupleElement valuePtr: UnsafeRawPointer, layout e: TupleMetadata.Element) {
        (self + e.offset).copyMemory(from: valuePtr, byteCount: e.metadata.vwt.size)
    }
}

public enum Jsum {
    public enum Error: Swift.Error {
        case couldNotDecode(String)
        case decodingNotSupported(String)
        case notYetImplemented
    }
    
    static func reflectAllPropsToJSON<T>(_ t: T) -> [String: JSONCodable] {
        return ["fake": "object"]
    }

    static func decode<T>(from json: [String: JSONCodable]) throws -> T {
        let metadata = reflect(T.self)
        switch metadata.kind {
//            case .class:
//                <#code#>
//            case .struct:
//                <#code#>
//            case .enum:
//                <#code#>
//            case .optional:
//                return nil
            case .tuple:
                return try self.decodeTuple(metadata as! TupleMetadata, from: json)
            default: throw Error.decodingNotSupported("Only tuples can be decoded as of now")
        }
    }
    
    private static func decodeFieldedType<T>(_ type: TypeMetadata, from json: [String: JSONCodable]) throws -> T {
        throw Error.decodingNotSupported
    }
    
    private static func decodeTuple<T>(_ tuple: TupleMetadata, from json: [String: JSONCodable]) throws -> T {
        let boxBuffer = UnsafeMutableRawPointer(mutating: UnsafeMutablePointer<T>.allocate(capacity: 1))
        
        for (e,name) in zip(tuple.elements, tuple.labels) {
            guard let value: Any = json[name] else {
                throw Error.couldNotDecode("Missing tuple label '\(name)' in payload")
            }
            
            var valueBox = container(for: value)
            (boxBuffer + e.offset).copyMemory(from: valueBox.projectValue(), byteCount: e.metadata.vwt.size)
        }
        
        return boxBuffer.assumingMemoryBound(to: T.self).pointee
    }
}

