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

public class OpaqueTransformer {
    public typealias Transformation = (Any?) -> Any
    fileprivate var forwardBlock: Transformation? = nil
    fileprivate var reverseBlock: Transformation? = nil
    
    internal init() { }
    
    public init(forwardBlock: @escaping Transformation) {
        self.forwardBlock = forwardBlock
        self.reverseBlock = nil
    }
    
    public init(forwardBlock: @escaping Transformation, reverseBlock: @escaping Transformation) {
        self.forwardBlock = forwardBlock
        self.reverseBlock = reverseBlock
    }
    
    public func transform(forward value: Any?) throws -> Any {
        return self.forwardBlock!(value)
    }
    
    public func transform(reverse value: Any?) throws -> Any {
        return self.reverseBlock!(value)
    }
}

public typealias AnyTransformer = OpaqueTransformer

public class Transform<T: JSONCodable, U: JSONCodable>: OpaqueTransformer {
    public enum Error: Swift.Error {
        case typeMismatch(given: Any.Type, expected: Any.Type)
    }
    
    public static func transform(_ t: T?) throws -> U {
        return try U.decode(from: t?.toJSON ?? T.defaultJSON)
    }
    
    public static func reverse(_ u: U?) throws -> T {
        return try T.decode(from: u?.toJSON ?? U.defaultJSON)
    }
    
    public override init() { super.init() }
    
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
        
        return try self.transform(t) as Any
    }
    
    override public func transform(reverse value: Any?) throws -> Any {
        guard let u = value as? U? else {
            throw Error.typeMismatch(given: type(of: value), expected: U.self)
        }
        
        return try self.reverse(u)
    }
}
