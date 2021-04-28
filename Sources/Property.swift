//
//  Property.swift
//  Property
//
//  Created by Mark Malstrom on 4/28/21.
//

public struct Property {
    var propertyName: String
    var keyedAs: String? = nil
    var transformTo: Any.Type? = nil
    
    public init(_ keyPath: String) { propertyName = keyPath }
    init() { propertyName = "" }
    
    public func transform<TransformTo>(from type: TransformTo.Type) -> Self {
        var this = self
        this.transformTo = type
        return this
    }
    
    public func keyed(as key: String) -> Self {
        var this = self
        this.keyedAs = key
        return this
    }
    
    static func empty() -> Self {
        return .init()
    }
}

@_functionBuilder
public struct PropertyBuilder {
    public static func buildBlock(_ properties: Property...) -> [Property] {
        properties
    }
}

