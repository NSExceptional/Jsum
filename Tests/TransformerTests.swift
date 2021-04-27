//
//  TransformerTests.swift
//  Jsum
//
//  Created by Tanner Bennett on 4/16/21.
//

import XCTest
@testable import Jsum

class TransformerTests: XCTestCase {
    
    func testBoolToT() {
        XCTAssertEqual(try! Transform<Bool,Bool>.transform(true), true)
        XCTAssertEqual(try! Transform<Bool,Bool>.transform(false), false)
        XCTAssertEqual(try! Transform<Bool,Bool>.transform(nil), false)
        XCTAssertEqual(try! Transform<Bool,Int>.transform(true), 1)
        XCTAssertEqual(try! Transform<Bool,Int>.transform(false), 0)
        XCTAssertEqual(try! Transform<Bool,Int>.transform(nil), 0)
        XCTAssertEqual(try! Transform<Bool,Double>.transform(true), 1.0)
        XCTAssertEqual(try! Transform<Bool,Double>.transform(false), 0.0)
        XCTAssertEqual(try! Transform<Bool,Double>.transform(nil), 0.0)
        XCTAssertEqual(try! Transform<Bool,String>.transform(true), "true")
        XCTAssertEqual(try! Transform<Bool,String>.transform(false), "false")
        XCTAssertEqual(try! Transform<Bool,String>.transform(nil), "false")
        
        XCTAssertEqual(try! Transform<Bool?,Bool>.transform(true), true)
        XCTAssertEqual(try! Transform<Bool?,Bool>.transform(false), false)
        XCTAssertEqual(try! Transform<Bool?,Bool>.transform(nil), false)
        XCTAssertEqual(try! Transform<Bool?,Int>.transform(true), 1)
        XCTAssertEqual(try! Transform<Bool?,Int>.transform(false), 0)
        XCTAssertEqual(try! Transform<Bool?,Int>.transform(nil), 0)
        XCTAssertEqual(try! Transform<Bool?,Double>.transform(true), 1.0)
        XCTAssertEqual(try! Transform<Bool?,Double>.transform(false), 0.0)
        XCTAssertEqual(try! Transform<Bool?,Double>.transform(nil), 0.0)
        XCTAssertEqual(try! Transform<Bool?,String>.transform(true), "true")
        XCTAssertEqual(try! Transform<Bool?,String>.transform(false), "false")
        XCTAssertEqual(try! Transform<Bool?,String>.transform(nil), "null")
    }
    
    func testIntToT() {
        let positive = 5
        let negative = -20
        let zero = 0
        
        XCTAssertEqual(try! Transform<Int,Bool>.transform(positive), true)
        XCTAssertEqual(try! Transform<Int,Bool>.transform(negative), true)
        XCTAssertEqual(try! Transform<Int,Bool>.transform(zero), false)
        XCTAssertEqual(try! Transform<Int,Bool>.transform(nil), false)
        XCTAssertEqual(try! Transform<Int,Int>.transform(positive), positive)
        XCTAssertEqual(try! Transform<Int,Int>.transform(negative), negative)
        XCTAssertEqual(try! Transform<Int,Int>.transform(zero), zero)
        XCTAssertEqual(try! Transform<Int,Int>.transform(nil), 0)
        XCTAssertEqual(try! Transform<Int,Double>.transform(positive), Double(positive))
        XCTAssertEqual(try! Transform<Int,Double>.transform(negative), Double(negative))
        XCTAssertEqual(try! Transform<Int,Double>.transform(zero), Double(zero))
        XCTAssertEqual(try! Transform<Int,Double>.transform(nil), 0.0)
        XCTAssertEqual(try! Transform<Int,String>.transform(positive), String(positive))
        XCTAssertEqual(try! Transform<Int,String>.transform(negative), String(negative))
        XCTAssertEqual(try! Transform<Int,String>.transform(zero), String(zero))
        XCTAssertEqual(try! Transform<Int,String>.transform(nil), String(0))
        
        XCTAssertEqual(try! Transform<Int?,Bool>.transform(positive), true)
        XCTAssertEqual(try! Transform<Int?,Bool>.transform(negative), true)
        XCTAssertEqual(try! Transform<Int?,Bool>.transform(zero), false)
        XCTAssertEqual(try! Transform<Int?,Bool>.transform(nil), false)
        XCTAssertEqual(try! Transform<Int?,Int>.transform(positive), positive)
        XCTAssertEqual(try! Transform<Int?,Int>.transform(negative), negative)
        XCTAssertEqual(try! Transform<Int?,Int>.transform(zero), zero)
        XCTAssertEqual(try! Transform<Int?,Int>.transform(nil), 0)
        XCTAssertEqual(try! Transform<Int?,Double>.transform(positive), Double(positive))
        XCTAssertEqual(try! Transform<Int?,Double>.transform(negative), Double(negative))
        XCTAssertEqual(try! Transform<Int?,Double>.transform(zero), Double(zero))
        XCTAssertEqual(try! Transform<Int?,Double>.transform(nil), 0.0)
        XCTAssertEqual(try! Transform<Int?,String>.transform(positive), String(positive))
        XCTAssertEqual(try! Transform<Int?,String>.transform(negative), String(negative))
        XCTAssertEqual(try! Transform<Int?,String>.transform(zero), String(zero))
        XCTAssertEqual(try! Transform<Int?,String>.transform(nil), "null")
    }
    
    func testArrayToArray() {
        XCTAssertEqual(try! Transform<[String],[Int]>
                        .transform(["234", "123"]), [234, 123])
        
        XCTAssertEqual(try! Transform<[Bool?],[String]>
                        .transform([true, false, nil]), ["true", "false", "null"])
    }
}

