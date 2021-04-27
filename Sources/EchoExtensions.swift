//
//  EchoExtensions.swift
//  Jsum
//
//  Created by Tanner Bennett on 4/12/21.
//  Copyright © 2021 Tanner Bennett. All rights reserved.
//

import Foundation
import Echo
import CEcho

typealias RawType = UnsafeRawPointer

/// For some reason, breaking it all out into separate vars like this
/// eliminated a bug where the pointers in the final set were not the
/// same pointers that would appear if you manually reflected a type
extension KnownMetadata.Builtin {
    static var jsumSupported: Set<RawType> = Set(_typePtrs)
    
    private static var _types: [Any.Type] {
        return [
            Int8.self, Int16.self, Int32.self, Int64.self, Int.self,
            UInt8.self, UInt16.self, UInt32.self, UInt64.self, UInt.self,
            Float32.self, Float64.self, Float80.self, Float.self, Double.self
        ]
    }
    
    private static var _typePtrs: [RawType] {
        return self._types.map({ type in
            let metadata = reflect(type)
            return metadata.ptr
        })
    }
}

extension Metadata {
    /// This doesn't actually work very well since Double etc aren't opaque,
    /// but instead contain a single member that is itself opaque
    var isBuiltin_alt: Bool {
        return self is OpaqueMetadata
    }
    
    var isBuiltin: Bool {
        guard self.vwt.flags.isPOD else {
            return false
        }
        
        return KnownMetadata.Builtin.jsumSupported.contains(self.ptr)
    }
}

protocol NominalType: TypeMetadata {
    associatedtype NominalTypeDescriptor: TypeContextDescriptor
    var descriptor: NominalTypeDescriptor { get }
    var genericMetadata: [Metadata] { get }
    var fieldOffsets: [Int] { get }
}

extension ClassMetadata: NominalType {
    typealias NominalTypeDescriptor = ClassDescriptor
}
extension StructMetadata: NominalType {    
    typealias NominalTypeDescriptor = StructDescriptor
}
extension EnumMetadata: NominalType {
    typealias NominalTypeDescriptor = EnumDescriptor
}

extension NominalType {
    private func recordIndex(forKey key: String) -> Int? {
        return self.descriptor.fields.records.firstIndex { $0.name == key }
    }
    
    var fields: [(name: String, type: Metadata)] {
        let r: [FieldRecord] = self.descriptor.fields.records
        return r.filter(\.hasMangledTypeName).map {
            return (
                $0.name,
                reflect(self.type(of: $0.mangledTypeName)!)
            )
        }
    }
    
    func getValue<T, O>(forKey key: String, from object: O) -> T {
        let recordIdx = self.recordIndex(forKey: key)!
        let offset = self.fieldOffsets[recordIdx]
        let ptr = object~
        return ptr[offset]
    }
    
    func set<T, O>(value: T, forKey key: String, on object: inout O) {
        let recordIdx = self.recordIndex(forKey: key)!
        let offset = self.fieldOffsets[recordIdx]
        var ptr = object~
        ptr[offset] = value
    }
}

extension NominalType {
    func conforms(to _protocol: Any) -> Bool {
        let existential = reflect(_protocol) as! MetatypeMetadata
        let instance = existential.instanceMetadata as! ExistentialMetadata
        let desc = instance.protocols.first!
        
        return !conformances.filter({ $0.protocol == desc }).isEmpty
    }
}

extension ClassMetadata {
    func createInstance<T: AnyObject>(props: [String: Any] = [:]) -> T {
        var obj = swift_allocObject(
            for: self,
            size: self.classSize,
            alignment: self.instanceAlignmentMask
        )
        
        for (key, value) in props {
            self.set(value: value, forKey: key, on: &obj)
        }
        
        return unsafeBitCast(obj, to: T.self)
    }
}
