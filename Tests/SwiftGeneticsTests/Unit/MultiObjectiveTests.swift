import XCTest
@testable import SwiftGenetics

final class MultiObjectiveTests: XCTestCase {
    
    struct MockEnv: GeneticEnvironment {
        var populationSize: Int = 10
        var selectionMethod: SelectionMethod = .nsga2
        var selectableProportion: Double = 1.0
        var mutationRate: Double = 0.1
        var crossoverRate: Double = 0.5
        var numberOfElites: Int = 0
        var numberOfEliteCopies: Int = 0
        var parameters: [String : AnyCodable] = [:]
    }
    
    struct ContGenome: Genome {
        typealias Environment = MockEnv
        var values: [Double]
        func mutate(rate: Double, environment: MockEnv) throws { /* noop */ }
        func crossover(with partner: ContGenome, rate: Double, environment: MockEnv) throws -> (ContGenome, ContGenome) {
            return (self, partner)
        }
    }
    
    // MARK: - Core Algorithm Tests
    
    func testParetoDominance() {
        let g = ContGenome(values: [])
        
        // Maximization: A dominates B if A is no worse in all, and better in at least one.
        var a = Organism(genotype: g)
        a.objectives = [2.0, 2.0]
        
        var b = Organism(genotype: g)
        b.objectives = [1.0, 1.0]
        
        XCTAssertTrue(NSGA2.dominates(a, b))
        XCTAssertFalse(NSGA2.dominates(b, a))
        
        var c = Organism(genotype: g)
        c.objectives = [2.0, 1.0]
        
        XCTAssertTrue(NSGA2.dominates(a, c))
        XCTAssertTrue(NSGA2.dominates(c, b))
        
        var d = Organism(genotype: g)
        d.objectives = [1.0, 2.0]
        
        // c and d should not dominate each other (non-dominated)
        XCTAssertFalse(NSGA2.dominates(c, d))
        XCTAssertFalse(NSGA2.dominates(d, c))
    }
    
    func testNonDominatedSort() {
        let g = ContGenome(values: [])
        
        let o1 = Organism(genotype: g); var p1 = o1; p1.objectives = [10.0, 2.0] // Front 1
        let o2 = Organism(genotype: g); var p2 = o2; p2.objectives = [5.0, 5.0]  // Front 1
        let o3 = Organism(genotype: g); var p3 = o3; p3.objectives = [2.0, 10.0] // Front 1
        let o4 = Organism(genotype: g); var p4 = o4; p4.objectives = [4.0, 4.0]  // Dominated by p2 (Front 2)
        let o5 = Organism(genotype: g); var p5 = o5; p5.objectives = [1.0, 1.0]  // Front 3
        
        let population = [p1, p2, p3, p4, p5]
        let fronts = NSGA2.fastNonDominatedSort(population)
        
        XCTAssertEqual(fronts.count, 3)
        XCTAssertEqual(fronts[0].count, 3) // p1, p2, p3
        XCTAssertEqual(fronts[1].count, 1) // p4
        XCTAssertEqual(fronts[2].count, 1) // p5
    }
    
    // MARK: - End-to-End Test
    
    struct MultiObjectiveEvaluator: FitnessEvaluator {
        typealias G = ContGenome
        func fitnessFor(organism: Organism<G>) async throws -> Double {
            return 0.0 // not used
        }
        func objectivesFor(organism: Organism<G>) async throws -> [Double] {
            // Maximize f1(x) = x[0], f2(x) = 10 - x[0]
            let x = organism.genotype.values[0]
            return [x, 10.0 - x]
        }
    }
    
    struct LogDelegate: EvolutionLoggingDelegate {
        typealias G = ContGenome
        func evolutionStartingEpoch(_ epoch: Int) {}
        func evolutionFinishedEpoch(_ epoch: Int, duration: TimeInterval, population: Population<G>) {}
        func evolutionFoundSolution(_ genotype: G, fitness: Double) {}
    }

    func testMultiObjectiveEvolution() async throws {
        let env = MockEnv(populationSize: 4)
        var population = Population<ContGenome>(environment: env, evolutionType: .nsga2)
        
        // Initial population
        population.organisms = [
            Organism(genotype: ContGenome(values: [0.0])),
            Organism(genotype: ContGenome(values: [1.0])),
            Organism(genotype: ContGenome(values: [2.0])),
            Organism(genotype: ContGenome(values: [3.0]))
        ]
        
        let ga = GeneticAlgorithm(fitnessEvaluator: MultiObjectiveEvaluator(), loggingDelegate: LogDelegate())
        let config = EvolutionAlgorithmConfiguration(maxEpochs: 2, algorithmType: .nsga2)
        
        try await ga.evolve(population: &population, configuration: config)
        
        // After 2 epochs, population size should still be 4
        XCTAssertEqual(population.organisms.count, 4)
        
        // Verify they all have objectives evaluated
        for organism in population.organisms {
            XCTAssertNotNil(organism.objectives)
            XCTAssertEqual(organism.objectives?.count, 2)
            // dominanceRank and crowdingDistance should be assigned
            XCTAssertLessThan(organism.dominanceRank, 4) 
        }
    }
}
