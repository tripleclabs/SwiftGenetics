import XCTest
import SwiftGenetics

final class ForestTests: XCTestCase {
    
    enum MockGeneType: Int, TreeGeneType {
        case terminal, unary, binary
        var childCount: Int {
            switch self {
            case .terminal: return 0
            case .unary: return 1
            case .binary: return 2
            }
        }
        static var binaryTypes: [MockGeneType] { [.binary] }
        static var unaryTypes: [MockGeneType] { [.unary] }
        static var leafTypes: [MockGeneType] { [.terminal] }
    }
    
    func testForestGenomeInitialization() {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let tree1 = TreeGenome<MockGeneType>(nodes: [FlatTreeNode(geneType: .terminal)], template: template)
        let tree2 = TreeGenome<MockGeneType>(nodes: [FlatTreeNode(geneType: .terminal)], template: template)
        
        let forest = ForestGenome(trees: [tree1, tree2])
        XCTAssertEqual(forest.trees.count, 2)
        XCTAssertEqual(forest.trees[0].nodes.count, 1)
    }
    
    func testLivingForestMutation() throws {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let tree = TreeGenome<MockGeneType>(nodes: [FlatTreeNode(geneType: .terminal)], template: template)
        var forest = ForestGenome(trees: [tree])
        
        let env = TreeEnvironment(
            populationSize: 10,
            selectionMethod: .roulette,
            selectableProportion: 1.0,
            mutationRate: 1.0,
            crossoverRate: 1.0,
            numberOfElites: 0,
            numberOfEliteCopies: 0,
            parameters: [:],
            scalarMutationMagnitude: 1,
            structuralMutationDeletionRate: 0.1,
            structuralMutationAdditionRate: 0.1
        )
        
        try forest.mutate(rate: 1.0, environment: env)
        XCTAssertEqual(forest.trees.count, 1)
    }
    
    func testLivingForestCrossover() throws {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let tree1 = TreeGenome<MockGeneType>(nodes: [FlatTreeNode(geneType: .terminal)], template: template)
        let tree2 = TreeGenome<MockGeneType>(nodes: [FlatTreeNode(geneType: .terminal)], template: template)
        
        let forest1 = ForestGenome(trees: [tree1])
        let forest2 = ForestGenome(trees: [tree2])
        
        let env = TreeEnvironment(
            populationSize: 10,
            selectionMethod: .roulette,
            selectableProportion: 1.0,
            mutationRate: 1.0,
            crossoverRate: 1.0,
            numberOfElites: 0,
            numberOfEliteCopies: 0,
            parameters: [:],
            scalarMutationMagnitude: 1,
            structuralMutationDeletionRate: 0.1,
            structuralMutationAdditionRate: 0.1
        )
        
        let (child1, child2) = try forest1.crossover(with: forest2, rate: 1.0, environment: env)
        XCTAssertEqual(child1.trees.count, 1)
        XCTAssertEqual(child2.trees.count, 1)
    }
    
    func testLivingForestCopy() {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let tree = TreeGenome<MockGeneType>(nodes: [FlatTreeNode(geneType: .terminal)], template: template)
        let forest = ForestGenome(trees: [tree])
        let copy = forest.copy()
        
        XCTAssertEqual(copy.trees.count, 1)
        XCTAssertEqual(copy.trees[0].nodes, forest.trees[0].nodes)
    }

    static let allTests = [
        ("testForestGenomeInitialization", testForestGenomeInitialization),
        ("testLivingForestMutation", testLivingForestMutation),
        ("testLivingForestCrossover", testLivingForestCrossover),
        ("testLivingForestCopy", testLivingForestCopy),
    ]
}
