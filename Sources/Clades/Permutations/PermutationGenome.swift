//
//  PermutationGenome.swift
//  SwiftGenetics
//
//  Created by Triple C Labs GmbH
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

/// A genome representing a unique ordering of elements (a permutation).
/// Useful for TSP, Scheduling, and Ordering problems.
public struct PermutationGenome<T: Codable & Hashable & Sendable>: Genome, Sendable {
    
    public typealias Environment = PermutationEnvironment
    
    /// The ordered sequence of elements.
    public var elements: [T]
    
    /// Creates a new genome with a specific order.
    public init(elements: [T]) {
        self.elements = elements
    }
    
    /// Mutates the order by swapping two random elements.
    /// This preserves the uniqueness of the set (in-place mutation).
    @inlinable
    public mutating func mutate(rate: Double, environment: Environment) {
        environment.randomSource.withGenerator { rng in
            guard Double.random(in: 0..<1, using: &rng) < rate else { return }
            guard elements.count > 1 else { return }
            let idx1 = Int.random(in: 0..<elements.count, using: &rng)
            let idx2 = Int.random(in: 0..<elements.count, using: &rng)
            elements.swapAt(idx1, idx2)
        }
    }
    
    /// Performs Order Crossover (OX1) to produce valid permutations.
    @inlinable
    public func crossover(with partner: PermutationGenome<T>, rate: Double, environment: Environment) -> (PermutationGenome<T>, PermutationGenome<T>) {
        return environment.randomSource.withGenerator { rng in
            guard Double.random(in: 0..<1, using: &rng) < rate else { return (self, partner) }
            guard self.elements.count > 1 else { return (self, partner) }
            
            // Helper function for OX1 Crossover
            func performOX1(parent1: [T], parent2: [T], using rng: inout Xoshiro256PlusPlus) -> [T] {
                let size = parent1.count
                let p1 = Int.random(in: 0..<(size - 1), using: &rng)
                let p2 = Int.random(in: (p1 + 1)..<size, using: &rng)
                
                // 1. Copy a slice from Parent 1
                var child = Array<T?>(repeating: nil, count: size)
                // O(1) expected membership checks instead of scanning the copied
                // segment for each candidate. Never iterate this set: parent order
                // and random-source consumption remain exactly the same as OX1.
                let copiedElements = Set(parent1[p1...p2])
                for i in p1...p2 {
                    child[i] = parent1[i]
                }
                
                // 2. Fill the remaining spots with order from Parent 2
                var currentP2Index = (p2 + 1) % size
                var currentChildIndex = (p2 + 1) % size
                
                while currentChildIndex != p1 {
                    let candidate = parent2[currentP2Index]
                    if !copiedElements.contains(candidate) {
                        child[currentChildIndex] = candidate
                        currentChildIndex = (currentChildIndex + 1) % size
                    }
                    currentP2Index = (currentP2Index + 1) % size
                }
                
                return child.map { $0! }
            }
            
            let child1 = performOX1(parent1: self.elements, parent2: partner.elements, using: &rng)
            let child2 = performOX1(parent1: partner.elements, parent2: self.elements, using: &rng)
            
            return (PermutationGenome(elements: child1), PermutationGenome(elements: child2))
        }
    }
}

// MARK: - Environment

public struct PermutationEnvironment: GeneticEnvironment {
    public var populationSize: Int
    public var selectionMethod: SelectionMethod
    public var selectableProportion: Double
    public var mutationRate: Double
    public var crossoverRate: Double
    public var numberOfElites: Int
    public var numberOfEliteCopies: Int
    public var parameters: [String : AnyCodable]
    public var randomSource: RandomSource
    
    public init(
        populationSize: Int = 100,
        selectionMethod: SelectionMethod = .tournament(size: 3),
        selectableProportion: Double = 1.0,
        mutationRate: Double = 0.05,
        crossoverRate: Double = 0.8,
        numberOfElites: Int = 2,
        numberOfEliteCopies: Int = 1,
        randomSource: RandomSource = RandomSource(seed: UInt64.random(in: 0...UInt64.max))
    ) {
        self.populationSize = populationSize
        self.selectionMethod = selectionMethod
        self.selectableProportion = selectableProportion
        self.mutationRate = mutationRate
        self.crossoverRate = crossoverRate
        self.numberOfElites = numberOfElites
        self.numberOfEliteCopies = numberOfEliteCopies
        self.parameters = [:]
        self.randomSource = randomSource
    }
}