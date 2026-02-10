//
//  FlatTreeNode.swift
//  SwiftGenetics
//
//  Created by Triple C Labs GmbH 10/02/2026.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

/// A building block for a flat, array-based tree representation (Polish Notation).
public struct FlatTreeNode<GeneType: TreeGeneType>: Codable, Sendable, Hashable {
    
    /// The specific type of this node (e.g., an operator or terminal).
    public var geneType: GeneType
    
    /// The number of nodes in the subtree rooted at this node (including this node).
    /// This allows for O(1) skipping of subtrees during traversal or crossover.
    public var subtreeSize: Int
    
    /// An optional coefficient that can be used for numerical constants.
    public var coefficient: Double?
    
    /// Whether the node allows for a coefficient.
    public var allowsCoefficient: Bool
    
    public init(geneType: GeneType, subtreeSize: Int = 1, coefficient: Double? = nil, allowsCoefficient: Bool = true) {
        self.geneType = geneType
        self.subtreeSize = subtreeSize
        self.coefficient = coefficient
        self.allowsCoefficient = allowsCoefficient
    }
}
