import XCTest
@testable import SwiftGenetics

final class SelfAdaptiveTests: XCTestCase {
    
    struct MockEnv: GeneticEnvironment {
        var populationSize: Int = 2
        var selectionMethod: SelectionMethod = .roulette
        var selectableProportion: Double = 1.0
        var mutationRate: Double = 0.5
        var crossoverRate: Double = 0.5
        var numberOfElites: Int = 0
        var numberOfEliteCopies: Int = 0
        var parameters: [String : AnyCodable] = [:]
    }
    
    // MARK: - Mock Genomes
    
    final class ProgenySpyGenome: Genome, @unchecked Sendable {
        typealias Environment = MockEnv
        var id = UUID()
        var mutationRateReceived: Double?
        var individualMutationRate: Double?
        
        init(mutationRateOverride: Double? = nil) {
            self.individualMutationRate = mutationRateOverride
        }
        
        func mutate(rate: Double, environment: MockEnv) throws {
            mutationRateReceived = rate
        }
        
        func crossover(with partner: ProgenySpyGenome, rate: Double, environment: MockEnv) throws -> (ProgenySpyGenome, ProgenySpyGenome) {
            // Return progeny with specific overrides to verify they are used in the next step (mutation)
            return (ProgenySpyGenome(mutationRateOverride: 0.77), ProgenySpyGenome(mutationRateOverride: 0.88))
        }
        
        // Protocol conformances
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
        static func == (lhs: ProgenySpyGenome, rhs: ProgenySpyGenome) -> Bool { lhs.id == rhs.id }
        required init(from decoder: Decoder) throws { id = UUID() }
        func encode(to encoder: Encoder) throws {}
    }
    
    final class RateObserver: @unchecked Sendable {
        var lastCrossoverRate: Double?
    }

    final class StaticSpyGenome: Genome, @unchecked Sendable {
        typealias Environment = MockEnv
        var id = UUID()
        var individualCrossoverRate: Double?
        let observer: RateObserver?
        
        init(individualCrossoverRate: Double? = nil, observer: RateObserver? = nil) {
            self.individualCrossoverRate = individualCrossoverRate
            self.observer = observer
        }
        
        func mutate(rate: Double, environment: MockEnv) throws {}
        func crossover(with partner: StaticSpyGenome, rate: Double, environment: MockEnv) throws -> (StaticSpyGenome, StaticSpyGenome) {
            observer?.lastCrossoverRate = rate
            return (self, partner)
        }
        
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
        static func == (lhs: StaticSpyGenome, rhs: StaticSpyGenome) -> Bool { lhs.id == rhs.id }
        required init(from decoder: Decoder) throws { id = UUID(); observer = nil }
        func encode(to encoder: Encoder) throws {}
    }

    // MARK: - Tests

    func testPopulationUsesIndividualMutationRateForProgeny() async throws {
        let env = MockEnv(selectionMethod: .truncation(takePortion: 1.0), mutationRate: 0.1)
        var population = Population<ProgenySpyGenome>(environment: env, evolutionType: .standard)
        
        let g1 = ProgenySpyGenome()
        let g2 = ProgenySpyGenome()
        
        population.organisms = [
            Organism(genotype: g1),
            Organism(genotype: g2)
        ]
        population.organisms[0].fitness = 1.0
        population.organisms[1].fitness = 1.0
        
        // This will trigger crossover (returning progeny with 0.77 and 0.88)
        // and then mutate those progeny using their individual rates.
        try await population.epoch()
        
        XCTAssertEqual(population.organisms.count, 2)
        let progenyA = population.organisms[0].genotype
        let progenyB = population.organisms[1].genotype
        
        XCTAssertEqual(progenyA.mutationRateReceived, 0.77)
        XCTAssertEqual(progenyB.mutationRateReceived, 0.88)
    }

    func testDirectCrossoverOverride() async throws {
        let observer = RateObserver()
        let env = MockEnv(selectionMethod: .truncation(takePortion: 1.0), crossoverRate: 0.1)
        var population = Population<StaticSpyGenome>(environment: env, evolutionType: .standard)
        population.organisms = [
            Organism(genotype: StaticSpyGenome(individualCrossoverRate: 0.66, observer: observer)),
            Organism(genotype: StaticSpyGenome(individualCrossoverRate: nil, observer: observer))
        ]
        population.organisms[0].fitness = 1.0
        population.organisms[1].fitness = 1.0
        
        try await population.epoch()
        XCTAssertEqual(observer.lastCrossoverRate, 0.66)
    }

    static let allTests = [
        ("testPopulationUsesIndividualMutationRateForProgeny", testPopulationUsesIndividualMutationRateForProgeny),
        ("testDirectCrossoverOverride", testDirectCrossoverOverride),
    ]
}
