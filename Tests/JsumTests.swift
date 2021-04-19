//
//  JsumTests.swift
//  JsumTests
//
//  Created by Tanner Bennett on 4/16/21.
//

import XCTest
@testable import Jsum
@testable import Echo

class JsumTests: XCTestCase {
    
    func testDecodeTuple() throws {
        let person: (name: String, age: Int) = try Jsum.decode(
            from: ["name": "Bob", "age": 25]
        )
        XCTAssertEqual(person.name, "Bob")
        XCTAssertEqual(person.age, 25)
    }
    
    /// Just needs to compile
    func testGenericConstraints() throws {
        _ = try Transformer<Int, String>.transform(5)
        _ = try Transformer<[Int], [String]>.transform([5])
        
        let person: (name: String, age: Int) = try Jsum.decode(
            from: ["name": "Bob", "age": 25]
        )
    }
}
