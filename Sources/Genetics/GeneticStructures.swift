//
//  GeneticStructures.swift
//  SwiftGenetics
//
//  Created by Santiago Gonzalez on 11/7/18.
//  Copyright © 2018 Santiago Gonzalez. All rights reserved.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

/// An environment where evolution takes place.
public protocol GeneticEnvironment: GeneticConstants, Sendable, Codable, Equatable { }

/// Implemented by structures that have an associated genetic environment.
public protocol GeneticEnvironmentAssociable {
    associatedtype Environment: GeneticEnvironment
}

/// An individual genetic element.
public protocol Gene: Mutatable, Codable, Sendable, Hashable {
    /// Mutates a slice/array of genes in batch. Types can override this to hoist
    /// environment parameter lookups and amortize RNG lock acquisitions across a genome.
    static func mutateGenes(_ genes: inout [Self], rate: Double, environment: Environment) throws
}

extension Gene {
    public static func mutateGenes(_ genes: inout [Self], rate: Double, environment: Environment) throws {
        for i in 0..<genes.count {
            try genes[i].mutate(rate: rate, environment: environment)
        }
    }
}

/// A collection of genes.
public protocol Genome: Mutatable, Crossoverable, Codable, Sendable, Hashable {
    /// Individual-specific mutation rate, or `nil` to use the environment's default.
    var individualMutationRate: Double? { get }
    /// Individual-specific crossover rate, or `nil` to use the environment's default.
    var individualCrossoverRate: Double? { get }
}

extension Genome {
    public var individualMutationRate: Double? { nil }
    public var individualCrossoverRate: Double? { nil }
}

/// Represents a specific, individual organism with a fitness and genome.
/// - Note: Refactored to a struct for Swift 6 Sendable safety.
public struct Organism<G: Genome>: Codable, Sendable, Identifiable {
    
    /// A unique identifier for this organism.
    public let id: UUID
    /// This organism's fitness value, or `nil` if it is unknown.
    public var fitness: Double?
    /// The organism's genotype.
    public var genotype: G
    /// The generation that this organism was created in, or -1.
    public var birthGeneration: Int
    
    // MARK: - Multi-Objective Metadata (NSGA-II)
    
    /// This organism's objective fitness values, or `nil` if unknown.
    /// Higher values are assumed to be better (maximization) in NSGA-II.
    public var objectives: [Double]?
    /// The dominance rank (front index) in NSGA-II.
    public var dominanceRank: Int = 0
    /// The crowding distance used for diversity preservation.
    public var crowdingDistance: Double = 0.0
    
    /// Creates a new organism.
    public init(fitness: Double? = nil, genotype: G, birthGeneration: Int = -1) {
        self.id = UUID()
        self.fitness = fitness
        self.genotype = genotype
        self.birthGeneration = birthGeneration
        self.objectives = nil
        self.dominanceRank = 0
        self.crowdingDistance = 0.0
    }
}

// Allows organisms to be compared by their fitnesses.
extension Organism: Comparable {
    public static func < (lhs: Organism<G>, rhs: Organism<G>) -> Bool {
        // Establish a strict weak ordering: `nil` and `NaN` sort lowest so
        // unevaluated or invalid organisms never outrank evaluated ones or break `Array.sort()`.
        let lValid = lhs.fitness.flatMap { $0.isNaN ? nil : $0 }
        let rValid = rhs.fitness.flatMap { $0.isNaN ? nil : $0 }
        switch (lValid, rValid) {
        case (nil, nil):
            return false
        case (nil, .some):
            return true
        case (.some, nil):
            return false
        case let (.some(l), .some(r)):
            return l < r
        }
    }
    
    public static func == (lhs: Organism<G>, rhs: Organism<G>) -> Bool {
        return lhs.fitness == rhs.fitness && lhs.id == rhs.id
    }
}

extension Organism: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Errors that can occur during genetic operations.
public enum GeneticError: Error, Sendable, LocalizedError {
    case unimplemented(String)
    case invalidParameter(String)
    case configurationError(String)
    case evolutionFailed(String)
    case unexpectedType(String)
    case decodingError(String)
    
    public var errorDescription: String? {
        switch self {
        case .unimplemented(let msg): return "Unimplemented: \(msg)"
        case .invalidParameter(let msg): return "Invalid parameter: \(msg)"
        case .configurationError(let msg): return "Configuration error: \(msg)"
        case .evolutionFailed(let msg): return "Evolution failed: \(msg)"
        case .unexpectedType(let msg): return "Unexpected type: \(msg)"
        case .decodingError(let msg): return "Decoding error: \(msg)"
        }
    }
}