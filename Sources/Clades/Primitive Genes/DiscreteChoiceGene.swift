//
//  DiscreteChoiceGene.swift
//  SwiftGenetics
//
//  Created by Santiago Gonzalez on 7/25/19.
//  Copyright © 2019 Santiago Gonzalez. All rights reserved.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

/// DIfferent types of categorical distributions should implement this protocol.
/// - Note: Any `CaseIterable` `enum` with `Codable` conformance supports `DiscreteChoice` out of the box.
public protocol DiscreteChoice: CaseIterable, Hashable, Codable, Sendable { }

/// A single gene that represents a discrete, categorical choice.
public struct DiscreteChoiceGene<C: DiscreteChoice, E: GeneticEnvironment>: Gene {
	public typealias Environment = E
	
	/// The gene's value.
	public var choice: C
	
	/// Creates a new gene with the given discrete value.
	public init(choice: C) {
		self.choice = choice
	}
	
	mutating public func mutate(rate: Double, environment: DiscreteChoiceGene<C, E>.Environment) throws {
		environment.randomSource.withGenerator { rng in
			guard Double.random(in: 0..<1, using: &rng) < rate else { return }
			mutateChoice(using: &rng)
		}
	}
	
	public static func mutateGenes(_ genes: inout [Self], rate: Double, environment: DiscreteChoiceGene<C, E>.Environment) throws {
		guard !genes.isEmpty else { return }
		environment.randomSource.withGenerator { rng in
			for i in 0..<genes.count {
				if Double.random(in: 0..<1, using: &rng) < rate {
					genes[i].mutateChoice(using: &rng)
				}
			}
		}
	}
	
	private mutating func mutateChoice(using rng: inout Xoshiro256PlusPlus) {
		// Select a new choice randomly without allocating a filtered array.
		let allCases = C.allCases
		let otherCount = allCases.count - 1
		guard otherCount > 0 else { return }
		var target = Int.random(in: 0..<otherCount, using: &rng)
		for candidate in allCases where candidate != choice {
			if target == 0 {
				choice = candidate
				return
			}
			target -= 1
		}
	}
	
	// MARK: - Coding.
	
	/// Coding keys for `Codable`.
	enum CodingKeys: String, CodingKey {
		case choice
	}
}

extension DiscreteChoiceGene: RawRepresentable {
	public typealias RawValue = C
	public var rawValue: RawValue { return choice }
	public init?(rawValue: RawValue) {
		self = DiscreteChoiceGene.init(choice: rawValue)
	}
}

