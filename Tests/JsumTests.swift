//
//  JsumTests.swift
//  JsumTests
//
//  Created by Tanner Bennett on 4/16/21.
//

import XCTest
import Foundation
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
            var _: JustDeallocateMe = cls.createInstance(props: ["expectation": expect])
        }
        
        self.wait(for: [expect], timeout: 20)
    }
    
    func testJSONCodableExistentials() {
        let type: JSONCodable.Type = Employee.self as JSONCodable.Type
        XCTAssert(type.isClass)
        
        XCTAssertEqual(Employee.bob.toJSON.asObject, ["class": JSON.string("Employee")])
    }
    
    func testDecodeEmployee() throws {
        let data: [String : Any] = [
            "position": "Programmer",
            "salary": 120_000,
            "cubicleSize": ["width": 9, "height": 5],
            "name": "Janice",
            "age": 30
        ]
        
        let employee: Employee = try Jsum.decode(from: data)
        
        XCTAssertEqual(employee.name, data["name"] as! String)
        XCTAssertEqual(employee.age, data["age"] as! Int)
        XCTAssertEqual(employee.cubicleSize, Size(width: 9, height: 5))
        XCTAssertEqual(employee.position, data["position"] as! String)
        XCTAssertEqual(employee.salary, Double(data["salary"] as! Int))
    }
    
    func testDecodePostWithCustomTransformers() throws {
        let data: [String: Any] = [
            "title": "My cat is so cute",
            "body_markdown": NSNull(),
            "saved": NSNull(),
            "details": [
                "score": "-25034",
                "upvoted": NSNull()
            ]
        ]
        
        let post: Post = try Jsum.decode(from: data)
        XCTAssertEqual(post.score, -25034)
        XCTAssertEqual(post.saved, false)
        XCTAssertEqual(post.upvoted, false)
        XCTAssertEqual(post.body, nil)
    }
    
    func testOptionals() {
        // Just needs to not crash
        let anyOptional: Any? = nil
        let _: Int? = anyOptional as! Int?
        let any = anyOptional as Any
        
        // Assumptions about types
        let type = reflect(any)
        XCTAssertEqual(type.kind, .optional)
        XCTAssert((type as! EnumMetadata).genericMetadata.first!.type == Any.self)
    }
    
    func testNSNumber() {
        // Just needs to not crash
        let _ = -1234 as AnyObject as! NSNumber
    }
}
