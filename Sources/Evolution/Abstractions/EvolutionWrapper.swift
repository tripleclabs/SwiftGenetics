//
//  EvolutionWrapper.swift
//  SwiftGenetics
//
//  Created by Santiago Gonzalez on 7/3/19.
//  Copyright © 2019 Santiago Gonzalez. All rights reserved.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

/// The high-level configuration for a GA. Hyperparameters that are too broad to be considered part of a
/// `GeneticEnvironment` are included here.
public struct EvolutionAlgorithmConfiguration {
	public let maxEpochs: Int
	public let algorithmType: EvolutionAlgorithmType
	
	/// Creates a new EA configruation.
	public init(maxEpochs: Int, algorithmType: EvolutionAlgorithmType) {
		self.maxEpochs = maxEpochs
		self.algorithmType = algorithmType
	}
}

/// Implemented by types that can be evolved.
public protocol EvolutionWrapper: Sendable {
	associatedtype Eval: FitnessEvaluator
	
	/// The fitness evaluator that the GA uses.
	var fitnessEvaluator: Eval { get }
	/// Runs evolution on the given start population, for a maximum number of epochs.
	func evolve(population: inout Population<Eval.G>, configuration: EvolutionAlgorithmConfiguration) async
	
	/// The functions that are called after each epoch.
	var afterEachEpochFns: [@Sendable (Int) async -> ()] { get set }
	
	/// Calls the passed function after each epoch. The function takes the completed generation's number.
	/// - Note: This function just provides syntactic sugar.
	mutating func afterEachEpoch(_ afterEachEpochFn: @escaping @Sendable (Int) async -> ())
}

extension EvolutionWrapper {
	mutating public func afterEachEpoch(_ afterEachEpochFn: @escaping @Sendable (Int) async -> ()) {
		afterEachEpochFns.append(afterEachEpochFn)
	}
}
