import XCTest
@testable import SwiftGenetics

final class GATests: XCTestCase {
    
    typealias G = LivingStringGenome<ContinuousGene<Double, LivingStringEnvironment>>
    
    struct MockEvaluator: FitnessEvaluator {
        typealias G = GATests.G
        func fitnessFor(organism: Organism<G>) async throws -> Double {
            return 1.0
        }
    }
    
    final class MockLogDelegate: EvolutionLoggingDelegate, @unchecked Sendable {
        typealias G = GATests.G
        var startingEpochCalled = false
        var finishedEpochCalled = false
        var foundSolutionCalled = false
        
        func evolutionStartingEpoch(_ i: Int) { startingEpochCalled = true }
        func evolutionFinishedEpoch(_ i: Int, duration: TimeInterval, population: Population<G>) { finishedEpochCalled = true }
        func evolutionFoundSolution(_ solution: G, fitness: Double) { foundSolutionCalled = true }
    }
    
    func testGAExecution() async {
        let env = LivingStringEnvironment(
            populationSize: 2,
            selectionMethod: .roulette,
            selectableProportion: 1.0,
            mutationRate: 0.1,
            crossoverRate: 0.5,
            numberOfElites: 0,
            numberOfEliteCopies: 0,
            parameters: [:]
        )
        let genome1 = LivingStringGenome<ContinuousGene<Double, LivingStringEnvironment>>(genes: [ContinuousGene(value: 1.0)])
        let genome2 = LivingStringGenome<ContinuousGene<Double, LivingStringEnvironment>>(genes: [ContinuousGene(value: 1.0)])
        var population = Population<G>(environment: env, evolutionType: .standard)
        population.organisms = [
            Organism(genotype: genome1),
            Organism(genotype: genome2)
        ]
        
        let evaluator = MockEvaluator()
        let logDelegate = MockLogDelegate()
        let ga = GeneticAlgorithm<MockEvaluator, MockLogDelegate>(fitnessEvaluator: evaluator, loggingDelegate: logDelegate)
        let config = EvolutionAlgorithmConfiguration(maxEpochs: 1, algorithmType: .standard)
        
        await ga.evolve(population: &population, configuration: config)
        
        XCTAssertTrue(logDelegate.startingEpochCalled)
        XCTAssertTrue(logDelegate.finishedEpochCalled)
        XCTAssertTrue(logDelegate.foundSolutionCalled)
    }

    static let allTests = [
        ("testGAExecution", testGAExecution),
    ]
}
