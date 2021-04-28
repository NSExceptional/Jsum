//
//  DeclarativeCustomCodingTests.swift
//  DeclarativeCustomCodingTests
//
//  Created by Mark Malstrom on 4/28/21.
//

import XCTest
@testable import Jsum

final class DeclarativeCustomCodingTests: XCTestCase {
    func testTypeTransforming() {
        struct Post: JSONCodable {
            var title: String
            var score: Int
            var isSaved: Bool
            var isUpvoted: Bool
            
            static var coding: CustomCoding {
                Property("score").transform(from: String?.self)
                Property("isSaved").transform(from: String?.self)
                Property("isUpvoted").transform(from: Int.self)
            }
        }
        
        let data: [String: Any] = [
            "title": "Hello World",
            "score": "100",
            "isSaved": NSNull(),
            "isUpvoted": 1
        ]
        
        let post: Post = try! Jsum.decode(from: data)
        
        XCTAssertEqual(post.title, "Hello World")
        XCTAssertEqual(post.score, 100)
        XCTAssertEqual(post.isSaved, false)
        XCTAssertEqual(post.isUpvoted, true)
    }
    
    func testKeyPathTransforming() {
        struct KeyPathTest: JSONCodable {
            var a: String
            var b: String
            var c: String
            var d: String
            var e: String
            
            static var coding: CustomCoding {
                Property("b").keyed(as: "aa.b")
                Property("c").keyed(as: "aa.bb.c")
                Property("d").keyed(as: "aa.bb.cc.d")
                Property("e").keyed(as: "aa.bb.cc.dd.e")
            }
        }
        
        let data: [String: Any] = [
            "a": "A'llo World",
            "aa": [
                "b": "B'llo World",
                "bb": [
                    "c": "C'llo World",
                    "cc": [
                        "d": "D'llo World",
                        "dd": [
                            "e": "E'llo World",
                        ]
                    ]
                ]
            ]
        ]
        
        let test: KeyPathTest = try! Jsum.decode(from: data)
        
        XCTAssertEqual(test.a, "A'llo World")
        XCTAssertEqual(test.b, "B'llo World")
        XCTAssertEqual(test.c, "C'llo World")
        XCTAssertEqual(test.d, "D'llo World")
        XCTAssertEqual(test.e, "E'llo World")
    }
}
