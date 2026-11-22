import XCTest
@testable import SwiftGenetics

final class FitnessCacheTests: XCTestCase {
    
    typealias G = LivingStringGenome<ContinuousGene<Double, LivingStringEnvironment>>
    
    func testSingleObjectiveCaching() {
        let cache = FitnessCache<G>()
        let genome = G(genes: [ContinuousGene(value: 1.0)])
        
        // Initial state
        XCTAssertNil(cache.fitness(for: genome))
        
        // Set and get
        cache.setFitness(123.45, for: genome)
        XCTAssertEqual(cache.fitness(for: genome), 123.45)
    }
    
    func testMultiObjectiveCaching() {
        let cache = FitnessCache<G>()
        let genome = G(genes: [ContinuousGene(value: 2.0)])
        let objectives = [1.0, 2.0, 3.0]
        
        // Initial state
        XCTAssertNil(cache.objectives(for: genome))
        
        // Set and get
        cache.setObjectives(objectives, for: genome)
        XCTAssertEqual(cache.objectives(for: genome), objectives)
    }
    
    func testClearCache() {
        let cache = FitnessCache<G>()
        let genome = G(genes: [ContinuousGene(value: 1.0)])
        
        cache.setFitness(42.0, for: genome)
        cache.clear()
        
        XCTAssertNil(cache.fitness(for: genome))
    }
    
    func testCacheUniqueness() {
        let cache = FitnessCache<G>()
        let genome1 = G(genes: [ContinuousGene(value: 1.0)])
        let genome2 = G(genes: [ContinuousGene(value: 2.0)])
        
        cache.setFitness(1.0, for: genome1)
        cache.setFitness(2.0, for: genome2)
        
        XCTAssertEqual(cache.fitness(for: genome1), 1.0)
        XCTAssertEqual(cache.fitness(for: genome2), 2.0)
    }

    func testBatchLookupAndInsert() {
        let cache = FitnessCache<G>()
        let genomes = (0..<5).map { G(genes: [ContinuousGene(value: Double($0))]) }

        cache.setFitnesses([
            (genomes[0], 10.0),
            (genomes[2], 20.0),
            (genomes[4], 30.0)
        ])

        let results = cache.fitnesses(for: genomes)
        XCTAssertEqual(results, [10.0, nil, 20.0, nil, 30.0])
    }

    func testBoundedEvictionRotatesOldBuckets() {
        // maxEntries = 4 -> bucketLimit = 2
        let cache = FitnessCache<G>(maxEntries: 4)
        let genomes = (0..<6).map { G(genes: [ContinuousGene(value: Double($0))]) }

        // Bucket 1: [0, 1]
        cache.setFitness(0.0, for: genomes[0])
        cache.setFitness(1.0, for: genomes[1])
        // Bucket 2 (rotates [0, 1] to previous): [2, 3]
        cache.setFitness(2.0, for: genomes[2])
        cache.setFitness(3.0, for: genomes[3])

        // All 4 should still hit (2 in current, 2 in previous)
        for i in 0..<4 {
            XCTAssertEqual(cache.fitness(for: genomes[i]), Double(i))
        }

        // Inserting 4 rotates [2, 3] to previous and drops [0, 1]
        cache.setFitness(4.0, for: genomes[4])
        XCTAssertNil(cache.fitness(for: genomes[0]))
        XCTAssertEqual(cache.fitness(for: genomes[2]), 2.0)
        XCTAssertEqual(cache.fitness(for: genomes[4]), 4.0)
    }

    static let allTests = [
        ("testSingleObjectiveCaching", testSingleObjectiveCaching),
        ("testMultiObjectiveCaching", testMultiObjectiveCaching),
        ("testClearCache", testClearCache),
        ("testCacheUniqueness", testCacheUniqueness),
        ("testBatchLookupAndInsert", testBatchLookupAndInsert),
        ("testBoundedEvictionRotatesOldBuckets", testBoundedEvictionRotatesOldBuckets),
    ]
}
