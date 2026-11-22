//
//  FitnessCache.swift
//  SwiftGenetics
//
//  Created by Triple C Labs GmbH 10/02/2026.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation
import Synchronization

/// A thread-safe cache for fitness evaluation results based on genome hash.
/// Uses a `Synchronization.Mutex`-protected two-generation bounded cache to avoid
/// actor-hop overhead and prevent unbounded memory growth while retaining cross-generation hits.
public final class FitnessCache<G: Genome>: Sendable {
    
    @usableFromInline
    internal struct Storage: Sendable {
        @usableFromInline var currentSingle: [G: Double] = [:]
        @usableFromInline var previousSingle: [G: Double] = [:]
        @usableFromInline var currentMulti: [G: [Double]] = [:]
        @usableFromInline var previousMulti: [G: [Double]] = [:]
        
        @usableFromInline init() {}
    }
    
    /// Maximum approximate number of entries retained per cache (single / multi).
    public let maxEntries: Int
    
    @usableFromInline internal let bucketLimit: Int
    @usableFromInline internal let storage: Mutex<Storage>
    
    @inlinable
    public init(maxEntries: Int = 50_000) {
        let clamped = max(2, maxEntries)
        self.maxEntries = clamped
        self.bucketLimit = max(1, clamped / 2)
        self.storage = Mutex(Storage())
    }
    
    /// Returns the cached single fitness value for the given genome, if any.
    @inlinable
    public func fitness(for genome: G) -> Double? {
        storage.withLock { s in
            s.currentSingle[genome] ?? s.previousSingle[genome]
        }
    }
    
    /// Batch lookup for single fitness values to amortize lock overhead per chunk.
    @inlinable
    public func fitnesses(for genomes: [G]) -> [Double?] {
        storage.withLock { s in
            var results = [Double?]()
            results.reserveCapacity(genomes.count)
            for genome in genomes {
                results.append(s.currentSingle[genome] ?? s.previousSingle[genome])
            }
            return results
        }
    }
    
    /// Returns the cached objective values for the given genome, if any.
    @inlinable
    public func objectives(for genome: G) -> [Double]? {
        storage.withLock { s in
            s.currentMulti[genome] ?? s.previousMulti[genome]
        }
    }
    
    /// Batch lookup for multi-objective values to amortize lock overhead per chunk.
    @inlinable
    public func objectivesList(for genomes: [G]) -> [[Double]?] {
        storage.withLock { s in
            var results = [[Double]?]()
            results.reserveCapacity(genomes.count)
            for genome in genomes {
                results.append(s.currentMulti[genome] ?? s.previousMulti[genome])
            }
            return results
        }
    }
    
    /// Caches a single fitness value for the given genome.
    @inlinable
    public func setFitness(_ fitness: Double, for genome: G) {
        let limit = bucketLimit
        storage.withLock { s in
            if s.currentSingle.count >= limit && s.currentSingle[genome] == nil {
                s.previousSingle = s.currentSingle
                s.currentSingle = [:]
            }
            s.currentSingle[genome] = fitness
        }
    }
    
    /// Batch insert for single fitness values to amortize lock overhead per chunk.
    @inlinable
    public func setFitnesses(_ entries: [(G, Double)]) {
        let limit = bucketLimit
        storage.withLock { s in
            for (genome, fitness) in entries {
                if s.currentSingle.count >= limit && s.currentSingle[genome] == nil {
                    s.previousSingle = s.currentSingle
                    s.currentSingle = [:]
                }
                s.currentSingle[genome] = fitness
            }
        }
    }
    
    /// Caches objective values for the given genome.
    @inlinable
    public func setObjectives(_ objectives: [Double], for genome: G) {
        let limit = bucketLimit
        storage.withLock { s in
            if s.currentMulti.count >= limit && s.currentMulti[genome] == nil {
                s.previousMulti = s.currentMulti
                s.currentMulti = [:]
            }
            s.currentMulti[genome] = objectives
        }
    }
    
    /// Batch insert for multi-objective values to amortize lock overhead per chunk.
    @inlinable
    public func setObjectivesList(_ entries: [(G, [Double])]) {
        let limit = bucketLimit
        storage.withLock { s in
            for (genome, objectives) in entries {
                if s.currentMulti.count >= limit && s.currentMulti[genome] == nil {
                    s.previousMulti = s.currentMulti
                    s.currentMulti = [:]
                }
                s.currentMulti[genome] = objectives
            }
        }
    }
    
    /// Clears all cached results.
    @inlinable
    public func clear() {
        storage.withLock { s in
            s.currentSingle = [:]
            s.previousSingle = [:]
            s.currentMulti = [:]
            s.previousMulti = [:]
        }
    }
}
