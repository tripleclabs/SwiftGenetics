//
//  File.swift
//  
//
//  Created by Santiago Gonzalez on 12/6/19.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

/// A type-erasing wrapper for `Codable`.
public struct AnyCodable: Codable, @unchecked Sendable {

	public let value: Any
	
    /// Wraps the provided `Codable` object.
    public init(_ value: Any) {
        self.value = value
    }

	// MARK: - Coding.
	
    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer()

        if let value = try? values.decode(String.self) {
            self.value = value
        } else if let value = try? values.decode(Bool.self) {
            self.value = value
        } else if let value = try? values.decode([String: AnyCodable].self) {
            self.value = value.mapValues { $0.value }
        } else if let value = try? values.decode([AnyCodable].self) {
            self.value = value.map { $0.value }
        } else if let value = try? values.decode(Double.self) {
            switch value {
            case value.rounded():
                self.value = Int(value)
            default:
                self.value = value
            }
        } else {
            throw GeneticError.decodingError("Cannot decode unknown AnyCodable value.")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let value as String:
            try container.encode(value)
        case let value as Bool:
            try container.encode(value)
        case let value as Int:
            try container.encode(value)
        case let value as Array<Codable>:
            try container.encode(value.map { AnyCodable($0) })
        case let value as Dictionary<String, Codable>:
            try container.encode(value.mapValues { AnyCodable($0) })
        case let value as Float:
            try container.encode(value)
        case let value as Double:
            try container.encode(value)
        default:
            throw GeneticError.unexpectedType("Cannot encode unknown AnyCodable value type: \(type(of: value))")
        }
    }
}

extension AnyCodable: Equatable {
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case let (l as Bool, r as Bool):
            return l == r
        case let (l as String, r as String):
            return l == r
        case let (l as Int, r as Int):
            return l == r
        case let (l as Double, r as Double):
            return l == r
        case let (l as Float, r as Float):
            return l == r
        case let (l as Int, r as Double):
            return Double(l) == r
        case let (l as Double, r as Int):
            return l == Double(r)
        case let (l as Int, r as Float):
            return Float(l) == r
        case let (l as Float, r as Int):
            return l == Float(r)
        case let (l as Float, r as Double):
            return Double(l) == r
        case let (l as Double, r as Float):
            return l == Double(r)
        case let (l as [Any], r as [Any]):
            guard l.count == r.count else { return false }
            for i in 0..<l.count {
                if AnyCodable(l[i]) != AnyCodable(r[i]) { return false }
            }
            return true
        case let (l as [String: Any], r as [String: Any]):
            guard l.count == r.count else { return false }
            for (k, lv) in l {
                guard let rv = r[k], AnyCodable(lv) == AnyCodable(rv) else { return false }
            }
            return true
        default:
            return false
        }
    }
}
