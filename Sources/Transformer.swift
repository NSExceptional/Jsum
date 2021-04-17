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

public struct Transformer<T: JSONCodable, U: JSONCodable> {
    static func transform(_ t: T?) throws -> U {
        return try U.decode(from: t?.toJSON ?? T.defaultJSON)
    }
    
    static func reverse(_ u: U?) throws -> T {
        return try T.decode(from: u?.toJSON ?? U.defaultJSON)
    }
    
    func transform(_ t: T?) throws -> U {
        return try Self.transform(t)
    }
    
    func reverse(_ u: U?) throws -> T {
        return try Self.reverse(u)
    } 
}
