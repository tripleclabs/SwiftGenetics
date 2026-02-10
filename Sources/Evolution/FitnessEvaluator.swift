//
//  FitnessEvaluator.swift
//  SwiftGenetics
//
//  Created by Santiago Gonzalez on 11/19/18.
//  Copyright © 2018 Santiago Gonzalez. All rights reserved.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

/// Implemented by types that can evaluate fitnesses for an associated genome.
public protocol FitnessEvaluator: Sendable {
    associatedtype G: Genome
    
    /// Returns the fitness value for a given organism. Larger fitnesses are better.
    /// Marked async to allow for heavy calculations or remote calls.
    func fitnessFor(organism: Organism<G>) async throws -> Double
    
    /// Returns the objective values for a given organism.
    /// Default implementation wraps the single fitness value as a single objective.
    func objectivesFor(organism: Organism<G>) async throws -> [Double]
}

extension FitnessEvaluator {
    public func objectivesFor(organism: Organism<G>) async throws -> [Double] {
        return [try await fitnessFor(organism: organism)]
    }
}

/// The result from an organism's fitness evaluation.
public struct FitnessResult {
	public var fitness: Double
    /// Multiple objective values for NSGA-II.
    public var objectives: [Double]

	/// Creates a new fitness result from a single fitness metric.
	public init(fitness: Double) {
		self.fitness = fitness
        self.objectives = [fitness]
	}
    
    /// Creates a new fitness result from multiple objective metrics.
    public init(objectives: [Double]) {
        self.objectives = objectives
        self.fitness = objectives.first ?? 0.0
    }
}
