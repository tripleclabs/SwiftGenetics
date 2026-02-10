import XCTest
import SwiftGenetics

final class LivingForestTests: XCTestCase {
    
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
    
    func testLivingForestGenomeInitialization() {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let root1 = LivingTreeGene<MockGeneType>(template, geneType: .terminal, parent: nil, children: [])
        let root2 = LivingTreeGene<MockGeneType>(template, geneType: .terminal, parent: nil, children: [])
        
        let forest = LivingForestGenome(roots: [root1, root2])
        XCTAssertEqual(forest.trees.count, 2)
        XCTAssertEqual(forest.trees[0].rootGene, root1)
    }
    
    func testLivingForestMutation() throws {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let root = LivingTreeGene<MockGeneType>(template, geneType: .terminal, parent: nil, children: [])
        var forest = LivingForestGenome(roots: [root])
        
        let env = LivingTreeEnvironment(
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
        let root1 = LivingTreeGene<MockGeneType>(template, geneType: .terminal, parent: nil, children: [])
        let root2 = LivingTreeGene<MockGeneType>(template, geneType: .terminal, parent: nil, children: [])
        
        let forest1 = LivingForestGenome(roots: [root1])
        let forest2 = LivingForestGenome(roots: [root2])
        
        let env = LivingTreeEnvironment(
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
        let root = LivingTreeGene<MockGeneType>(template, geneType: .terminal, parent: nil, children: [])
        let forest = LivingForestGenome(roots: [root])
        let copy = forest.copy()
        
        XCTAssertEqual(copy.trees.count, 1)
        XCTAssertFalse(copy.trees[0].rootGene === forest.trees[0].rootGene)
    }

    static let allTests = [
        ("testLivingForestGenomeInitialization", testLivingForestGenomeInitialization),
        ("testLivingForestMutation", testLivingForestMutation),
        ("testLivingForestCrossover", testLivingForestCrossover),
        ("testLivingForestCopy", testLivingForestCopy),
    ]
}
