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
	
	/// Perform roulette sampling to get an organism.
	internal func organismFromRoulette() throws -> Organism<G> {
		guard !organisms.isEmpty else {
			throw GeneticError.evolutionFailed("Cannot sample from an empty population.")
		}
		guard totalFitness != 0 else {
			return organisms.randomElement()!
		}
		let slice = totalFitness > 0 ? Double.random(in: 0..<1) * totalFitness : 0.0
		var cumulativeFitness = 0.0
		for organism in organisms {
			cumulativeFitness += organism.fitness ?? 0.0
			if cumulativeFitness >= slice {
				return organism
			}
		}
		return organisms.first!
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
		let playerIndices = (0..<size).map { _ in Int.random(in: (organisms.count - selectableCount)..<organisms.count) }
		return organisms[playerIndices.max()!]
	}
	
}
