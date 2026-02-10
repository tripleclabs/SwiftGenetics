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
        // CORRECTION: Ensure Generation 0 is evaluated before the loop begins.
        // Otherwise, the first selection step is random.
        if !population.organisms.isEmpty {
            let needsEval = population.organisms.contains { $0.fitness == nil && $0.objectives == nil }
            if needsEval {
                await evaluatePopulation(&population)
            }
        }
        
        for i in 0..<configuration.maxEpochs {
            // Log start of epoch.
            loggingDelegate.evolutionStartingEpoch(i)
            let startDate = Date()
            
            // Perform an epoch (selection, crossover, and mutation).
            // Selection now has access to evaluated fitness/objectives.
            try population.epoch()
            
            // Re-evaluate the new population (or the expanded population for NSGA-II).
            await evaluatePopulation(&population)
            
            // If NSGA-II, perform survival selection (truncation back to N) after evaluation.
            if population.evolutionType == .nsga2 {
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
    
    /// Concurrently evaluates the fitness or objectives of the population using task chunking.
    private func evaluatePopulation(_ population: inout Population<Eval.G>) async {
        let organisms = population.organisms
        let evolutionType = population.evolutionType
        let evaluator = self.fitnessEvaluator
        
        // Performance Note: Implemented Chunking (Batching).
        // Instead of one task per organism, we split the work across the number of active processors.
        // This reduces task scheduling overhead for large populations.
        let totalCount = organisms.count
        let processorCount = ProcessInfo.processInfo.activeProcessorCount
        let chunkSize = max(1, Int(ceil(Double(totalCount) / Double(processorCount))))
        
        await withTaskGroup(of: [(Int, Double?, [Double]?)].self) { group in
            for startIndex in stride(from: 0, to: totalCount, by: chunkSize) {
                let endIndex = min(startIndex + chunkSize, totalCount)
                let organismSlice = Array(organisms[startIndex..<endIndex])
                
                group.addTask {
                    var chunkResults = [(Int, Double?, [Double]?)]()
                    chunkResults.reserveCapacity(organismSlice.count)
                    
                    for (offset, organism) in organismSlice.enumerated() {
                        let originalIndex = startIndex + offset
                        
                        // Skip if already evaluated
                        if (evolutionType == .standard && organism.fitness != nil) ||
                           (evolutionType == .nsga2 && organism.objectives != nil) {
                            continue
                        }
                        
                        do {
                            if evolutionType == .nsga2 {
                                let objectives = try await evaluator.objectivesFor(organism: organism)
                                chunkResults.append((originalIndex, objectives.first, objectives))
                            } else {
                                let fit = try await evaluator.fitnessFor(organism: organism)
                                chunkResults.append((originalIndex, fit, nil))
                            }
                        } catch {
                            print("Error evaluating fitness for organism \(originalIndex): \(error)")
                            chunkResults.append((originalIndex, 0.0, nil))
                        }
                    }
                    return chunkResults
                }
            }
            
            for await chunkResults in group {
                for (index, fitness, objectives) in chunkResults {
                    if let fitness = fitness {
                        population.organisms[index].fitness = fitness
                    }
                    if let objectives = objectives {
                        population.organisms[index].objectives = objectives
                    }
                    loggingDelegate.evolutionFoundSolution(population.organisms[index].genotype, fitness: fitness ?? (objectives?.first ?? 0.0))
                }
            }
        }
        
        // Update statistics after evaluation so that the next epoch or logging has correct data.
        population.updateFitnessMetrics()
    }
    
    mutating public func afterEachEpoch(_ afterEachEpochFn: @escaping @Sendable (Int) async -> ()) {
        afterEachEpochFns.append(afterEachEpochFn)
    }
}