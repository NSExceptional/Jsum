//
//  Extensions.swift
//  ReflexTests
//
//  Created by Tanner Bennett on 4/12/21.
//  Copyright © 2021 Tanner Bennett. All rights reserved.
//

import Foundation

extension UnsafeRawPointer {
    subscript<T>(offset: Int) -> T {
        get {
            return self.load(fromByteOffset: offset, as: T.self)
        }
    }
}

extension UnsafeMutableRawPointer {
    subscript<T>(offset: Int) -> T {
        get {
            return self.load(fromByteOffset: offset, as: T.self)
        }
        
        set {
            self.storeBytes(of: newValue, toByteOffset: offset, as: T.self)
        }
    }
}

postfix operator ~
postfix func ~<T>(target: T) -> UnsafeMutableRawPointer {
    return unsafeBitCast(target, to: UnsafeMutableRawPointer.self)
}
