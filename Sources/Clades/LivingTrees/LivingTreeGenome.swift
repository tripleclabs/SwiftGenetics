/// An evolvable tree represented as a flat array of nodes in prefix order (Polish Notation).
public struct LivingTreeGenome<GeneType: TreeGeneType>: Genome {
    
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
        var i = 0
        let originalCount = nodes.count
        var nodesAdded = 0
        
        while i < originalCount + nodesAdded {
            // Check if we should mutate this node
            if environment.randomSource.randomDouble() < rate {
                var node = nodes[i]
                
                var madeStructuralMutation = false
                
                // Deletion mutation: turn a non-leaf into a leaf
                if !node.geneType.isLeafType && environment.randomSource.randomDouble() < environment.structuralMutationDeletionRate {
                    let newType = environment.randomSource.randomElement(from: template.leafTypes)!
                    node.geneType = newType
                    let oldSubtreeSize = node.subtreeSize
                    node.subtreeSize = 1
                    nodes[i] = node
                    
                    // Remove the rest of the subtree
                    if oldSubtreeSize > 1 {
                        nodes.removeSubrange((i+1)..<(i+oldSubtreeSize))
                        nodesAdded -= (oldSubtreeSize - 1)
                    }
                    madeStructuralMutation = true
                }
                
                // Addition mutation: turn a leaf into a non-leaf
                if !madeStructuralMutation && node.geneType.isLeafType && environment.randomSource.randomDouble() < environment.structuralMutationAdditionRate {
                    let newType = environment.randomSource.randomElement(from: template.nonLeafTypes)!
                    node.geneType = newType
                    nodes[i] = node
                    
                    // Add new random children
                    var newChildren: [Node] = []
                    for _ in 0..<newType.childCount {
                        newChildren.append(contentsOf: try generateRandomSubtree(depth: 1, environment: environment))
                    }
                    nodes.insert(contentsOf: newChildren, at: i + 1)
                    nodesAdded += newChildren.count
                    
                    // Skip the newly added children to avoid infinite mutation loops
                    i += newChildren.count
                    
                    madeStructuralMutation = true
                }
                
                // Type mutation: swap type but maintain structure
                if !madeStructuralMutation {
                    let currentType = node.geneType
                    if currentType.isBinaryType {
                        node.geneType = environment.randomSource.randomElement(from: template.binaryTypes.filter { $0 != currentType }) ?? currentType
                    } else if currentType.isUnaryType {
                        node.geneType = environment.randomSource.randomElement(from: template.unaryTypes.filter { $0 != currentType }) ?? currentType
                    } else if currentType.isLeafType {
                        node.geneType = environment.randomSource.randomElement(from: template.leafTypes.filter { $0 != currentType }) ?? currentType
                    }
                    nodes[i] = node
                }
                
                // If structure changed, we MUST recalculate subtree sizes for the WHOLE tree
                // because Polish Notation depends on it for traversal.
                if madeStructuralMutation {
                    recalculateSubtreeSizes()
                }
            }
            i += 1
        }
    }
    
    // MARK: - Crossover
    
    public func crossover(with partner: LivingTreeGenome, rate: Double, environment: Environment) throws -> (LivingTreeGenome, LivingTreeGenome) {
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
        
        var childA = LivingTreeGenome(nodes: newNodesA, template: template)
        var childB = LivingTreeGenome(nodes: newNodesB, template: template)
        
        childA.recalculateSubtreeSizes()
        childB.recalculateSubtreeSizes()
        
        return (childA, childB)
    }
    
    // MARK: - Helpers
    
    /// Generates a random subtree starting from the given depth.
    private func generateRandomSubtree(depth: Int, environment: Environment) throws -> [Node] {
        // Simple heuristic: if depth > 3, prioritize leaves.
        let type: GeneType
        if depth > 3 || environment.randomSource.randomDouble() < 0.5 {
            type = environment.randomSource.randomElement(from: template.leafTypes)!
        } else {
            type = environment.randomSource.randomElement(from: template.nonLeafTypes)!
        }
        
        var subtree = [Node(geneType: type)]
        for _ in 0..<type.childCount {
            subtree.append(contentsOf: try generateRandomSubtree(depth: depth + 1, environment: environment))
        }
        
        // Set subtree size for the root of this random subtree
        subtree[0].subtreeSize = subtree.count
        return subtree
    }
    
    /// Recalculates `subtreeSize` for all nodes using a bottom-up approach (via stack).
    mutating public func recalculateSubtreeSizes() {
        guard !nodes.isEmpty else { return }
        
        // We process from end to start to easily calculate subtree sizes
        var sizes = [Int](repeating: 0, count: nodes.count)
        
        for i in (0..<nodes.count).reversed() {
            let type = nodes[i].geneType
            var size = 1
            var childIndex = i + 1
            for _ in 0..<type.childCount {
                if childIndex < nodes.count {
                    size += sizes[childIndex]
                    childIndex += sizes[childIndex]
                }
            }
            sizes[i] = size
            nodes[i].subtreeSize = size
        }
    }
    
    public func copy() -> LivingTreeGenome {
        return LivingTreeGenome(nodes: nodes, template: template)
    }
    
    // MARK: - Genesis
    
    /// Returns a random, recursively built tree subject to certain constraints.
    public static func random(depth: Int, template: TreeGeneTemplate<GeneType>, environment: Environment) throws -> LivingTreeGenome {
        var genome = LivingTreeGenome(nodes: [], template: template)
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

extension LivingTreeGenome: RawRepresentable {
    public typealias RawValue = [Node]
    public var rawValue: RawValue { return nodes }
    public init?(rawValue: RawValue) {
        // Note: Template is missing here, which is a downside of RawRepresentable.
        // We might need to store the template in the RawValue if we really need this.
        return nil 
    }
}

extension LivingTreeGenome: Gene {
    public typealias Environment = LivingTreeEnvironment
}
