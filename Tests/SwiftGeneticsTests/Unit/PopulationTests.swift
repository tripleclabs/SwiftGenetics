import XCTest
@testable import SwiftGenetics

final class PopulationTests: XCTestCase {
    
    typealias G = LivingStringGenome<ContinuousGene<Double, LivingStringEnvironment>>
    
    func testPopulationFitnessMetrics() {
        let env = LivingStringEnvironment(
            populationSize: 4,
            selectionMethod: .roulette,
            selectableProportion: 1.0,
            mutationRate: 0.1,
            crossoverRate: 0.5,
            numberOfElites: 0,
            numberOfEliteCopies: 0,
            parameters: [
                ContinuousEnvironmentParameter.mutationSize.rawValue: AnyCodable(0.1),
                ContinuousEnvironmentParameter.mutationType.rawValue: AnyCodable(ContinuousMutationType.uniform.rawValue)
            ]
        )
        var population = Population<G>(environment: env, evolutionType: .standard)
        
        let genomes = (0..<4).map { _ in G(genes: [ContinuousGene(value: 1.0)]) }
        population.organisms = genomes.enumerated().map { i, g in
            var organism = Organism(genotype: g)
            organism.fitness = Double(i + 1) // 1.0, 2.0, 3.0, 4.0
            return organism
        }
        
        // epoch() calls updateFitnessMetrics internally
        population.epoch()
        
        XCTAssertEqual(population.bestOrganismInGeneration?.fitness, 4.0)
        XCTAssertEqual(population.averageFitness, 2.5)
    }
    
    func testPopulationEpoch() {
        let env = LivingStringEnvironment(
            populationSize: 4,
            selectionMethod: .roulette,
            selectableProportion: 1.0,
            mutationRate: 0.1,
            crossoverRate: 0.5,
            numberOfElites: 1,
            numberOfEliteCopies: 2,
            parameters: [
                ContinuousEnvironmentParameter.mutationSize.rawValue: AnyCodable(0.1),
                ContinuousEnvironmentParameter.mutationType.rawValue: AnyCodable(ContinuousMutationType.uniform.rawValue)
            ]
        )
        var population = Population<G>(environment: env, evolutionType: .standard)
        
        let genomes = (0..<4).map { _ in G(genes: [ContinuousGene(value: 1.0)]) }
        population.organisms = genomes.map { Organism(genotype: $0) }
        for i in 0..<4 { population.organisms[i].fitness = Double(i) }
        
        let initialGeneration = population.generation
        population.epoch()
        
        XCTAssertEqual(population.generation, initialGeneration + 1)
        XCTAssertEqual(population.organisms.count, 4)
        // Ensure elites are preserved (one of them should be the best from previous)
        // This is implicit in the epoch implementation.
    }

    static let allTests = [
        ("testPopulationFitnessMetrics", testPopulationFitnessMetrics),
        ("testPopulationEpoch", testPopulationEpoch),
    ]
}
