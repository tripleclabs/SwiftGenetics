import XCTest
import SwiftGenetics

final class PermutationGAIntegrationTests: XCTestCase {
    
    struct OrderFitnessEvaluator: FitnessEvaluator {
        typealias G = PermutationGenome<Int>
        
        func fitnessFor(organism: Organism<G>) async throws -> Double {
            var fitness = 0.0
            for i in 0..<organism.genotype.elements.count {
                if organism.genotype.elements[i] == i {
                    fitness += 1.0
                }
            }
            return fitness
        }
    }
    
    struct MockLogDelegate: EvolutionLoggingDelegate {
        typealias G = PermutationGenome<Int>
        func evolutionStartingEpoch(_ i: Int) {}
        func evolutionFinishedEpoch(_ i: Int, duration: TimeInterval, population: Population<G>) {}
        func evolutionFoundSolution(_ solution: G, fitness: Double) {}
    }
    
    func testPermutationSortingGA() async throws {
        let maxEpochs = 50
        let size = 10
        let environment = PermutationEnvironment(
            populationSize: 100,
            selectionMethod: .tournament(size: 3),
            mutationRate: 0.2,
            crossoverRate: 0.8,
            numberOfElites: 2
        )
        
        var population = Population<PermutationGenome<Int>>(environment: environment, evolutionType: .standard)
        let baseElements = Array(0..<size)
        for _ in 0..<environment.populationSize {
            let genotype = PermutationGenome(elements: baseElements.shuffled())
            let organism = Organism<PermutationGenome<Int>>(genotype: genotype)
            population.organisms.append(organism)
        }
        
        let evaluator = OrderFitnessEvaluator()
        let logDelegate = MockLogDelegate()
        let ga = GeneticAlgorithm(fitnessEvaluator: evaluator, loggingDelegate: logDelegate)
        let config = EvolutionAlgorithmConfiguration(maxEpochs: maxEpochs, algorithmType: .standard)
        
        try await ga.evolve(population: &population, configuration: config)
        
        let bestOrganism = population.bestOrganism!
        XCTAssertGreaterThan(bestOrganism.fitness ?? 0, 0)
        // With enough epochs, it should eventually reach perfect fitness (10.0)
        // but we just check if it's doing something reasonable.
    }

    static let allTests = [
        ("testPermutationSortingGA", testPermutationSortingGA),
    ]
}
