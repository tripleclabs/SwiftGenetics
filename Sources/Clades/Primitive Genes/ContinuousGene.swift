//
//  ContinuousGene.swift
//  SwiftGenetics
//
//  Created by Santiago Gonzalez on 10/25/19.
//  Copyright © 2019 Santiago Gonzalez. All rights reserved.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

/// The types of mutations that can be performed on a real-valued gene.
public enum ContinuousMutationType: String {
	/// Add a sample from a uniform distribution, centered at zero, to the value.
	case uniform
	/// Add a sample from a Gaussian distribution, centered at zero, to the value.
	case gaussian
}

/// Keys to the environment's parameters dictionary that a real-valued gene uses.
public enum ContinuousEnvironmentParameter: String {
	/// How large should mutations be.
	case mutationSize // Double
	/// The type of mutations that are performed.
	case mutationType // MutationType
}

/// Represents a single continuous value that can be evolved.
public struct ContinuousGene<R: FloatingPoint & Hashable & Sendable, E: GeneticEnvironment>: Gene, Equatable, Hashable {
	public typealias Environment = E
	public typealias Param = ContinuousEnvironmentParameter
	
	/// The gene's value.
	public var value: R
	
	/// Creates a new gene with the given value.
	public init(value: R) {
		self.value = value
	}
	
	@inlinable
	mutating public func mutate(rate: Double, environment: ContinuousGene<R, E>.Environment) throws {
		let (mutationSize, mutationType) = Self.resolveMutationParameters(from: environment)
		try environment.randomSource.withGenerator { rng in
			guard Double.random(in: 0..<1, using: &rng) < rate else { return }
			try mutateValue(mutationSize: mutationSize, mutationType: mutationType, using: &rng)
		}
	}
	
	@inlinable
	public static func mutateGenes(_ genes: inout [Self], rate: Double, environment: ContinuousGene<R, E>.Environment) throws {
		guard !genes.isEmpty else { return }
		// Hoist dictionary parameter lookups and RNG lock acquisition out of the per-gene loop.
		let (mutationSize, mutationType) = resolveMutationParameters(from: environment)
		try environment.randomSource.withGenerator { rng in
			for i in 0..<genes.count {
				if Double.random(in: 0..<1, using: &rng) < rate {
					try genes[i].mutateValue(mutationSize: mutationSize, mutationType: mutationType, using: &rng)
				}
			}
		}
	}
	
	@inlinable
	internal static func resolveMutationParameters(from environment: E) -> (Double, ContinuousMutationType) {
		let mutationSize = (environment.parameters[Param.mutationSize.rawValue]?.value as? Double) ?? 0.1
		let mutationType: ContinuousMutationType
		if let rawMutationType = environment.parameters[Param.mutationType.rawValue]?.value as? String,
		   let type = ContinuousMutationType(rawValue: rawMutationType) {
			mutationType = type
		} else {
			mutationType = .uniform
		}
		return (mutationSize, mutationType)
	}
	
	@inlinable
	internal mutating func mutateValue(mutationSize: Double, mutationType: ContinuousMutationType, using rng: inout Xoshiro256PlusPlus) throws {
		switch mutationType {
		case .uniform:
			value += try ContinuousGene.genericize(Double.random(in: (-mutationSize)...mutationSize, using: &rng))
		case .gaussian:
			value += try ContinuousGene.genericize(RandomSource.sampleGaussian(mu: 0.0, sigma: mutationSize, using: &rng))
		}
	}
	
	/// Converts the input `Double` into the gene's generic floating-point type.
	/// This is slightly ugly, but I can't think of a cleaner way to do this.
	@inlinable
	internal static func genericize(_ num: Double) throws -> R {
		switch R.self {
		case is Float.Type:
			return Float(num) as! R
		#if arch(x86_64)
		case is Float80.Type:
			return Float80(num) as! R
		#endif
		case is Double.Type:
			return num as! R
		default:
			throw GeneticError.unexpectedType("Unhandled floating-point type: \(R.self)")
		}
	}
	
	// MARK: - Comparability.
	
	@inlinable
	public static func == (lhs: ContinuousGene, rhs: ContinuousGene) -> Bool {
		return lhs.value == rhs.value // TODO: maybe this could cause issues, bad to compare IEEE float equality...
	}

	@inlinable
	public func hash(into hasher: inout Hasher) {
		hasher.combine(value)
	}
	
	// MARK: - Coding.
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		switch R.self {
		case is Float.Type:
			try container.encode(value as! Float)
		case is Double.Type:
			try container.encode(value as! Double)
		default:
			throw GeneticError.unexpectedType("Unhandled floating-point type: \(R.self)")
		}
	}
	
	public init(from decoder: Decoder) throws {
		let values = try decoder.singleValueContainer()
		switch R.self {
		case is Float.Type:
			value = try ContinuousGene.genericize(Double(values.decode(Float.self)))
		case is Double.Type:
			value = try ContinuousGene.genericize(values.decode(Double.self))
		default:
			throw GeneticError.unexpectedType("Unhandled floating-point type: \(R.self)")
		}
	}
}
