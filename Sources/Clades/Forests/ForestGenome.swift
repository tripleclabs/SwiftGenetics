//
//  ForestGenome.swift
//  SwiftGenetics
//
//  Created by Santiago Gonzalez on 6/11/19.
//  Copyright © 2019 Santiago Gonzalez. All rights reserved.
//

import Foundation

/// An evolvable forest of one or more independent trees.
/// Note: Forests have homogeneous gene types for now.
public struct ForestGenome<GeneType: TreeGeneType>: Genome {
	
	public typealias RealGene = TreeGenome<GeneType>
	public typealias Environment = RealGene.Environment
	
	/// The child trees in the forest.
	public var trees: [RealGene]
	
	/// Creates a new forest given trees.
	public init(trees: [RealGene]) {
		self.trees = trees
	}
	
	mutating public func mutate(rate: Double, environment: Environment) throws {
		// Mutate each tree individually.
		for idx in 0..<trees.count {
			try trees[idx].mutate(rate: rate, environment: environment)
		}
	}
	
	public func crossover(with partner: ForestGenome, rate: Double, environment: Environment) throws -> (ForestGenome, ForestGenome) {
		// Recombine each child individually, imagine how recombination works on chromosomes.
		var trees1 = [RealGene]()
		var trees2 = [RealGene]()
        
        let minCount = min(trees.count, partner.trees.count)
		for i in 0..<minCount {
            let (c1, c2) = try trees[i].crossover(with: partner.trees[i], rate: rate, environment: environment)
            trees1.append(c1)
            trees2.append(c2)
		}
		return (
			ForestGenome(trees: trees1),
			ForestGenome(trees: trees2)
		)
	}
	
	/// Returns a deep copy.
	public func copy() -> ForestGenome {
		return ForestGenome(trees: trees.map { $0.copy() })
	}
	
}

extension ForestGenome: RawRepresentable {
	public typealias RawValue = [RealGene]
	public var rawValue: RawValue { return trees }
	public init?(rawValue: RawValue) {
        // Warning: this is suboptimal as we don't have the template here.
        // We might want to pass it in or store it in the tree if we really need RawRepresentable.
        return nil
	}
}
