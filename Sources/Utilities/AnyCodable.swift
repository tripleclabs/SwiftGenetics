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
            fatalError("Cannot decode unknown value.")
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
            fatalError("Cannot encode unknown value.")
        }
    }
}

extension AnyCodable: Equatable {
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // This is a simple way to compare type-erased Codable values.
        // For dictionaries, ordering might be an issue with raw Data comparison,
        // but for these tests it should be sufficient or better than the raw test check.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let lhsData = try? encoder.encode(lhs),
              let rhsData = try? encoder.encode(rhs) else {
            return false
        }
        return lhsData == rhsData
    }
}
