//
//  EchoExtensions.swift
//  Jsum
//
//  Created by Tanner Bennett on 4/12/21.
//  Copyright © 2021 Tanner Bennett. All rights reserved.
//

import Foundation
@_implementationOnly import Echo

typealias RawType = UnsafeRawPointer
typealias Field = (name: String, type: Metadata)

/// For some reason, breaking it all out into separate vars like this
/// eliminated a bug where the pointers in the final set were not the
/// same pointers that would appear if you manually reflected a type
extension KnownMetadata.Builtin {
    static var jsumSupported: Set<RawType> = Set(_typePtrs)
    
    private static var _types: [Any.Type] {
        return [
            Int8.self, Int16.self, Int32.self, Int64.self, Int.self,
            UInt8.self, UInt16.self, UInt32.self, UInt64.self, UInt.self,
            Float32.self, Float64.self, Float.self, Double.self
        ]
    }
    
    private static var _typePtrs: [RawType] {
        return self._types.map({ type in
            let metadata = reflect(type)
            return metadata.ptr
        })
    }
}

extension KnownMetadata {
    static var array: StructDescriptor = reflectStruct([Any].self)!.descriptor
    static var dictionary: StructDescriptor = reflectStruct([String:Any].self)!.descriptor
    static var date: StructDescriptor = reflectStruct(Date.self)!.descriptor
    static var data: StructDescriptor = reflectStruct(Data.self)!.descriptor
    static var url: StructDescriptor = reflectStruct(URL.self)!.descriptor
}

extension Metadata {
    /// This doesn't actually work very well since Double etc aren't opaque,
    /// but instead contain a single member that is itself opaque
    private var isBuiltin_alt: Bool {
        return self is OpaqueMetadata
    }
    
    var isBuiltin: Bool {
        guard self.vwt.flags.isPOD else {
            return false
        }
        
        return KnownMetadata.Builtin.jsumSupported.contains(self.ptr)
    }
    
    func attemptJSONCodableConversion(value: Any) throws -> Any? {
        if let src = value as? JSONCodable, let destType = self.type as? JSONCodable.Type {
            return try destType.decode(from: src.toJSON)
        }
        
        return nil
    }
    
    func dynamicCast(from variable: Any) throws -> Any {
        func cast<T>(_: T.Type) throws -> T {
            guard let casted = variable as? T else {
                throw Jsum.Error.couldNotDecode("Failed dynamic cast")
            }
            
            return casted
        }
        
        return try _openExistential(self.type, do: cast(_:))
    }
}

extension StructMetadata {
    var isDateOrData: Bool {
        return self.descriptor == KnownMetadata.date ||
            self.descriptor == KnownMetadata.data
    }
}

protocol NominalType: TypeMetadata {
    var genericMetadata: [Metadata] { get }
    var fieldOffsets: [Int] { get }
    var fields: [Field] { get }
}

protocol ContextualNominalType: NominalType {
    associatedtype NominalTypeDescriptor: TypeContextDescriptor
    var nominalDescriptor: NominalTypeDescriptor? { get }
    var name: String { get }
}

extension ContextualNominalType {
    var name: String {
        return self.nominalDescriptor?.name ?? "\(self)"
    }
}

extension ClassMetadata: NominalType, ContextualNominalType {
    var nominalDescriptor: ClassDescriptor? {
        descriptor
    }
}
extension StructMetadata: NominalType, ContextualNominalType {
    var nominalDescriptor: StructDescriptor? {
        descriptor
    }
}
extension EnumMetadata: NominalType, ContextualNominalType {
    var nominalDescriptor: Echo.EnumDescriptor? {
        descriptor
    }
}

// MARK: JSONCodable
extension NominalType {
    var jsonCodableInfoByProperty: JSONCodableInfo {
        if let jsoncodable = self.type as? JSONCodable.Type {
            return (
                jsoncodable.transformersByProperty,
                jsoncodable.jsonKeyPathsByProperty,
                jsoncodable.defaultsByProperty
            )
        }
        
        return ([:], [:], [:])
    }
}

// MARK: KVC
extension ContextualNominalType {
    func recordIndex(forKey key: String) -> Int? {
        return self.nominalDescriptor?.fields.records.firstIndex { $0.name == key }
    }
    
    func fieldOffset(for key: String) -> Int? {
        if let idx = self.recordIndex(forKey: key) {
            return self.fieldOffsets[idx]
        }
        
        return nil
    }
    
    func fieldType(for key: String) -> Metadata? {
        return self.fields.first(where: { $0.name == key })?.type
    }
    
    var _shallowFields: [Field] {
        guard let r: [FieldRecord] = self.nominalDescriptor?.fields.records else {
            return []
        }
        
        return r.filter(\.hasMangledTypeName).map {
            return (
                $0.name,
                reflect(self.type(of: $0.mangledTypeName)!)
            )
        }
    }
}

extension StructMetadata {
    func getValue<T, O>(forKey key: String, from object: O) -> T {
        let offset = self.fieldOffset(for: key)!
        let ptr = object~
        return ptr[offset]
    }
    
    func set<T, O>(value: T, forKey key: String, on object: inout O) {
        self.set(value: value, forKey: key, pointer: object~)
    }
    
    func set(value: Any, forKey key: String, pointer ptr: RawPointer) {
        let offset = self.fieldOffset(for: key)!
        let type = self.fieldType(for: key)!
        ptr.storeBytes(of: value, type: type, offset: offset)
    }
    
    var fields: [Field] { self._shallowFields }
}

extension ClassMetadata {
    func getValue<T, O>(forKey key: String, from object: O) -> T {
        guard let offset = self.fieldOffset(for: key) else {
            if let sup = self.superclassMetadata {
                return sup.getValue(forKey: key, from: object)
            } else {
                fatalError("Class '\(self.name)' has no member '\(key)'")
            }
        }

        let ptr = object~
        return ptr[offset]
    }
    
    func set<T, O>(value: T, forKey key: String, on object: inout O) {
        self.set(value: value, forKey: key, pointer: object~)
    }
    
    func set(value: Any, forKey key: String, pointer ptr: RawPointer) {
        guard let offset = self.fieldOffset(for: key) else {
            if let sup = self.superclassMetadata {
                return sup.set(value: value, forKey: key, pointer: ptr)
            } else {
                fatalError("Class '\(self.name)' has no member '\(key)'")
            }
        }
        
        let type = self.fieldType(for: key)!
        ptr.storeBytes(of: value, type: type, offset: offset)
    }
    
    /// Consolidate all fields in the class hierarchy
    var fields: [Field] {
        if let sup = self.superclassMetadata, sup.isSwiftClass {
            return self._shallowFields + sup.fields
        }
        
        return self._shallowFields
    }
}

extension EnumMetadata {
    var fields: [Field] { self._shallowFields }
}

// MARK: Protocol conformance checking
extension TypeMetadata {
    func conforms(to _protocol: Any) -> Bool {
        let existential = reflect(_protocol) as! MetatypeMetadata
        let instance = existential.instanceMetadata as! ExistentialMetadata
        let desc = instance.protocols.first!
        
        return !self.conformances.filter({ $0.protocol == desc }).isEmpty
    }
}

// MARK: MetadataKind
extension MetadataKind {
    var isObject: Bool {
        return self == .class || self == .objcClassWrapper
    }
}

// MARK: Object allocation
extension ClassMetadata {
    func createInstance<T: AnyObject>(props: [String: Any] = [:]) -> T {
        let obj = swift_allocObject(
            for: self,
            size: self.instanceSize,
            alignment: self.instanceAlignmentMask
        )
        
        for (key, value) in props {
            // TODO: this shouldn't be inout for this case
            self.set(value: value, forKey: key, pointer: obj~)
        }
        
        return Unmanaged.fromOpaque(obj).takeRetainedValue()
    }
}

// MARK: Struct initialization
extension StructMetadata {
    func createInstance(props: [String: Any] = [:]) -> Any {
        assert({
            let givenKeys = Set(props.keys.map { $0 as String })
            let allKeys = Set(self.descriptor.fields.records.map(\.name))
            return givenKeys == allKeys
        }())
        
        var box = AnyExistentialContainer(metadata: self)
        for (key, value) in props {
            self.set(value: value, forKey: key, pointer: box.getValueBuffer()~)
        }
        
        return box.toAny
    }
}

// MARK: Tuple initialization
extension TupleMetadata {
    func createInstance(elements: [Any] = []) -> Any {
        var box = AnyExistentialContainer(metadata: self)
        let ptr = box.getValueBuffer()
        
        // Copy each element of the array to each tuple element at the specified offset
        for (e, value) in zip(self.elements, elements) {
            var valueBox = container(for: value)
            ptr.copyMemory(ofTupleElement: valueBox.projectValue(), layout: e)
        }
        
        return box.toAny
    }
}

// MARK: Populating AnyExistentialContainer
extension AnyExistentialContainer {
    var toAny: Any {
        return unsafeBitCast(self, to: Any.self)
    }
    
    var isEmpty: Bool {
        return self.data == (0, 0, 0)
    }
    
    init(boxing valuePtr: RawPointer, type: Metadata) {
        self = .init(metadata: type)
        self.store(value: valuePtr)
    }
    
    init(nil optionalType: EnumMetadata) {
        self = .init(metadata: optionalType)
        
        // Zero memory
        let size = optionalType.vwt.size
        self.getValueBuffer().initializeMemory(
            as: Int8.self, repeating: 0, count: size
        )
    }
    
    mutating func store(value newValuePtr: RawPointer) {
        self.metadata.vwt.initializeWithCopy(self.getValueBuffer(), newValuePtr)
//        self.getValueBuffer().copyMemory(from: newValuePtr, type: self.metadata)
    }
    
    /// Calls into `projectValue()` but will allocate a box
    /// first if needed for types that are not inline
    mutating func getValueBuffer() -> RawPointer {
        // Allocate a box if needed and return it
        if !self.metadata.vwt.flags.isValueInline && self.data.0 == 0 {
            return self.metadata.allocateBoxForExistential(in: &self)~
        }
        
        // We don't need a box or already have one
        return self.projectValue()~
    }
}

//internal extension FieldRecord: @retroactive CustomDebugStringConvertible {
//    var debugDescription: String {
//        let ptr = self.mangledTypeName.assumingMemoryBound(to: UInt8.self)
//        return self.name + ": \(String(cString: ptr)) ( \(self.referenceStorage) : \(self.flags))"
//    }
//}

extension EnumMetadata {
    func getTag(for instance: Any) -> UInt32 {
        var box = container(for: instance)
        return self.enumVwt.getEnumTag(for: box.projectValue())
    }
    
    func copyPayload(from instance: Any) -> (value: Any, type: Any.Type)? {
        let tag = self.getTag(for: instance)
        let isPayloadCase = self.descriptor.numPayloadCases > tag
        if isPayloadCase {
            let caseRecord = self.descriptor.fields.records[Int(tag)]
            let type = self.type(of: caseRecord.mangledTypeName)!
            var caseBox = container(for: instance)
            // Copies in the value and allocates a box as needed
            let payload = AnyExistentialContainer(
                boxing: caseBox.projectValue()~,
                type: reflect(type)
            )
            return (unsafeBitCast(payload, to: Any.self), type)
        }
        
        return nil
    }
}
