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
    
    /// A cache for fitness results to avoid redundant evaluations.
    private let fitnessCache = FitnessCache<Eval.G>()
    
    /// Creates a new evolution wrapper.
    public init(fitnessEvaluator: Eval, loggingDelegate: LogDelegate) {
        self.fitnessEvaluator = fitnessEvaluator
        self.loggingDelegate = loggingDelegate
    }
    
    public func evolve(population: inout Population<Eval.G>, configuration: EvolutionAlgorithmConfiguration) async throws {
        try Task.checkCancellation()
        // CORRECTION: Ensure Generation 0 is evaluated before the loop begins.
        // Otherwise, the first selection step is random.
        if !population.organisms.isEmpty {
            let needsEval = population.organisms.contains { $0.fitness == nil && $0.objectives == nil }
            if needsEval {
                try await evaluatePopulation(&population, threads: configuration.parallelEvaluationThreads)
            }
        }
        
        for i in 0..<configuration.maxEpochs {
            try Task.checkCancellation()
            // Log start of epoch.
            loggingDelegate.evolutionStartingEpoch(i)
            let startDate = Date()
            
            // Perform an epoch (selection, crossover, and mutation).
            // Selection now has access to evaluated fitness/objectives.
            try await population.epoch()
            
            // Re-evaluate the new population (or the expanded population for NSGA-II).
            try await evaluatePopulation(&population, threads: configuration.parallelEvaluationThreads)
            
            try Task.checkCancellation()
            // If NSGA-II, perform survival selection (truncation back to N) after evaluation.
            if population.evolutionType == .nsga2 {
                population.truncateNSGA2()
            }
            
            try Task.checkCancellation()
            // Print epoch statistics.
            let elapsedInterval = Date().timeIntervalSince(startDate)
            loggingDelegate.evolutionFinishedEpoch(i, duration: elapsedInterval, population: population)
            
            // Execute epoch finished functions.
            for fn in afterEachEpochFns {
                try Task.checkCancellation()
                await fn(i)
            }
        }
        try Task.checkCancellation()
    }
    
    /// Concurrently evaluates the fitness or objectives of the population using task chunking.
    private func evaluatePopulation(_ population: inout Population<Eval.G>, threads: Int?) async throws {
        try Task.checkCancellation()
        let organisms = population.organisms
        let evolutionType = population.evolutionType
        let evaluator = self.fitnessEvaluator
        let cache = self.fitnessCache
        
        // Performance Note: Implemented Chunking (Batching).
        // Instead of one task per organism, we split the work across the number of active processors.
        // This reduces task scheduling overhead for large populations.
        let totalCount = organisms.count
        let processorCount = max(1, threads ?? ProcessInfo.processInfo.activeProcessorCount)
        let chunkSize = max(1, Int(ceil(Double(totalCount) / Double(processorCount))))
        
        try await withThrowingTaskGroup(of: [(Int, Double?, [Double]?)].self) { group in
            for startIndex in stride(from: 0, to: totalCount, by: chunkSize) {
                let endIndex = min(startIndex + chunkSize, totalCount)
                let organismSlice = Array(organisms[startIndex..<endIndex])
                
                group.addTask {
                    var chunkResults = [(Int, Double?, [Double]?)]()
                    chunkResults.reserveCapacity(organismSlice.count)
                    
                    // Collect organisms in this chunk that need evaluation.
                    var pendingIndices = [Int]()
                    var pendingOrganisms = [Organism<Eval.G>]()
                    var pendingGenomes = [Eval.G]()
                    pendingIndices.reserveCapacity(organismSlice.count)
                    pendingOrganisms.reserveCapacity(organismSlice.count)
                    pendingGenomes.reserveCapacity(organismSlice.count)
                    
                    for (offset, organism) in organismSlice.enumerated() {
                        try Task.checkCancellation()
                        if (evolutionType == .standard && organism.fitness != nil) ||
                           (evolutionType == .nsga2 && organism.objectives != nil) {
                            continue
                        }
                        pendingIndices.append(startIndex + offset)
                        pendingOrganisms.append(organism)
                        pendingGenomes.append(organism.genotype)
                    }
                    
                    guard !pendingOrganisms.isEmpty else {
                        return chunkResults
                    }
                    
                    if evolutionType == .nsga2 {
                        // Single batched lock acquisition to check cache for the entire chunk.
                        let cachedList = cache.objectivesList(for: pendingGenomes)
                        var localCache = [Eval.G: [Double]]()
                        var newCacheEntries = [(Eval.G, [Double])]()
                        
                        for i in 0..<pendingOrganisms.count {
                            try Task.checkCancellation()
                            let originalIndex = pendingIndices[i]
                            let genome = pendingGenomes[i]
                            if let cached = cachedList[i] ?? localCache[genome] {
                                chunkResults.append((originalIndex, cached.first, cached))
                                continue
                            }
                            do {
                                let objectives = try await evaluator.objectivesFor(organism: pendingOrganisms[i])
                                try Task.checkCancellation()
                                localCache[genome] = objectives
                                newCacheEntries.append((genome, objectives))
                                chunkResults.append((originalIndex, objectives.first, objectives))
                            } catch is CancellationError {
                                throw CancellationError()
                            } catch {
                                try Task.checkCancellation()
                                print("Error evaluating fitness for organism \(originalIndex): \(error)")
                                chunkResults.append((originalIndex, 0.0, nil))
                            }
                        }
                        
                        if !newCacheEntries.isEmpty {
                            cache.setObjectivesList(newCacheEntries)
                        }
                    } else {
                        // Single batched lock acquisition to check cache for the entire chunk.
                        let cachedList = cache.fitnesses(for: pendingGenomes)
                        var localCache = [Eval.G: Double]()
                        var newCacheEntries = [(Eval.G, Double)]()
                        
                        for i in 0..<pendingOrganisms.count {
                            try Task.checkCancellation()
                            let originalIndex = pendingIndices[i]
                            let genome = pendingGenomes[i]
                            if let cached = cachedList[i] ?? localCache[genome] {
                                chunkResults.append((originalIndex, cached, nil))
                                continue
                            }
                            do {
                                let fit = try await evaluator.fitnessFor(organism: pendingOrganisms[i])
                                try Task.checkCancellation()
                                localCache[genome] = fit
                                newCacheEntries.append((genome, fit))
                                chunkResults.append((originalIndex, fit, nil))
                            } catch is CancellationError {
                                throw CancellationError()
                            } catch {
                                try Task.checkCancellation()
                                print("Error evaluating fitness for organism \(originalIndex): \(error)")
                                chunkResults.append((originalIndex, 0.0, nil))
                            }
                        }
                        
                        if !newCacheEntries.isEmpty {
                            cache.setFitnesses(newCacheEntries)
                        }
                    }
                    return chunkResults
                }
            }
            
            for try await chunkResults in group {
                try Task.checkCancellation()
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
        
        try Task.checkCancellation()
        // Update statistics after evaluation so that the next epoch or logging has correct data.
        population.updateFitnessMetrics()
    }
    
    mutating public func afterEachEpoch(_ afterEachEpochFn: @escaping @Sendable (Int) async -> ()) {
        afterEachEpochFns.append(afterEachEpochFn)
    }
}