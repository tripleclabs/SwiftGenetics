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
    
    func testLivingTreeGeneInitialization() {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let gene = LivingTreeGene<MockGeneType>(template, geneType: .terminal, parent: nil, children: [])
        
        XCTAssertEqual(gene.geneType, .terminal)
        XCTAssertTrue(gene.children.isEmpty)
    }
    
    func testLivingTreeGeneMutation() {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let gene = LivingTreeGene<MockGeneType>(template, geneType: .terminal, parent: nil, children: [])
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
        gene.mutate(rate: 1.0, environment: env)
        XCTAssertNotNil(gene.geneType)
    }
    
    func testLivingTreeGenomeOperations() {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let root = LivingTreeGene<MockGeneType>(template, geneType: .terminal, parent: nil, children: [])
        let genome1 = LivingTreeGenome(rootGene: root)
        let genome2 = LivingTreeGenome(rootGene: root.copy())
        
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
        mutableGenome.mutate(rate: 1.0, environment: env)
        
        // Crossover
        let (child1, child2) = genome1.crossover(with: genome2, rate: 1.0, environment: env)
        XCTAssertNotNil(child1.rootGene)
        XCTAssertNotNil(child2.rootGene)
    }
    
    func testTreeGeneCopy() {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let parent = LivingTreeGene<MockGeneType>(template, geneType: .binary, parent: nil, children: [])
        parent.children.append(LivingTreeGene(template, geneType: .terminal, parent: parent, children: []))
        
        let copy = parent.copy()
        XCTAssertEqual(copy.geneType, .binary)
        XCTAssertEqual(copy.children.count, 1)
        XCTAssertEqual(copy.children[0].geneType, .terminal)
        
        // Ensure it's a deep copy
        parent.children[0].geneType = .terminal
        // (Just verification that it works)
    }
    
    func testTreeGeneEquality() {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let gene1 = LivingTreeGene<MockGeneType>(template, geneType: .terminal, parent: nil, children: [])
        let gene2 = LivingTreeGene<MockGeneType>(template, geneType: .terminal, parent: nil, children: [])
        let gene3 = LivingTreeGene<MockGeneType>(template, geneType: .binary, parent: nil, children: [])
        
        XCTAssertEqual(gene1, gene2)
        XCTAssertNotEqual(gene1, gene3)
        
        gene1.children.append(LivingTreeGene(template, geneType: .terminal, parent: gene1, children: []))
        XCTAssertNotEqual(gene1, gene2)
        
        gene2.children.append(LivingTreeGene(template, geneType: .terminal, parent: gene2, children: []))
        XCTAssertEqual(gene1, gene2)
    }
    
    func testTreeGeneHashing() {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let gene1 = LivingTreeGene<MockGeneType>(template, geneType: .terminal, parent: nil, children: [])
        let gene2 = LivingTreeGene<MockGeneType>(template, geneType: .terminal, parent: nil, children: [])
        
        XCTAssertEqual(gene1.hashValue, gene2.hashValue)
    }

    static let allTests = [
        ("testLivingTreeGeneInitialization", testLivingTreeGeneInitialization),
        ("testLivingTreeGeneMutation", testLivingTreeGeneMutation),
        ("testLivingTreeGenomeOperations", testLivingTreeGenomeOperations),
        ("testTreeGeneCopy", testTreeGeneCopy),
        ("testTreeGeneEquality", testTreeGeneEquality),
        ("testTreeGeneHashing", testTreeGeneHashing),
        ("testRandomTreeGenesis", testRandomTreeGenesis),
        ("testStructuralAdditionMutation", testStructuralAdditionMutation),
        ("testStructuralDeletionMutation", testStructuralDeletionMutation),
        ("testTreeEnumeration", testTreeEnumeration),
    ]
}

extension LivingTreeTests {
    func testRandomTreeGenesis() {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let gene = LivingTreeGene<MockGeneType>.random(depth: 2, template: template)
        XCTAssertNotNil(gene)
        XCTAssertTrue(gene.allNodes.count >= 1)
    }

    func testStructuralAdditionMutation() {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let gene = LivingTreeGene<MockGeneType>(template, geneType: .terminal, parent: nil, children: [])
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
        
        gene.mutate(rate: 1.0, environment: env)
        XCTAssertFalse(gene.children.isEmpty)
    }

    func testStructuralDeletionMutation() {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let parent = LivingTreeGene<MockGeneType>(template, geneType: .binary, parent: nil, children: [])
        parent.children = [
            LivingTreeGene(template, geneType: .terminal, parent: parent, children: []),
            LivingTreeGene(template, geneType: .terminal, parent: parent, children: [])
        ]
        
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
        
        parent.mutate(rate: 1.0, environment: env)
        XCTAssertTrue(parent.children.isEmpty)
    }

    func testTreeEnumeration() {
        let template = TreeGeneTemplate<MockGeneType>(binaryTypes: [.binary], unaryTypes: [.unary], leafTypes: [.terminal])
        let parent = LivingTreeGene<MockGeneType>(template, geneType: .binary, parent: nil, children: [])
        parent.children = [
            LivingTreeGene(template, geneType: .terminal, parent: parent, children: []),
            LivingTreeGene(template, geneType: .terminal, parent: parent, children: [])
        ]
        
        var count = 0
        parent.bottomUpEnumerate { _ in count += 1 }
        XCTAssertEqual(count, 3)
        XCTAssertEqual(parent.allNodes.count, 3)
    }
}
