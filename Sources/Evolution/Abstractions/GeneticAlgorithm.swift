//
//  GeneticAlgorithm.swift
//  SwiftGenetics
//
//  Created by Triple C Labs GmbH 10/02/2026.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

/// Encapsulates a generic genetic algorithm that performs fitness evaluations concurrently
/// using Swift Structured Concurrency.
public struct GeneticAlgorithm<Eval: FitnessEvaluator, LogDelegate: EvolutionLoggingDelegate>: EvolutionWrapper where Eval.G == LogDelegate.G {
    
    public let fitnessEvaluator: Eval
    public var afterEachEpochFns = [@Sendable (Int) async -> ()]()
    
    /// A delegate for logging information from the GA.
    private let loggingDelegate: LogDelegate
    
    /// Creates a new evolution wrapper.
    public init(fitnessEvaluator: Eval, loggingDelegate: LogDelegate) {
        self.fitnessEvaluator = fitnessEvaluator
        self.loggingDelegate = loggingDelegate
    }
    
    public func evolve(population: inout Population<Eval.G>, configuration: EvolutionAlgorithmConfiguration) async throws {
        for i in 0..<configuration.maxEpochs {
            // Log start of epoch.
            loggingDelegate.evolutionStartingEpoch(i)
            let startDate = Date()
            
            // Perform an epoch (mutation/crossover/selection).
            try population.epoch()
            
            // Calculate fitnesses concurrently using TaskGroup
            let organisms = population.organisms
            let evolutionType = population.evolutionType
            await withTaskGroup(of: (Int, Double?, [Double]?).self) { group in
                for (index, organism) in organisms.enumerated() {
                    // Only evaluate if fitness/objectives are nil
                    if (evolutionType == .standard && organism.fitness == nil) || (evolutionType == .nsga2 && organism.objectives == nil) {
                        let evaluator = self.fitnessEvaluator
                        // Capture explicitly for Sendable closure
                        group.addTask {
                            do {
                                if evolutionType == .nsga2 {
                                    let objectives = try await evaluator.objectivesFor(organism: organism)
                                    return (index, objectives.first, objectives)
                                } else {
                                    let fit = try await evaluator.fitnessFor(organism: organism)
                                    return (index, fit, nil)
                                }
                            } catch {
                                print("Error evaluating fitness: \(error)")
                                return (index, 0.0, nil) // Handle error appropriately
                            }
                        }
                    }
                }
                
                // Collect results locally
                var results = [(Int, Double?, [Double]?)]()
                for await result in group {
                    results.append(result)
                }
                
                // Now apply results to population
                for (index, fitness, objectives) in results {
                    if let fitness = fitness {
                        population.organisms[index].fitness = fitness
                    }
                    if let objectives = objectives {
                        population.organisms[index].objectives = objectives
                    }
                    // Check for solution callback logic if needed
                    loggingDelegate.evolutionFoundSolution(population.organisms[index].genotype, fitness: fitness ?? (objectives?.first ?? 0.0))
                }
            }
            
            // If NSGA-II, perform survival selection (truncation back to N) after evaluation.
            if evolutionType == .nsga2 {
                population.truncateNSGA2()
            }
            
            // Print epoch statistics.
            let elapsedInterval = Date().timeIntervalSince(startDate)
            loggingDelegate.evolutionFinishedEpoch(i, duration: elapsedInterval, population: population)
            
            // Execute epoch finished functions.
            for fn in afterEachEpochFns {
                await fn(i)
            }
        }
    }
    
    mutating public func afterEachEpoch(_ afterEachEpochFn: @escaping @Sendable (Int) async -> ()) {
        afterEachEpochFns.append(afterEachEpochFn)
    }
}