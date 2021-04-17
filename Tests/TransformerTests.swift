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
        XCTAssertEqual(try! Transformer<Bool,Bool>.transform(true), true)
        XCTAssertEqual(try! Transformer<Bool,Bool>.transform(false), false)
        XCTAssertEqual(try! Transformer<Bool,Bool>.transform(nil), false)
        XCTAssertEqual(try! Transformer<Bool,Int>.transform(true), 1)
        XCTAssertEqual(try! Transformer<Bool,Int>.transform(false), 0)
        XCTAssertEqual(try! Transformer<Bool,Int>.transform(nil), 0)
        XCTAssertEqual(try! Transformer<Bool,Double>.transform(true), 1.0)
        XCTAssertEqual(try! Transformer<Bool,Double>.transform(false), 0.0)
        XCTAssertEqual(try! Transformer<Bool,Double>.transform(nil), 0.0)
        XCTAssertEqual(try! Transformer<Bool,String>.transform(true), "true")
        XCTAssertEqual(try! Transformer<Bool,String>.transform(false), "false")
        XCTAssertEqual(try! Transformer<Bool,String>.transform(nil), "false")
        
        XCTAssertEqual(try! Transformer<Bool?,Bool>.transform(true), true)
        XCTAssertEqual(try! Transformer<Bool?,Bool>.transform(false), false)
        XCTAssertEqual(try! Transformer<Bool?,Bool>.transform(nil), false)
        XCTAssertEqual(try! Transformer<Bool?,Int>.transform(true), 1)
        XCTAssertEqual(try! Transformer<Bool?,Int>.transform(false), 0)
        XCTAssertEqual(try! Transformer<Bool?,Int>.transform(nil), 0)
        XCTAssertEqual(try! Transformer<Bool?,Double>.transform(true), 1.0)
        XCTAssertEqual(try! Transformer<Bool?,Double>.transform(false), 0.0)
        XCTAssertEqual(try! Transformer<Bool?,Double>.transform(nil), 0.0)
        XCTAssertEqual(try! Transformer<Bool?,String>.transform(true), "true")
        XCTAssertEqual(try! Transformer<Bool?,String>.transform(false), "false")
        XCTAssertEqual(try! Transformer<Bool?,String>.transform(nil), "null")
    }
    
    func testIntToT() {
        let positive = 5
        let negative = -20
        let zero = 0
        
        XCTAssertEqual(try! Transformer<Int,Bool>.transform(positive), true)
        XCTAssertEqual(try! Transformer<Int,Bool>.transform(negative), true)
        XCTAssertEqual(try! Transformer<Int,Bool>.transform(zero), false)
        XCTAssertEqual(try! Transformer<Int,Bool>.transform(nil), false)
        XCTAssertEqual(try! Transformer<Int,Int>.transform(positive), positive)
        XCTAssertEqual(try! Transformer<Int,Int>.transform(negative), negative)
        XCTAssertEqual(try! Transformer<Int,Int>.transform(zero), zero)
        XCTAssertEqual(try! Transformer<Int,Int>.transform(nil), 0)
        XCTAssertEqual(try! Transformer<Int,Double>.transform(positive), Double(positive))
        XCTAssertEqual(try! Transformer<Int,Double>.transform(negative), Double(negative))
        XCTAssertEqual(try! Transformer<Int,Double>.transform(zero), Double(zero))
        XCTAssertEqual(try! Transformer<Int,Double>.transform(nil), 0.0)
        XCTAssertEqual(try! Transformer<Int,String>.transform(positive), String(positive))
        XCTAssertEqual(try! Transformer<Int,String>.transform(negative), String(negative))
        XCTAssertEqual(try! Transformer<Int,String>.transform(zero), String(zero))
        XCTAssertEqual(try! Transformer<Int,String>.transform(nil), String(0))
        
        XCTAssertEqual(try! Transformer<Int?,Bool>.transform(positive), true)
        XCTAssertEqual(try! Transformer<Int?,Bool>.transform(negative), true)
        XCTAssertEqual(try! Transformer<Int?,Bool>.transform(zero), false)
        XCTAssertEqual(try! Transformer<Int?,Bool>.transform(nil), false)
        XCTAssertEqual(try! Transformer<Int?,Int>.transform(positive), positive)
        XCTAssertEqual(try! Transformer<Int?,Int>.transform(negative), negative)
        XCTAssertEqual(try! Transformer<Int?,Int>.transform(zero), zero)
        XCTAssertEqual(try! Transformer<Int?,Int>.transform(nil), 0)
        XCTAssertEqual(try! Transformer<Int?,Double>.transform(positive), Double(positive))
        XCTAssertEqual(try! Transformer<Int?,Double>.transform(negative), Double(negative))
        XCTAssertEqual(try! Transformer<Int?,Double>.transform(zero), Double(zero))
        XCTAssertEqual(try! Transformer<Int?,Double>.transform(nil), 0.0)
        XCTAssertEqual(try! Transformer<Int?,String>.transform(positive), String(positive))
        XCTAssertEqual(try! Transformer<Int?,String>.transform(negative), String(negative))
        XCTAssertEqual(try! Transformer<Int?,String>.transform(zero), String(zero))
        XCTAssertEqual(try! Transformer<Int?,String>.transform(nil), "null")
    }
    
    func testArrayToArray() {
        XCTAssertEqual(try! Transformer<[String],[Int]>
                        .transform(["234", "123"]), [234, 123])
        
        XCTAssertEqual(try! Transformer<[Bool?],[String]>
                        .transform([true, false, nil]), ["true", "false", "null"])
    }
}

