//
//  SampleTypes.swift
//  ReflexTests
//
//  Created by Tanner Bennett on 4/12/21.
//  Copyright © 2021 Tanner Bennett. All rights reserved.
//

import Foundation
import Jsum
import XCTest

protocol Conformable { }

struct Counter<T: Numeric> {
    var count: T = 5
}

struct Point: Equatable {
    var x: Int = 0
    var y: Int = 0
}

struct Size: Equatable {
    var width: Int = 0
    var height: Int = 0
}

class Person: Equatable, Conformable {
    var name: String
    var age: Int
    
    var tuple: (String, Int) {
        return (self.name, self.age)
    }
    
    internal init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
    
    static func == (lhs: Person, rhs: Person) -> Bool {
        return lhs.name == rhs.name && lhs.age == rhs.age
    }
    
    func sayHello() {
        print("Hello!")
    }
}

class Employee: Person, JSONCodable {    
    private(set) var position: String
    private(set) var salary: Double
    let cubicleSize = Size(width: 5, height: 7)
    
    var job: (position: String, salary: Double) {
        return (self.position, self.salary)
    }
    
    static var bob = Employee(name: "Bob", age: 52, position: "Programmer")
    
    internal init(name: String, age: Int, position: String, salary: Double = 60_000) {
        self.position = position
        self.salary = salary
        super.init(name: name, age: age)
    }
    
    func promote() -> (position: String, salary: Double) {
        self.position += "+"
        self.salary *= 1.05
        
        return self.job
    }
}

class JustDeallocateMe {
    var expectation: XCTestExpectation
    
    init(_ expectation: XCTestExpectation) {
        self.expectation = expectation
    }
    
    deinit {
        self.expectation.fulfill()
    }
}
