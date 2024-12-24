//
//  Transformer.swift
//  Jsum
//
//  Created by Tanner Bennett on 4/16/21.
//  Copyright © 2021 Tanner Bennett. All rights reserved.
//

import Foundation

public enum TransformError: Error {
    case notConvertible
}

/// A non-generic transformer class. You should use `Transform<T,U>` first if you can.
public class OpaqueTransformer {
    public typealias Transformation = (Any?) throws -> Any
    fileprivate var forwardBlock: Transformation? = nil
    fileprivate var reverseBlock: Transformation? = nil
    
    internal init() { }
    
    public init(forwardBlock: @escaping Transformation) {
        self.forwardBlock = forwardBlock
        self.reverseBlock = nil
    }
    
    public init(forwardBlock: @escaping Transformation, reverseBlock: Transformation? = nil) {
        self.forwardBlock = forwardBlock
        self.reverseBlock = reverseBlock
    }
    
    public func transform(forward value: Any?) throws -> Any {
        return try self.forwardBlock!(value)
    }
    
    public func transform(reverse value: Any?) throws -> Any {
        return try self.reverseBlock!(value)
    }
}

public typealias AnyTransformer = OpaqueTransformer

public class Transform<T: JSONCodable, U: JSONCodable>: OpaqueTransformer {
    public typealias ForwardTransformation = (T?) throws -> U
    public typealias ReverseTransformation = (U?) throws -> T
    
    private var _forwardBlock: ForwardTransformation? { self.forwardBlock as! ForwardTransformation? }
    private var _reverseBlock: ReverseTransformation? { self.reverseBlock as! ReverseTransformation? }
    
    public enum Error: Swift.Error {
        case typeMismatch(given: Any.Type, expected: Any.Type)
    }
    
    static var snakeCaseToCamelCase: Transform<String,String> {
        .init(forwardBlock: { 
            return Jsum.snakeCaseToCamelCase($0!)
        }, reverseBlock: {
            return Jsum.camelCaseToSnakeCase($0!)
        })
    }
    
    static var camelCaseToSnakeCase: Transform<String,String> {
        self.snakeCaseToCamelCase.reversed()
    }
    
    func reversed() -> Transform<U,T> {
        guard let reverse = _reverseBlock else {
            fatalError("Cannot reverse one-way transformer")
        }
        
        return .init(forwardBlock: reverse, reverseBlock: _forwardBlock!)
    }
    
    public static func transform(_ t: T?) throws -> U {
        return try U.decode(from: t?.toJSON ?? T.defaultJSON)
    }
    
    public static func reverse(_ u: U?) throws -> T {
        return try T.decode(from: u?.toJSON ?? U.defaultJSON)
    }
    
    public override init() { super.init() }
    
    public init(forwardBlock: @escaping ForwardTransformation) {
        super.init(forwardBlock: { try forwardBlock(($0 as! T)) })
    }
    
    public init(forwardBlock: @escaping ForwardTransformation, reverseBlock: ReverseTransformation?) {
        super.init(
            forwardBlock: { try forwardBlock(($0 as! T)) },
            reverseBlock: reverseBlock == nil ? nil : { try reverseBlock!(($0 as! U)) }
        )
    }
    
    public func transform(_ t: T?) throws -> U {
        return try Self.transform(t)
    }
    
    public func reverse(_ u: U?) throws -> T {
        return try Self.reverse(u)
    }
    
    override public func transform(forward value: Any?) throws -> Any {
        guard let t = value as? T? else {
            throw Error.typeMismatch(given: type(of: value), expected: T.self)
        }
        
        // If initialized with explicit blocks, use those instead
        if self.forwardBlock != nil {
            return try super.transform(forward: value)
        }
        
        return try self.transform(t) as Any
    }
    
    override public func transform(reverse value: Any?) throws -> Any {
        guard let u = value as? U? else {
            throw Error.typeMismatch(given: type(of: value), expected: U.self)
        }
        
        // If initialized with explicit blocks, use those instead
        if self.reverseBlock != nil {
            return try super.transform(reverse: value)
        }
        
        return try self.reverse(u)
    }
}
