import XCTest
@testable import SwiftGenetics

final class FitnessCacheTests: XCTestCase {
    
    typealias G = LivingStringGenome<ContinuousGene<Double, LivingStringEnvironment>>
    
    func testSingleObjectiveCaching() async {
        let cache = FitnessCache<G>()
        let genome = G(genes: [ContinuousGene(value: 1.0)])
        
        // Initial state
        let initial = await cache.fitness(for: genome)
        XCTAssertNil(initial)
        
        // Set and get
        await cache.setFitness(123.45, for: genome)
        let cached = await cache.fitness(for: genome)
        XCTAssertEqual(cached, 123.45)
    }
    
    func testMultiObjectiveCaching() async {
        let cache = FitnessCache<G>()
        let genome = G(genes: [ContinuousGene(value: 2.0)])
        let objectives = [1.0, 2.0, 3.0]
        
        // Initial state
        let initial = await cache.objectives(for: genome)
        XCTAssertNil(initial)
        
        // Set and get
        await cache.setObjectives(objectives, for: genome)
        let cached = await cache.objectives(for: genome)
        XCTAssertEqual(cached, objectives)
    }
    
    func testClearCache() async {
        let cache = FitnessCache<G>()
        let genome = G(genes: [ContinuousGene(value: 1.0)])
        
        await cache.setFitness(42.0, for: genome)
        await cache.clear()
        
        let cached = await cache.fitness(for: genome)
        XCTAssertNil(cached)
    }
    
    func testCacheUniqueness() async {
        let cache = FitnessCache<G>()
        let genome1 = G(genes: [ContinuousGene(value: 1.0)])
        let genome2 = G(genes: [ContinuousGene(value: 2.0)])
        
        await cache.setFitness(1.0, for: genome1)
        await cache.setFitness(2.0, for: genome2)
        
        let cached1 = await cache.fitness(for: genome1)
        let cached2 = await cache.fitness(for: genome2)
        
        XCTAssertEqual(cached1, 1.0)
        XCTAssertEqual(cached2, 2.0)
    }

    static let allTests = [
        ("testSingleObjectiveCaching", testSingleObjectiveCaching),
        ("testMultiObjectiveCaching", testMultiObjectiveCaching),
        ("testClearCache", testClearCache),
        ("testCacheUniqueness", testCacheUniqueness),
    ]
}
