//
//  EchoExtensions.swift
//  Jsum
//
//  Created by Tanner Bennett on 4/12/21.
//  Copyright © 2021 Tanner Bennett. All rights reserved.
//

import Foundation
import Echo

extension Metadata {
    var isBuiltin: Bool { self.vwt.flags.isPOD }
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
