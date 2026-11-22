//
//  Population.swift
//  SwiftGenetics
//
//  Created by Santiago Gonzalez on 11/7/18.
//  Copyright © 2018 Santiago Gonzalez. All rights reserved.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

/// Defines broad types of genetic algorithms.
public enum EvolutionAlgorithmType: String, Codable, Sendable {
	/// A standard, single-objective genetic algorithm.
	case standard
    /// Nondominated Sorting Genetic Algorithm II (Multi-objective).
    case nsga2
}

/// A world of organisms, genericized by a type of genome.
public struct Population<G: Genome>: Codable, Sendable, Equatable {
	
	public typealias Environment = G.Environment
	
	/// The environment configuration that the population is subject to.
	public var environment: Environment
	
	/// The type of evolution that this population undergoes.
	public let evolutionType: EvolutionAlgorithmType
	
	/// The organisms in the world. Fit organisms are at the end when sorted.
	public var organisms: [Organism<G>] = []
	
	/// The current generation.
	public var generation = 0
	/// The best organism of all time.
	public var bestOrganism: Organism<G>?
	/// The best organism in the current generation.
	public var bestOrganismInGeneration: Organism<G>?
	
	/// The total fitness of all organisms in this generation.
	public var totalFitness: Double = 0.0
	/// This average fitness of this generation's organisms.
	public var averageFitness: Double = 0.0
	
	
	/// Creates a new, empty population with the given environment configuration.
	public init(environment: Environment, evolutionType: EvolutionAlgorithmType) {
		self.environment = environment
		self.evolutionType = evolutionType
	}
	
	// MARK: - Evolution
	
	/// Updates the population's fitness metrics for an epoch.
	public mutating func updateFitnessMetrics() {
		totalFitness = 0.0
		var highestSoFar = -Double.greatestFiniteMagnitude
		var lowestSoFar = Double.greatestFiniteMagnitude
		for organism in organisms {
			if let fitness = organism.fitness {
				if fitness > highestSoFar { // This is a better organism.
					highestSoFar = fitness
					bestOrganismInGeneration = organism
					// Check if we have a new best organism.
					if fitness > bestOrganism?.fitness ?? -Double.greatestFiniteMagnitude {
						bestOrganism = organism
					}
				}
				if fitness < lowestSoFar { // This is a worse organism.
					lowestSoFar = fitness
				}
				totalFitness += fitness
			}
		}
		averageFitness = organisms.isEmpty ? 0.0 : totalFitness / Double(organisms.count)
	}
	
	/// Performs an evolutionary epoch.
	mutating public func epoch() async throws {
        try Task.checkCancellation()
		// Get this generation's population.
		switch evolutionType {
		case .standard:
			// Sort existing population. Fit organisms are at the end.
			organisms.sort()
        case .nsga2:
            // NSGA-II sorts after evaluation, so we don't sort here.
            break
		}
		
		// Update the population's fitness metrics for the epoch.
		updateFitnessMetrics()
		
		// Create a new, empty population.
		var newOrganisms = [Organism<G>]()
		
        // Standard evolution replacements
        if evolutionType == .standard {
            // Perform elite sampling.
            newOrganisms.append(contentsOf: try elitesFromPopulation())
        }
		
		// Sample parents.
		let numberOfParents = (environment.populationSize - newOrganisms.count) + ((environment.populationSize - newOrganisms.count) % 2)
		var parents = [Organism<G>]()
		switch environment.selectionMethod {
		case .roulette:
			guard environment.selectableProportion == 1.0 else {
                throw GeneticError.unimplemented("Roulette sampling with selectableProportion != 1.0 is not yet supported.")
            }
			parents = try organismsFromRoulette(count: numberOfParents)
		case let .tournament(size: size):
			parents = try organismsFromTournament(size: size, count: numberOfParents)
		case let .truncation(takePortion: portion):
			guard !organisms.isEmpty else {
				throw GeneticError.evolutionFailed("Cannot sample from an empty population.")
			}
			let takeCount = Int(Double(organisms.count) * portion * environment.selectableProportion)
			guard takeCount > 0 else {
				throw GeneticError.configurationError("Truncation portion (\(portion)) and selectableProportion (\(environment.selectableProportion)) resulted in 0 selectable organisms.")
			}
			let topOrganisms = organisms.suffix(takeCount)
			parents.reserveCapacity(numberOfParents)
			while parents.count < numberOfParents {
				let remaining = numberOfParents - parents.count
				if remaining >= topOrganisms.count {
					parents.append(contentsOf: topOrganisms)
				} else {
					parents.append(contentsOf: topOrganisms.suffix(remaining))
				}
			}
        case .nsga2:
            // Use Crowded Tournament Selection for NSGA-II
            parents = try organismsFromCrowdedTournament(count: numberOfParents)
		}
		assert(parents.count == numberOfParents)
		
		// Reproduce until the population is the desired size.
		let matingCount = parents.count / 2
		let currentGeneration = generation
		let currentEnvironment = environment
		
		let progeny: [Organism<G>]
		let sequentialThreshold = 64
		if matingCount < sequentialThreshold {
			var localProgeny = [Organism<G>]()
			localProgeny.reserveCapacity(matingCount * 2)
			for i in 0..<matingCount {
				try Task.checkCancellation()
				let progenitorA = parents[i * 2]
				let progenitorB = parents[i * 2 + 1]
				let crossoverRate = progenitorA.genotype.individualCrossoverRate
					?? progenitorB.genotype.individualCrossoverRate
					?? currentEnvironment.crossoverRate
				var (progenyGenomeA, progenyGenomeB) = try progenitorA.genotype.crossover(with: progenitorB.genotype, rate: crossoverRate, environment: currentEnvironment)
				try Task.checkCancellation()
				try progenyGenomeA.mutate(rate: progenyGenomeA.individualMutationRate ?? currentEnvironment.mutationRate, environment: currentEnvironment)
				try progenyGenomeB.mutate(rate: progenyGenomeB.individualMutationRate ?? currentEnvironment.mutationRate, environment: currentEnvironment)
				localProgeny.append(Organism<G>(fitness: nil, genotype: progenyGenomeA, birthGeneration: currentGeneration))
				localProgeny.append(Organism<G>(fitness: nil, genotype: progenyGenomeB, birthGeneration: currentGeneration))
			}
			progeny = localProgeny
		} else {
			let processorCount = max(1, ProcessInfo.processInfo.activeProcessorCount)
			let chunkSize = max(1, (matingCount + processorCount - 1) / processorCount)
			let chunkRanges = Array(stride(from: 0, to: matingCount, by: chunkSize)).map { start in
				start..<min(start + chunkSize, matingCount)
			}
			// Pre-fork one RNG per chunk sequentially so child seeds are deterministic
			// and independent of task scheduling order.
			let forkedSources = (0..<chunkRanges.count).map { currentEnvironment.randomSource.fork(index: $0) }
			let immutableParents = parents
			
			progeny = try await withThrowingTaskGroup(of: (Int, [Organism<G>]).self) { group in
				for (chunkIndex, range) in chunkRanges.enumerated() {
					let chunkRandomSource = forkedSources[chunkIndex]
					group.addTask {
						var taskEnvironment = currentEnvironment
						taskEnvironment.randomSource = chunkRandomSource
						var chunkProgeny = [Organism<G>]()
						chunkProgeny.reserveCapacity(range.count * 2)
						
						for i in range {
							try Task.checkCancellation()
							let progenitorA = immutableParents[i * 2]
							let progenitorB = immutableParents[i * 2 + 1]
							let crossoverRate = progenitorA.genotype.individualCrossoverRate
								?? progenitorB.genotype.individualCrossoverRate
								?? taskEnvironment.crossoverRate
							var (progenyGenomeA, progenyGenomeB) = try progenitorA.genotype.crossover(with: progenitorB.genotype, rate: crossoverRate, environment: taskEnvironment)
							try Task.checkCancellation()
							try progenyGenomeA.mutate(rate: progenyGenomeA.individualMutationRate ?? taskEnvironment.mutationRate, environment: taskEnvironment)
							try progenyGenomeB.mutate(rate: progenyGenomeB.individualMutationRate ?? taskEnvironment.mutationRate, environment: taskEnvironment)
							chunkProgeny.append(Organism<G>(fitness: nil, genotype: progenyGenomeA, birthGeneration: currentGeneration))
							chunkProgeny.append(Organism<G>(fitness: nil, genotype: progenyGenomeB, birthGeneration: currentGeneration))
						}
						return (chunkIndex, chunkProgeny)
					}
				}
				
				var orderedChunks = [[Organism<G>]](repeating: [], count: chunkRanges.count)
				for try await (chunkIndex, chunkProgeny) in group {
					orderedChunks[chunkIndex] = chunkProgeny
				}
				
				var combined = [Organism<G>]()
				combined.reserveCapacity(matingCount * 2)
				for chunk in orderedChunks {
					combined.append(contentsOf: chunk)
				}
				return combined
			}
		}
        
        newOrganisms.append(contentsOf: progeny)
		
		// Replace the old population or expand for NSGA-II.
        if evolutionType == .nsga2 {
            // Combine parents and progeny (expansion to 2N)
            organisms.append(contentsOf: newOrganisms)
        } else {
            // In standard GA, if we have elites, newOrganisms already contains them.
            // We just need to ensure the count is correct.
            organisms = newOrganisms
        }
		generation += 1
	}
    
    /// Truncates the population to its desired size using NSGA-II sorting and ranking.
    /// Should be called after fitness evaluation.
    mutating public func truncateNSGA2() {
        guard evolutionType == .nsga2 else { return }
        organisms = NSGA2.sortAndTruncate(organisms, to: environment.populationSize)
    }
}
