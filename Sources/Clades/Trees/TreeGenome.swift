/// An evolvable tree represented as a flat array of nodes in prefix order (Polish Notation).
public struct TreeGenome<GeneType: TreeGeneType>: Genome {
    
    public typealias Node = FlatTreeNode<GeneType>
    
    /// The tree's nodes in prefix order.
    public var nodes: [Node]
    
    /// The sampling template used for structural mutations.
    public let template: TreeGeneTemplate<GeneType>
    
    /// Creates a new genome with the given nodes.
    public init(nodes: [Node], template: TreeGeneTemplate<GeneType>) {
        self.nodes = nodes
        self.template = template
    }
    
    // MARK: - Mutation
    
    mutating public func mutate(rate: Double, environment: Environment) throws {
        guard !nodes.isEmpty else { return }
        
        let deletionRate = environment.structuralMutationDeletionRate
        let additionRate = environment.structuralMutationAdditionRate
        
        environment.randomSource.withGenerator { rng in
            var i = 0
            // Stack of open ancestors in prefix order: (nodeIndex, remainingUnvisitedChildren).
            // Allows O(depth) incremental subtreeSize updates on structural mutations instead of O(n).
            var ancestorStack: [(index: Int, remainingChildren: Int)] = []
            ancestorStack.reserveCapacity(16)
            
            @inline(__always)
            func completeSubtreeInAncestors() {
                while !ancestorStack.isEmpty {
                    let lastIdx = ancestorStack.count - 1
                    ancestorStack[lastIdx].remainingChildren -= 1
                    if ancestorStack[lastIdx].remainingChildren == 0 {
                        ancestorStack.removeLast()
                    } else {
                        break
                    }
                }
            }
            
            while i < nodes.count {
                var node = nodes[i]
                var madeStructuralMutation = false
                
                // Check if we should mutate this node
                if Double.random(in: 0..<1, using: &rng) < rate {
                    // Deletion mutation: turn a non-leaf into a leaf
                    if !node.geneType.isLeafType && Double.random(in: 0..<1, using: &rng) < deletionRate {
                        let newType = template.leafTypes.randomElement(using: &rng)!
                        let oldSubtreeSize = node.subtreeSize
                        node.geneType = newType
                        node.subtreeSize = 1
                        nodes[i] = node
                        
                        // Remove the rest of the subtree
                        if oldSubtreeSize > 1 {
                            let delta = 1 - oldSubtreeSize
                            nodes.removeSubrange((i + 1)..<(i + oldSubtreeSize))
                            for a in 0..<ancestorStack.count {
                                nodes[ancestorStack[a].index].subtreeSize += delta
                            }
                        }
                        madeStructuralMutation = true
                    }
                    
                    // Addition mutation: turn a leaf into a non-leaf
                    if !madeStructuralMutation && node.geneType.isLeafType && Double.random(in: 0..<1, using: &rng) < additionRate {
                        let newType = template.nonLeafTypes.randomElement(using: &rng)!
                        var newChildren: [Node] = []
                        for _ in 0..<newType.childCount {
                            newChildren.append(contentsOf: generateRandomSubtree(depth: 1, using: &rng))
                        }
                        let addedCount = newChildren.count
                        node.geneType = newType
                        node.subtreeSize = 1 + addedCount
                        nodes[i] = node
                        nodes.insert(contentsOf: newChildren, at: i + 1)
                        
                        for a in 0..<ancestorStack.count {
                            nodes[ancestorStack[a].index].subtreeSize += addedCount
                        }
                        
                        // Skip the newly added children to avoid infinite mutation loops
                        i += addedCount
                        madeStructuralMutation = true
                    }
                    
                    // Type mutation: swap type but maintain structure
                    if !madeStructuralMutation {
                        let currentType = node.geneType
                        if currentType.isBinaryType {
                            node.geneType = Self.randomOtherElement(in: template.binaryTypes, excluding: currentType, using: &rng)
                        } else if currentType.isUnaryType {
                            node.geneType = Self.randomOtherElement(in: template.unaryTypes, excluding: currentType, using: &rng)
                        } else if currentType.isLeafType {
                            node.geneType = Self.randomOtherElement(in: template.leafTypes, excluding: currentType, using: &rng)
                        }
                        nodes[i] = node
                    }
                }
                
                // Advance prefix-order ancestor tracking
                if madeStructuralMutation {
                    // Both deletion (now a leaf) and addition (children skipped) finish this subtree.
                    completeSubtreeInAncestors()
                } else {
                    let childCount = node.geneType.childCount
                    if childCount > 0 {
                        ancestorStack.append((index: i, remainingChildren: childCount))
                    } else {
                        completeSubtreeInAncestors()
                    }
                }
                
                i += 1
            }
        }
    }
    
    /// Picks a random element from `candidates` other than `excluded` without allocating a filtered array.
    private static func randomOtherElement(in candidates: [GeneType], excluding excluded: GeneType, using rng: inout Xoshiro256PlusPlus) -> GeneType {
        var otherCount = 0
        for candidate in candidates where candidate != excluded {
            otherCount += 1
        }
        guard otherCount > 0 else { return excluded }
        var target = Int.random(in: 0..<otherCount, using: &rng)
        for candidate in candidates where candidate != excluded {
            if target == 0 { return candidate }
            target -= 1
        }
        return excluded
    }
    
    // MARK: - Crossover
    
    public func crossover(with partner: TreeGenome, rate: Double, environment: Environment) throws -> (TreeGenome, TreeGenome) {
        guard environment.randomSource.randomDouble() < rate else { return (self, partner) }
        
        // Pick a random subtree in each parent
        let indexA = environment.randomSource.randomInt(in: 0..<self.nodes.count)
        let indexB = environment.randomSource.randomInt(in: 0..<partner.nodes.count)
        
        let subtreeA = self.nodes[indexA..<(indexA + self.nodes[indexA].subtreeSize)]
        let subtreeB = partner.nodes[indexB..<(indexB + partner.nodes[indexB].subtreeSize)]
        
        var newNodesA = self.nodes
        newNodesA.replaceSubrange(indexA..<(indexA + self.nodes[indexA].subtreeSize), with: subtreeB)
        
        var newNodesB = partner.nodes
        newNodesB.replaceSubrange(indexB..<(indexB + partner.nodes[indexB].subtreeSize), with: subtreeA)
        
        var childA = TreeGenome(nodes: newNodesA, template: template)
        var childB = TreeGenome(nodes: newNodesB, template: template)
        
        childA.recalculateSubtreeSizes()
        childB.recalculateSubtreeSizes()
        
        return (childA, childB)
    }
    
    // MARK: - Helpers
    
    /// Generates a random subtree starting from the given depth.
    private func generateRandomSubtree(depth: Int, environment: Environment) throws -> [Node] {
        return environment.randomSource.withGenerator { rng in
            generateRandomSubtree(depth: depth, using: &rng)
        }
    }
    
    /// Generates a random subtree starting from the given depth using the provided generator directly.
    private func generateRandomSubtree(depth: Int, using rng: inout Xoshiro256PlusPlus) -> [Node] {
        // Simple heuristic: if depth > 3, prioritize leaves.
        let type: GeneType
        if depth > 3 || Double.random(in: 0..<1, using: &rng) < 0.5 {
            type = template.leafTypes.randomElement(using: &rng)!
        } else {
            type = template.nonLeafTypes.randomElement(using: &rng)!
        }
        
        var subtree = [Node(geneType: type)]
        for _ in 0..<type.childCount {
            subtree.append(contentsOf: generateRandomSubtree(depth: depth + 1, using: &rng))
        }
        
        // Set subtree size for the root of this random subtree
        subtree[0].subtreeSize = subtree.count
        return subtree
    }
    
    /// Recalculates `subtreeSize` for all nodes using a bottom-up pass in place.
    mutating public func recalculateSubtreeSizes() {
        let count = nodes.count
        guard count > 0 else { return }
        
        for i in (0..<count).reversed() {
            let childCount = nodes[i].geneType.childCount
            var size = 1
            var childIndex = i + 1
            for _ in 0..<childCount {
                if childIndex < count {
                    let childSize = nodes[childIndex].subtreeSize
                    size += childSize
                    childIndex += childSize
                }
            }
            nodes[i].subtreeSize = size
        }
    }
    
    public func copy() -> TreeGenome {
        return TreeGenome(nodes: nodes, template: template)
    }
    
    // MARK: - Genesis
    
    /// Returns a random, recursively built tree subject to certain constraints.
    public static func random(depth: Int, template: TreeGeneTemplate<GeneType>, environment: Environment) throws -> TreeGenome {
        var genome = TreeGenome(nodes: [], template: template)
        genome.nodes = try genome.generateRandomSubtree(depth: depth, environment: environment)
        genome.recalculateSubtreeSizes()
        return genome
    }
    
    /// Creates a random tree with the given depth.
    public init(depth: Int, template: TreeGeneTemplate<GeneType>, environment: Environment) throws {
        self.template = template
        self.nodes = []
        self.nodes = try generateRandomSubtree(depth: depth, environment: environment)
        recalculateSubtreeSizes()
    }
}

extension TreeGenome: RawRepresentable {
    public typealias RawValue = [Node]
    public var rawValue: RawValue { return nodes }
    public init?(rawValue: RawValue) {
        // Note: Template is missing here, which is a downside of RawRepresentable.
        // We might need to store the template in the RawValue if we really need this.
        return nil 
    }
}

extension TreeGenome: Gene {
    public typealias Environment = TreeEnvironment
}
