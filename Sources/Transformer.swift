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

public class AnyTransformer { }

public class OpaqueTransformer {
    public typealias Transformation = (Any?) -> Any?
    internal var forwardBlock: Transformation? = nil
    internal var reverseBlock: Transformation? = nil
    
    internal init() { }
    
    public init(forwardBlock: @escaping Transformation) {
        self.forwardBlock = forwardBlock
        self.reverseBlock = nil
    }
    
    public init(forwardBlock: @escaping Transformation, reverseBlock: @escaping Transformation) {
        self.forwardBlock = forwardBlock
        self.reverseBlock = reverseBlock
    }
    
    public func transform(forward value: Any?) -> Any? {
        return self.forwardBlock!(value)
    }
    
    public func transform(reverse value: Any?) -> Any? {
        return self.reverseBlock!(value)
    }
}

public class Transform<T: JSONCodable, U: JSONCodable>: OpaqueTransformer {
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
    
    override public func transform(forward value: Any?) -> Any? {
        if let t = value as? T {
            return try? self.transform(t)
        }
        
        return nil
    }
    
    override public func transform(reverse value: Any?) -> Any? {
        if let u = value as? U {
            return try? self.reverse(u)
        }
        
        return nil
    }
}
