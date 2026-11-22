//
//  Population+Selection.swift
//  SwiftGenetics
//
//  Created by Santiago Gonzalez on 6/27/19.
//  Copyright © 2019 Santiago Gonzalez. All rights reserved.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

extension Population {
	
	/// Performs elite selection. This function assumes that organisms
	/// are sorted in ascending order.
	internal func elitesFromPopulation() throws -> [Organism<G>] {
		guard environment.numberOfEliteCopies * environment.numberOfElites % 2 == 0 else {
			throw GeneticError.configurationError("Must be an even number of elite copies for mating to work correctly.")
		}
		var elites = [Organism<G>]()
		for _ in 0..<environment.numberOfEliteCopies {
			elites.append(contentsOf: organisms.suffix(environment.numberOfElites))
		}
		return elites
	}
	
	/// Perform batch roulette sampling to get `count` organisms in O(n + count log n).
	internal func organismsFromRoulette(count: Int) throws -> [Organism<G>] {
		guard !organisms.isEmpty else {
			throw GeneticError.evolutionFailed("Cannot sample from an empty population.")
		}
		guard count > 0 else { return [] }
		let n = organisms.count
		var minFitness = Double.infinity
		for organism in organisms {
			let f = organism.fitness ?? 0.0
			if f < minFitness { minFitness = f }
		}
		let shift = minFitness < 0.0 ? -minFitness : 0.0
		var cumulativeWeights = [Double]()
		cumulativeWeights.reserveCapacity(n)
		var running = 0.0
		for organism in organisms {
			running += (organism.fitness ?? 0.0) + shift
			cumulativeWeights.append(running)
		}
		let totalWeight = running
		
		return environment.randomSource.withGenerator { rng in
			var selected = [Organism<G>]()
			selected.reserveCapacity(count)
			guard totalWeight > 0.0 else {
				for _ in 0..<count {
					selected.append(organisms[Int.random(in: 0..<n, using: &rng)])
				}
				return selected
			}
			for _ in 0..<count {
				let slice = Double.random(in: 0..<1, using: &rng) * totalWeight
				var lo = 0
				var hi = n - 1
				while lo < hi {
					let mid = lo + (hi - lo) / 2
					if cumulativeWeights[mid] < slice {
						lo = mid + 1
					} else {
						hi = mid
					}
				}
				selected.append(organisms[lo])
			}
			return selected
		}
	}
	
	/// Perform batch tournament sampling to get `count` organisms with a single lock acquisition.
	internal func organismsFromTournament(size: Int, count: Int) throws -> [Organism<G>] {
		guard !organisms.isEmpty else {
			throw GeneticError.evolutionFailed("Cannot sample from an empty population.")
		}
		guard count > 0 else { return [] }
		let selectableCount = Int(Double(organisms.count) * environment.selectableProportion)
		guard selectableCount > 0 else {
			throw GeneticError.configurationError("Selectable proportion resulted in 0 selectable organisms.")
		}
		let range = (organisms.count - selectableCount)..<organisms.count
		return environment.randomSource.withGenerator { rng in
			var selected = [Organism<G>]()
			selected.reserveCapacity(count)
			for _ in 0..<count {
				var bestIdx = Int.random(in: range, using: &rng)
				if size > 1 {
					for _ in 1..<size {
						let candidate = Int.random(in: range, using: &rng)
						if candidate > bestIdx {
							bestIdx = candidate
						}
					}
				}
				selected.append(organisms[bestIdx])
			}
			return selected
		}
	}
	
	/// Perform batch crowded tournament sampling for NSGA-II with a single lock acquisition.
	internal func organismsFromCrowdedTournament(count: Int) throws -> [Organism<G>] {
		guard !organisms.isEmpty else {
			throw GeneticError.evolutionFailed("Cannot sample from an empty population.")
		}
		guard count > 0 else { return [] }
		let n = organisms.count
		return environment.randomSource.withGenerator { rng in
			var selected = [Organism<G>]()
			selected.reserveCapacity(count)
			for _ in 0..<count {
				let p = organisms[Int.random(in: 0..<n, using: &rng)]
				let q = organisms[Int.random(in: 0..<n, using: &rng)]
				if p.dominanceRank < q.dominanceRank {
					selected.append(p)
				} else if q.dominanceRank < p.dominanceRank {
					selected.append(q)
				} else if p.crowdingDistance > q.crowdingDistance {
					selected.append(p)
				} else {
					selected.append(q)
				}
			}
			return selected
		}
	}
	
	/// Perform roulette sampling to get an organism.
	internal func organismFromRoulette() throws -> Organism<G> {
		guard !organisms.isEmpty else {
			throw GeneticError.evolutionFailed("Cannot sample from an empty population.")
		}
		var minFitness = Double.infinity
		for organism in organisms {
			let f = organism.fitness ?? 0.0
			if f < minFitness { minFitness = f }
		}
		let shift = minFitness < 0.0 ? -minFitness : 0.0
		var totalWeight = 0.0
		for organism in organisms {
			totalWeight += (organism.fitness ?? 0.0) + shift
		}
		guard totalWeight > 0.0 else {
			return environment.randomSource.randomElement(from: organisms)!
		}
		let slice = environment.randomSource.randomDouble() * totalWeight
		var cumulativeWeight = 0.0
		for organism in organisms {
			cumulativeWeight += (organism.fitness ?? 0.0) + shift
			if cumulativeWeight >= slice {
				return organism
			}
		}
		return organisms.last!
	}
	
	/// Perform tournament sampling to get an organism.
	internal func organismFromTournament(size: Int) throws -> Organism<G> {
		guard !organisms.isEmpty else {
			throw GeneticError.evolutionFailed("Cannot sample from an empty population.")
		}
		let selectableCount = Int(Double(organisms.count) * environment.selectableProportion)
		guard selectableCount > 0 else {
			throw GeneticError.configurationError("Selectable proportion resulted in 0 selectable organisms.")
		}
		let playerIndices = (0..<size).map { _ in environment.randomSource.randomInt(in: (organisms.count - selectableCount)..<organisms.count) }
		return organisms[playerIndices.max()!]
	}
    
    /// Perform crowded tournament sampling for NSGA-II.
    internal func organismFromCrowdedTournament() throws -> Organism<G> {
        guard !organisms.isEmpty else {
            throw GeneticError.evolutionFailed("Cannot sample from an empty population.")
        }
        
        let i = environment.randomSource.randomInt(in: 0..<organisms.count)
        let j = environment.randomSource.randomInt(in: 0..<organisms.count)
        let p = organisms[i]
        let q = organisms[j]
        
        // Crowded-comparison operator
        if p.dominanceRank < q.dominanceRank {
            return p
        } else if q.dominanceRank < p.dominanceRank {
            return q
        } else if p.crowdingDistance > q.crowdingDistance {
            return p
        } else {
            return q
        }
    }
	
}
