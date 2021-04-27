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
        _ = try Transform<Int, String>.transform(5)
        _ = try Transform<[Int], [String]>.transform([5])
        
        let _: (name: String, age: Int) = try Jsum.decode(
            from: ["name": "Bob", "age": 25]
        )
    }
    
    func testBuiltinMetadata() {
        let metadata = KnownMetadata.Builtin.int64
        XCTAssert(metadata.isBuiltin)
        
        let intm = reflect(Int.self)
        XCTAssert(intm.isBuiltin)
        
        let stringm = reflect(String.self)
        XCTAssert(!stringm.isBuiltin)
    }
    
    func testEmptyStruct() {
        struct Nothing { }
        
        let metadata = reflectStruct(Nothing.self)!
        XCTAssert(metadata.fields.isEmpty)
        XCTAssert(metadata.vwt.size == 0)
    }
    
//    func testEnumTypeNoFields() {
//        let metadata = reflectEnum(JSON.self)!
//        XCTAssert(metadata.descriptor.fields.records.first!.flags.isVar)
//    }
    
    func testFieldedTypeHasNoComputedFields() {
        let metadata = reflectClass(Person.self)!
        let fields = metadata.descriptor.fields
        
        XCTAssertEqual(fields.records.count, metadata.fieldOffsets.count)
        XCTAssert(fields.records.filter({ $0.name == "tuple" }).isEmpty)
    }

    func testProtocolConformances() {
        let person = reflectClass(Person.self)!
        XCTAssert(person.conforms(to: Conformable.self))
    }
    
    func testBuiltinDecodeProtocolMethod() throws {
        let int = reflectStruct(Int.self)!
        XCTAssert(int.conforms(to: JSONCodable.self))
        
        XCTAssertEqual(try Jsum.decode(from: 5), 5)
        XCTAssertEqual(try Jsum.decode(from: 3.14159), 3.14159)
    }
    
    func testAllocObject() {
        let expect = XCTestExpectation(description: "deinit")
        let cls = reflectClass(JustDeallocateMe.self)!
        DispatchQueue.global().async {
            var obj: JustDeallocateMe? = cls.createInstance(props: ["expectation": expect])
            obj = nil
        }
        
        self.wait(for: [expect], timeout: 2)
    }
}
