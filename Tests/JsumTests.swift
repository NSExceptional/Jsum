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
    
    func testGenericsDecodeCorrectType() throws {
        class Base: Codable { }
        class Child: Base {
            var name: String
            required init(from decoder: any Decoder) throws { fatalError() }
        }
        
        let opaqueType: Base.Type = Child.self
        let data = ["name": "Hailey"]
        
        let obj: Base = try Jsum.decode(opaqueType, from: data)
        
        XCTAssert(type(of: obj) === opaqueType)
    }
    
    func testOpenExistentials() throws {
        
        enum Colors: String {
            case red = "red"
            case blue = "blue"
            case green = "green"
        }
        
        struct Marker {
            let color: Colors
        }
        
        let marker: Marker = try Jsum.decode(from: ["color": "red"])
        let color: Colors = try Jsum.decode(from: "red")
        
        XCTAssertEqual(marker.color, .red)
        XCTAssertEqual(marker.color, color)
        
//        let inputValue = "red"
//        func createColor<T: RawRepresentable>(_: T.Type) -> T {
//            return T.init(rawValue: inputValue as! T.RawValue)!
//        }

//        let type: any RawRepresentable.Type = Colors.self
//        let i = _openExistential(type, do: createColor(_:))
//        
//        XCTAssertEqual(i as? Colors, .red)
    }
    
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
    
    func testDefaultValues() {
        var json: [String: Any] = [:]
        
        var instance: JustDecodeMe = try! Jsum.decode(from: json)
        XCTAssertEqual(instance.truth, true)
        XCTAssertEqual(instance.five, 5)
        XCTAssertEqual(instance.pie, 3.14)
        
        json = ["truth": false, "five": 1.168, "pie": 10]
        instance = try! Jsum.decode(from: json)
        
        XCTAssertEqual(instance.truth, false)
        XCTAssertEqual(instance.five, 1)
        XCTAssertEqual(instance.pie, 10.0)
    }
    
    func testDecodeCollections() {
        let strings = ["1", "2", "3"]
        let nums: [Int] = try! Jsum.decode(from: strings)
        XCTAssertEqual(nums, [1, 2, 3])
        
        let numMap = ["a": 1, "b": 2, "c": 3]
        let stringMap: [String: String] = try! Jsum.decode(from: numMap)
        XCTAssertEqual(stringMap, ["a": "1", "b": "2", "c": "3"])
    }
    
    func testDecodeDates() throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [formatter.formatOptions, .withFractionalSeconds]
        
        let now = Date().ignoringTime
        let j = Jsum()
        let dateString = formatter.string(from: now)
        
        var date: Date = try j.decode(from: dateString)
        XCTAssertEqual(date, now)
        
        date = try j.decode(from: now.timeIntervalSince1970)
        XCTAssertEqual(date, now)
    }
    
    func testDecodeData() throws {
        let string = "Hello, world!"
        let base64 = string.data(using: .utf8)!.base64EncodedString()
        
        let data: Data = try Jsum.decode(from: base64)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
    }
    
    func testDecodeURL() throws {
        struct HasURL: Equatable {
            var url: URL
        }
        let urlString = "https://google.com/"
        let obj = ["url": urlString]
        
        let hasurl: HasURL = try Jsum.decode(from: obj)
        XCTAssertEqual(URL(string: urlString)!, hasurl.url)
    }
    
    func testFailOnNullNonOptionals() {
        var json: [String: Any] = ["x": 5]
        // y is missing; we want it to default to 0
        var result = Jsum.tryDecode(Point.self, from: json)
        XCTAssert(result.succeeded)
        
        // y is missing and non-optional; we want it to default to 0
        result = Jsum().failOnNullNonOptionals().tryDecode(Point.self, from: json)
        XCTAssert(result.succeeded)
        
        json = ["x": 5, "y": NSNull()]
        // y is not missing but is nil/null; we want it to fail decoding
        result = Jsum().failOnNullNonOptionals().tryDecode(Point.self, from: json)
        XCTAssert(result.failed)
        
        // TODO: tests for tuples and enums with payloads, and default values
    }
    
    func testFailOnMissingKeys() {
        var json: [String: Any] = ["x": 5]
        // y is missing; we want it to default to 0
        var result = Jsum.tryDecode(Point.self, from: json)
        XCTAssert(result.succeeded)
        
        // y is missing; we want it to fail decoding
        result = Jsum().failOnMissingKeys().tryDecode(Point.self, from: json)
        XCTAssert(result.failed)
        
        json = ["x": 5, "y": NSNull()]
        // y is null; we want it to default to 0
        result = Jsum.tryDecode(Point.self, from: json)
        XCTAssert(result.succeeded)
        
        // y is not missing, just null; we want it to default to 0
        result = Jsum().failOnMissingKeys().tryDecode(Point.self, from: json)
        XCTAssert(result.succeeded)
        
        // TODO: tests for tuples and enums with payloads, and default values
    }
}
