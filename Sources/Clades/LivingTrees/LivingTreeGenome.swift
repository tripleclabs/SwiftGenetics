//
//  LivingTreeGenome.swift
//  SwiftGenetics
//
//  Created by Santiago Gonzalez on 6/28/19.
//  Copyright © 2019 Santiago Gonzalez. All rights reserved.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

/// An evolvable tree.
public struct LivingTreeGenome<GeneType: TreeGeneType>: Genome {
	
	public typealias RealGene = LivingTreeGene<GeneType>
	
	/// The tree's root gene.
	public var rootGene: RealGene
	
	/// Creates a new genome with the given tree root.
	public init(rootGene: RealGene) {
		self.rootGene = rootGene
	}
	
	mutating public func mutate(rate: Double, environment: Environment) throws {
		try rootGene.bottomUpEnumerate { gene in
			try gene.mutate(rate: rate, environment: environment)
		}
	}
	
	public func crossover(with partner: LivingTreeGenome, rate: Double, environment: Environment) throws -> (LivingTreeGenome, LivingTreeGenome) {
		guard Double.random(in: 0..<1) < rate else { return (self, partner) }
		guard partner.rootGene.children.count > 1 && self.rootGene.children.count > 1 else { return (self, partner) }
		
		var childRootA = self.rootGene.copy()
		var childRootB = partner.rootGene.copy()
		
		guard let crossoverRootA = childRootA.allNodes.randomElement(),
			  let crossoverRootB = childRootB.allNodes.randomElement() else {
			return (self, partner)
		}
		
		let crossoverRootAOriginalParent = crossoverRootA.parent
		let crossoverRootBOriginalParent = crossoverRootB.parent
		
		// Crossover to create first child.
		if let parent = crossoverRootAOriginalParent {
            if let index = parent.children.firstIndex(where: { $0 === crossoverRootA }) {
                parent.children[index] = crossoverRootB
            }
		} else {
			childRootA = crossoverRootB
		}
		
		// Crossover to create second child.
		if let parent = crossoverRootBOriginalParent {
            if let index = parent.children.firstIndex(where: { $0 === crossoverRootB }) {
                parent.children[index] = crossoverRootA
            }
		} else {
			childRootB = crossoverRootA
		}
        
        // Ensure all parent back-pointers are correct after structural swap.
        childRootA.recursivelyResetParents()
        childRootB.recursivelyResetParents()
		
		return (
			LivingTreeGenome(rootGene: childRootA),
			LivingTreeGenome(rootGene: childRootB)
		)
	}
	
	/// Returns a deep copy.
	public func copy() -> LivingTreeGenome {
		let newRoot = self.rootGene.copy()
		return LivingTreeGenome(rootGene: newRoot)
	}
	
}

extension LivingTreeGenome: RawRepresentable {
	public typealias RawValue = RealGene
	public var rawValue: RawValue { return rootGene }
	public init?(rawValue: RawValue) {
		self = LivingTreeGenome.init(rootGene: rawValue)
	}
}

// Living trees can behave as genes within a living forest genome.
extension LivingTreeGenome: Gene {
	public typealias Environment = RealGene.Environment
}
