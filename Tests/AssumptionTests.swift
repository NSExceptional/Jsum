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

class Assumptions: XCTestCase {
    
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
    
    func testNSNumber() {
        // Just needs to not crash
        let _ = -1234 as AnyObject as! NSNumber
    }
    
    func testGenericMetadataRootTypeEquality() {
        let anyarray = reflectStruct([Any].self)!
        let intarray = reflectStruct([Int].self)!
        
        XCTAssert(anyarray.descriptor == intarray.descriptor)
    }
    
    func testFieldedTypeHasNoComputedFields() {
        let metadata = reflectClass(Person.self)!
        guard let fields = metadata.descriptor?.fields else {
            return XCTFail()
        }
        
        XCTAssertEqual(fields.records.count, metadata.fieldOffsets.count)
        XCTAssert(fields.records.filter({ $0.name == "tuple" }).isEmpty)
    }
    
    func test_verifyPODs() {
        struct JustPrimitives { let i: Int; let d: Double }
        struct HasString { let s: String }
        struct HasArray { let a: [Int] }
        struct HasObject { let a: AnyObject }
        enum OneCaseNoPayload { case foo }
        enum TwoCasesNoPayloads { case foo, bar }
        enum OneCaseIntPayload { case foo(Int) }
        enum OneCaseObjPayload { case foo(AnyObject) }
        enum OneCaseDuoPayload { case foo(Int, AnyObject) }
        
        
        XCTAssert(reflect(Int.self).vwt.flags.isPOD)
        XCTAssert(reflect(Double.self).vwt.flags.isPOD)
        XCTAssert(reflect(UnsafeRawPointer.self).vwt.flags.isPOD)
        XCTAssert(reflect(JustPrimitives.self).vwt.flags.isPOD)
        XCTAssert(reflect(OneCaseNoPayload.self).vwt.flags.isPOD)
        XCTAssert(reflect(TwoCasesNoPayloads.self).vwt.flags.isPOD)
        XCTAssert(reflect(OneCaseIntPayload.self).vwt.flags.isPOD)
        
        XCTAssert(!reflect(String.self).vwt.flags.isPOD)
        XCTAssert(!reflect([Int].self).vwt.flags.isPOD)
        XCTAssert(!reflect(HasString.self).vwt.flags.isPOD)
        XCTAssert(!reflect(HasArray.self).vwt.flags.isPOD)
        XCTAssert(!reflect(HasObject.self).vwt.flags.isPOD)
        XCTAssert(!reflect(AnyObject.self).vwt.flags.isPOD)
        XCTAssert(!reflect(OneCaseObjPayload.self).vwt.flags.isPOD)
        XCTAssert(!reflect(OneCaseDuoPayload.self).vwt.flags.isPOD)
    }
}
