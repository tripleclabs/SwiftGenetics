import XCTest
@testable import SwiftGenetics

final class LivingTreeTests: XCTestCase {
    
    struct MockTreeEnvironment: GeneticEnvironment {
        var populationSize: Int = 10
        var selectionMethod: SelectionMethod = .roulette
        var selectableProportion: Double = 1.0
        var mutationRate: Double = 1.0
        var crossoverRate: Double = 1.0
        var numberOfElites: Int = 0
        var numberOfEliteCopies: Int = 0
        var parameters: [String : AnyCodable] = [:]
        var randomSource: RandomSource = RandomSource(seed: 42)
        var scalarMutationMagnitude: Int = 1
        var structuralMutationDeletionRate: Double = 0.1
        var structuralMutationAdditionRate: Double = 0.1
    }
    
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
    
    func testLivingTreeGenomeInitialization() {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let genome = LivingTreeGenome<MockGeneType>(nodes: [FlatTreeNode(geneType: .terminal)], template: template)
        
        XCTAssertEqual(genome.nodes.count, 1)
        XCTAssertEqual(genome.nodes[0].geneType, .terminal)
    }
    
    func testLivingTreeMutation() throws {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        var genome = LivingTreeGenome<MockGeneType>(nodes: [FlatTreeNode(geneType: .terminal)], template: template)
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
        
        // Mutate terminal
        try genome.mutate(rate: 1.0, environment: env)
        XCTAssertFalse(genome.nodes.isEmpty)
    }
    
    func testLivingTreeGenomeOperations() throws {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let mockEnv = LivingTreeEnvironment(
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
            structuralMutationAdditionRate: 0.1,
            randomSource: RandomSource(seed: 42)
        )
        let genome1 = try LivingTreeGenome(depth: 1, template: template, environment: mockEnv)
        let genome2 = try LivingTreeGenome(depth: 1, template: template, environment: mockEnv)
        
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
        
        // Mutate genome
        var mutableGenome = genome1
        try mutableGenome.mutate(rate: 1.0, environment: env)
        
        // Crossover
        let (child1, child2) = try genome1.crossover(with: genome2, rate: 1.0, environment: env)
        XCTAssertFalse(child1.nodes.isEmpty)
        XCTAssertFalse(child2.nodes.isEmpty)
    }
    
    func testTreeGenomeCopy() throws {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
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
            structuralMutationAdditionRate: 0.1,
            randomSource: RandomSource(seed: 42)
        )
        let genome = try LivingTreeGenome(depth: 2, template: template, environment: env)
        
        let copy = genome.copy()
        XCTAssertEqual(copy.nodes.count, genome.nodes.count)
        XCTAssertEqual(copy.nodes[0].geneType, genome.nodes[0].geneType)
    }
    
    func testTreeGenomeEquality() throws {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let genome1 = LivingTreeGenome<MockGeneType>(nodes: [FlatTreeNode(geneType: .terminal)], template: template)
        let genome2 = LivingTreeGenome<MockGeneType>(nodes: [FlatTreeNode(geneType: .terminal)], template: template)
        let genome3 = LivingTreeGenome<MockGeneType>(nodes: [FlatTreeNode(geneType: .binary, subtreeSize: 3), FlatTreeNode(geneType: .terminal), FlatTreeNode(geneType: .terminal)], template: template)
        
        XCTAssertEqual(genome1, genome2)
        XCTAssertNotEqual(genome1, genome3)
    }
    
    func testTreeGenomeHashing() {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let genome1 = LivingTreeGenome<MockGeneType>(nodes: [FlatTreeNode(geneType: .terminal)], template: template)
        let genome2 = LivingTreeGenome<MockGeneType>(nodes: [FlatTreeNode(geneType: .terminal)], template: template)
        
        XCTAssertEqual(genome1.hashValue, genome2.hashValue)
    }

    static let allTests = [
        ("testLivingTreeGenomeInitialization", testLivingTreeGenomeInitialization),
        ("testLivingTreeMutation", testLivingTreeMutation),
        ("testLivingTreeGenomeOperations", testLivingTreeGenomeOperations),
        ("testTreeGenomeCopy", testTreeGenomeCopy),
        ("testTreeGenomeEquality", testTreeGenomeEquality),
        ("testTreeGenomeHashing", testTreeGenomeHashing),
        ("testRandomTreeGenesis", testRandomTreeGenesis),
        ("testStructuralAdditionMutation", testStructuralAdditionMutation),
        ("testStructuralDeletionMutation", testStructuralDeletionMutation),
    ]
}

extension LivingTreeTests {
    func testRandomTreeGenesis() throws {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
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
            structuralMutationAdditionRate: 0.1,
            randomSource: RandomSource(seed: 42)
        )
        let genome = try LivingTreeGenome<MockGeneType>.random(depth: 2, template: template, environment: env)
        XCTAssertFalse(genome.nodes.isEmpty)
    }

    func testStructuralAdditionMutation() throws {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        var genome = LivingTreeGenome<MockGeneType>(nodes: [FlatTreeNode(geneType: .terminal)], template: template)
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
            structuralMutationDeletionRate: 0.0,
            structuralMutationAdditionRate: 1.0 // Force addition
        )
        
        try genome.mutate(rate: 1.0, environment: env)
        XCTAssertTrue(genome.nodes.count > 1)
    }

    func testStructuralDeletionMutation() throws {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        var genome = LivingTreeGenome<MockGeneType>(nodes: [
            FlatTreeNode(geneType: .binary, subtreeSize: 3),
            FlatTreeNode(geneType: .terminal),
            FlatTreeNode(geneType: .terminal)
        ], template: template)
        
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
            structuralMutationDeletionRate: 1.0, // Force deletion
            structuralMutationAdditionRate: 0.0
        )
        
        try genome.mutate(rate: 1.0, environment: env)
        XCTAssertEqual(genome.nodes.count, 1)
        XCTAssertTrue(genome.nodes[0].geneType.isLeafType)
    }
}
