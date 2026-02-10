//
//  LivingTree+Equatable.swift
//  SwiftGenetics
//
//  Created by Santiago Gonzalez on 6/13/19.
//  Copyright © 2019 Santiago Gonzalez. All rights reserved.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

extension LivingTreeGene: Equatable {
	
	// NOTE: does not compare parents.
	public static func == (lhs: LivingTreeGene, rhs: LivingTreeGene) -> Bool {
		return
			lhs.coefficient == rhs.coefficient &&
			lhs.allowsCoefficient == rhs.allowsCoefficient &&
			lhs.geneType == rhs.geneType &&
			lhs.children == rhs.children
	}
	
}

extension LivingTreeGene: Hashable {
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(coefficient)
		hasher.combine(allowsCoefficient)
		hasher.combine(geneType)
		hasher.combine(children)
	}
	
}

extension LivingTreeGene: @unchecked Sendable { }
