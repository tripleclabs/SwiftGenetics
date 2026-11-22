//
//  TreeGeneType.swift
//  SwiftGenetics
//
//  Created by Santiago Gonzalez on 6/27/19.
//  Copyright © 2019 Santiago Gonzalez. All rights reserved.
//

import Foundation

/// An abstract interface that all tree gene types conform to.
public protocol TreeGeneType: Hashable, Codable, Sendable {
	var childCount: Int { get }
	var isBinaryType: Bool { get }
	var isUnaryType: Bool { get }
	var isLeafType: Bool { get }
	static var binaryTypes: [Self] { get }
	static var unaryTypes: [Self] { get }
	static var leafTypes: [Self] { get }
	static var nonLeafTypes: [Self] { get }
	static var allTypes: [Self] { get }
}

extension TreeGeneType {
	public var isBinaryType: Bool { return Self.binaryTypes.contains(self) }
	public var isUnaryType: Bool { return Self.unaryTypes.contains(self) }
	public var isLeafType: Bool { return Self.leafTypes.contains(self) }
	
	public static var nonLeafTypes: [Self] { return binaryTypes + unaryTypes }
	public static var allTypes: [Self] { return nonLeafTypes + leafTypes }
}


/// Templates can enforce certain constraints and define gene type sampling.
public struct TreeGeneTemplate<T: TreeGeneType>: Codable, Sendable {
	/// Sampling array for binary gene types.
	let binaryTypes: [T]
	/// Sampling array for unary gene types.
	let unaryTypes: [T]
	/// Sampling array for leaf gene types.
	let leafTypes: [T]
	
	/// Precomputed sampling array for non-leaf types.
	let nonLeafTypes: [T]
	/// Precomputed sampling array for all types.
	let allTypes: [T]
	
	enum CodingKeys: String, CodingKey {
		case binaryTypes
		case unaryTypes
		case leafTypes
	}
	
	/// Creates a new template.
	public init(binaryTypes: [T], unaryTypes: [T], leafTypes: [T]) {
		self.binaryTypes = binaryTypes
		self.unaryTypes = unaryTypes
		self.leafTypes = leafTypes
		let nonLeaf = binaryTypes + unaryTypes
		self.nonLeafTypes = nonLeaf
		self.allTypes = nonLeaf + leafTypes
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let binaryTypes = try container.decode([T].self, forKey: .binaryTypes)
		let unaryTypes = try container.decode([T].self, forKey: .unaryTypes)
		let leafTypes = try container.decode([T].self, forKey: .leafTypes)
		self.init(binaryTypes: binaryTypes, unaryTypes: unaryTypes, leafTypes: leafTypes)
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(binaryTypes, forKey: .binaryTypes)
		try container.encode(unaryTypes, forKey: .unaryTypes)
		try container.encode(leafTypes, forKey: .leafTypes)
	}
}

extension TreeGeneTemplate: Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(binaryTypes)
		hasher.combine(unaryTypes)
		hasher.combine(leafTypes)
	}
}
