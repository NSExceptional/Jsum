//
//  DeclarativeCustomCodingTests.swift
//  DeclarativeCustomCodingTests
//
//  Created by Mark Malstrom on 4/28/21.
//

import XCTest
@testable import Jsum

struct Post: JSONCodable {
    var title: String
    var score: Int
    var isSaved: Bool
    var isUpvoted: Bool
    
    static var coding: CustomCoding {
        Property("score").transform(from: String?.self)
        Property("isSaved")
            .keyed(as: "details.saved")
            .transform(from: String?.self)
        Property("isUpvoted")
            .keyed(as: "details.upvoted")
            .transform(from: Int.self)
    }
}

final class DeclarativeCustomCodingTests: XCTestCase {
    let json = """
    {
        title: "Hello World",
        score: "100"
        details: {
            saved: null,
            upvoted: 1
        }
    }
    """
    
    let data: [String: Any] = [
        "title": "Hello World",
        "score": "100",
        "isSaved": NSNull(),
        "isUpvoted": 1
    ]
    
    func testTypeTransforming() {
        let post: Post = try! Jsum.decode(from: data)
        
        XCTAssertEqual(post.title, "Hello World")
        XCTAssertEqual(post.score, 100)
        XCTAssertEqual(post.isSaved, false)
        XCTAssertEqual(post.isUpvoted, true)
    }
    
    func testKeyPathTransforming() {
        
    }
}
