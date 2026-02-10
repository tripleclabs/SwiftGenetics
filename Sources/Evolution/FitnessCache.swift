//
//  FitnessCache.swift
//  SwiftGenetics
//
//  Created by Triple C Labs GmbH 10/02/2026.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

/// A thread-safe actor that caches fitness evaluation results based on genome hash.
/// This avoid redundant, expensive evaluations for identical genomes.
public actor FitnessCache<G: Genome> {
    
    private var singleCache: [G: Double] = [:]
    private var multiCache: [G: [Double]] = [:]
    
    public init() {}
    
    /// Returns the cached single fitness value for the given genome, if any.
    public func fitness(for genome: G) -> Double? {
        return singleCache[genome]
    }
    
    /// Returns the cached objective values for the given genome, if any.
    public func objectives(for genome: G) -> [Double]? {
        return multiCache[genome]
    }
    
    /// Caches a single fitness value for the given genome.
    public func setFitness(_ fitness: Double, for genome: G) {
        singleCache[genome] = fitness
    }
    
    /// Caches objective values for the given genome.
    public func setObjectives(_ objectives: [Double], for genome: G) {
        multiCache[genome] = objectives
    }
    
    /// Clears all cached results.
    public func clear() {
        singleCache = [:]
        multiCache = [:]
    }
}
