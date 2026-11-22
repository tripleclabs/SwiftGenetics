import XCTest
@testable import SwiftGenetics

final class CorrectnessRemediationTests: XCTestCase {

    typealias RealGene = ContinuousGene<Double, LivingStringEnvironment>
    typealias StringGenome = LivingStringGenome<RealGene>

    private func makeEnvironment(
        populationSize: Int = 50,
        selectionMethod: SelectionMethod = .tournament(size: 3),
        selectableProportion: Double = 1.0,
        mutationRate: Double = 0.5,
        crossoverRate: Double = 0.8,
        numberOfElites: Int = 2,
        numberOfEliteCopies: Int = 1,
        seed: UInt64 = 12345
    ) -> LivingStringEnvironment {
        LivingStringEnvironment(
            populationSize: populationSize,
            selectionMethod: selectionMethod,
            selectableProportion: selectableProportion,
            mutationRate: mutationRate,
            crossoverRate: crossoverRate,
            numberOfElites: numberOfElites,
            numberOfEliteCopies: numberOfEliteCopies,
            parameters: [
                ContinuousEnvironmentParameter.mutationSize.rawValue: AnyCodable(0.5),
                ContinuousEnvironmentParameter.mutationType.rawValue: AnyCodable(ContinuousMutationType.uniform.rawValue)
            ],
            randomSource: RandomSource(seed: seed)
        )
    }

    private func makePopulation(env: LivingStringEnvironment) -> Population<StringGenome> {
        var pop = Population<StringGenome>(environment: env, evolutionType: .standard)
        pop.organisms = (0..<env.populationSize).map { i in
            let genes = (0..<8).map { j in RealGene(value: Double(i * 8 + j)) }
            return Organism(fitness: Double(i + 1), genotype: StringGenome(genes: genes))
        }
        return pop
    }

    // MARK: - 1.1 Parallel Epoch Determinism

    func testEpochDeterminismAcrossParallelMatings() async throws {
        var pop1 = makePopulation(env: makeEnvironment(populationSize: 100, seed: 424242))
        var pop2 = makePopulation(env: makeEnvironment(populationSize: 100, seed: 424242))

        for _ in 0..<3 {
            try await pop1.epoch()
            try await pop2.epoch()

            // Assign deterministic fitnesses for next epoch
            for i in 0..<pop1.organisms.count {
                let fit1 = pop1.organisms[i].genotype.genes.reduce(0.0) { $0 + $1.value }
                let fit2 = pop2.organisms[i].genotype.genes.reduce(0.0) { $0 + $1.value }
                pop1.organisms[i].fitness = fit1
                pop2.organisms[i].fitness = fit2
            }

            XCTAssertEqual(
                pop1.organisms.map(\.genotype),
                pop2.organisms.map(\.genotype),
                "Populations evolved with identical seeds must produce identical genotypes."
            )
        }
    }

    // MARK: - 1.2 Truncation Selection Guard & Filling

    func testTruncationZeroTakePortionThrows() async {
        let env = makeEnvironment(
            populationSize: 50,
            selectionMethod: .truncation(takePortion: 0.01),
            selectableProportion: 1.0,
            numberOfElites: 0,
            numberOfEliteCopies: 0
        )
        var pop = makePopulation(env: env)

        do {
            try await pop.epoch()
            XCTFail("Expected configurationError when takeCount is 0.")
        } catch GeneticError.configurationError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTruncationSmallPortionFillsPopulation() async throws {
        let env = makeEnvironment(
            populationSize: 10,
            selectionMethod: .truncation(takePortion: 0.2),
            selectableProportion: 1.0,
            numberOfElites: 0,
            numberOfEliteCopies: 0
        )
        var pop = makePopulation(env: env)
        try await pop.epoch()
        XCTAssertEqual(pop.organisms.count, 10)
    }

    // MARK: - 1.3 Organism.< Strict Weak Ordering

    func testOrganismStrictWeakOrderingWithNilAndNaN() {
        let g = StringGenome(genes: [RealGene(value: 0.0)])
        let values: [Double?] = [nil, .nan, 5.0, -10.0, nil, 0.0, .nan, -.infinity, .infinity, -10.0]
        let organisms = values.map { Organism(fitness: $0, genotype: g) }

        // Verify irreflexivity and asymmetry for all pairs.
        for a in organisms {
            XCTAssertFalse(a < a, "Irreflexivity violated")
            for b in organisms {
                if a < b {
                    XCTAssertFalse(b < a, "Asymmetry violated")
                }
            }
        }

        let sorted = organisms.sorted()
        // First 4 elements must be the nil / NaN organisms.
        for i in 0..<4 {
            let f = sorted[i].fitness
            XCTAssertTrue(f == nil || f!.isNaN, "Expected nil or NaN at index \(i), got \(String(describing: f))")
        }
        // Remaining 6 elements must be sorted ascending: [-inf, -10, -10, 0, 5, +inf].
        let validFitnesses = sorted[4...].compactMap(\.fitness)
        XCTAssertEqual(validFitnesses, [-.infinity, -10.0, -10.0, 0.0, 5.0, .infinity])
    }

    // MARK: - 1.4 RandomSource Codable State Preservation

    func testRandomSourceCodablePreservesStateAndDoesNotMutate() throws {
        let rng1 = RandomSource(seed: 987654321)
        let rngControl = RandomSource(seed: 987654321)

        // Advance both identically.
        for _ in 0..<15 {
            _ = rng1.randomDouble()
            _ = rngControl.randomDouble()
        }

        // Encode rng1 and decode rng2. Encoding must NOT advance rng1.
        let data = try JSONEncoder().encode(rng1)
        let rng2 = try JSONDecoder().decode(RandomSource.self, from: data)

        let seq1 = (0..<20).map { _ in rng1.randomDouble() }
        let seq2 = (0..<20).map { _ in rng2.randomDouble() }
        let seqControl = (0..<20).map { _ in rngControl.randomDouble() }

        XCTAssertEqual(seq1, seqControl, "Encoding RandomSource must not mutate its generator state.")
        XCTAssertEqual(seq2, seqControl, "Decoded RandomSource must continue the exact RNG stream.")
    }

    func testRandomSourceDecodesLegacySeedFormat() throws {
        let legacyJSON = Data(#"{"seed": 42}"#.utf8)
        let decoded = try JSONDecoder().decode(RandomSource.self, from: legacyJSON)
        let fresh = RandomSource(seed: 42)
        XCTAssertEqual(decoded.randomDouble(), fresh.randomDouble())
    }

    // MARK: - 1.5 Roulette Selection with Negative Fitnesses

    func testRouletteSelectionWithNegativeFitnesses() throws {
        let env = makeEnvironment(populationSize: 4, selectionMethod: .roulette, seed: 777)
        var pop = Population<StringGenome>(environment: env, evolutionType: .standard)
        let fitnesses = [-100.0, -90.0, -50.0, -1.0]
        pop.organisms = fitnesses.enumerated().map { idx, fit in
            Organism(fitness: fit, genotype: StringGenome(genes: [RealGene(value: Double(idx))]))
        }
        pop.updateFitnessMetrics()

        var counts = [Double: Int]()
        for _ in 0..<1000 {
            let picked = try pop.organismFromRoulette()
            counts[picked.fitness!, default: 0] += 1
        }

        // -100.0 has shifted weight 0, -1.0 has shifted weight 99.
        XCTAssertEqual(counts[-100.0, default: 0], 0)
        XCTAssertGreaterThan(counts[-1.0, default: 0], counts[-90.0, default: 0] * 3)
    }

    // MARK: - 1.6 NSGA2 Empty Population Guard

    func testNSGA2SortAndTruncateEmptyOrZero() {
        let empty: [Organism<StringGenome>] = []
        XCTAssertTrue(NSGA2.sortAndTruncate(empty, to: 10).isEmpty)

        var org = Organism(genotype: StringGenome(genes: [RealGene(value: 1.0)]))
        org.objectives = [1.0, 2.0]
        XCTAssertTrue(NSGA2.sortAndTruncate([org], to: 0).isEmpty)
    }

    // MARK: - 3.4 TreeGenome Incremental Subtree Size Invariant

    enum MultiTreeOp: Int, TreeGeneType {
        case add, sub, neg, sin, x, y
        var childCount: Int {
            switch self {
            case .add, .sub: return 2
            case .neg, .sin: return 1
            case .x, .y: return 0
            }
        }
        static var binaryTypes: [MultiTreeOp] { [.add, .sub] }
        static var unaryTypes: [MultiTreeOp] { [.neg, .sin] }
        static var leafTypes: [MultiTreeOp] { [.x, .y] }
    }

    func testTreeGenomeIncrementalSubtreeSizesMatchFullRecalculation() throws {
        let template = TreeGeneTemplate<MultiTreeOp>(
            binaryTypes: MultiTreeOp.binaryTypes,
            unaryTypes: MultiTreeOp.unaryTypes,
            leafTypes: MultiTreeOp.leafTypes
        )
        let env = TreeEnvironment(
            populationSize: 10,
            selectionMethod: .tournament(size: 2),
            selectableProportion: 1.0,
            mutationRate: 0.5,
            crossoverRate: 0.5,
            numberOfElites: 0,
            numberOfEliteCopies: 0,
            parameters: [:],
            scalarMutationMagnitude: 1,
            structuralMutationDeletionRate: 0.35,
            structuralMutationAdditionRate: 0.35,
            randomSource: RandomSource(seed: 2026)
        )

        for _ in 0..<200 {
            var tree = try TreeGenome<MultiTreeOp>.random(depth: 1, template: template, environment: env)
            for _ in 0..<5 {
                try tree.mutate(rate: 0.5, environment: env)
                var expected = tree
                expected.recalculateSubtreeSizes()
                XCTAssertEqual(tree.nodes, expected.nodes, "Incremental subtreeSize diverged from full recalculation.")
            }
        }
    }

    // MARK: - Intra-Chunk Cache Deduplication

    private actor CountingEvaluator: FitnessEvaluator {
        typealias G = PermutationGenome<Int>
        var calls = 0
        func fitnessFor(organism: Organism<G>) async throws -> Double {
            calls += 1
            return Double(calls)
        }
        func objectivesFor(organism: Organism<G>) async throws -> [Double] {
            calls += 1
            return [Double(calls), Double(calls)]
        }
    }

    private struct NoopLogger: EvolutionLoggingDelegate {
        typealias G = PermutationGenome<Int>
        func evolutionStartingEpoch(_ i: Int) {}
        func evolutionFinishedEpoch(_ i: Int, duration: TimeInterval, population: Population<G>) {}
        func evolutionFoundSolution(_ solution: G, fitness: Double) {}
    }

    func testEvaluatePopulationDeduplicatesWithinChunk() async throws {
        let env = PermutationEnvironment(populationSize: 4, selectionMethod: .nsga2, numberOfElites: 0, numberOfEliteCopies: 0)
        var pop = Population<PermutationGenome<Int>>(environment: env, evolutionType: .nsga2)
        pop.organisms = (0..<4).map { _ in Organism(genotype: PermutationGenome(elements: [0, 1])) }

        let eval = CountingEvaluator()
        let ga = GeneticAlgorithm(fitnessEvaluator: eval, loggingDelegate: NoopLogger())
        try await ga.evolve(population: &pop, configuration: .init(maxEpochs: 0, algorithmType: .nsga2, parallelEvaluationThreads: 1))

        let totalCalls = await eval.calls
        XCTAssertEqual(totalCalls, 1, "Identical genomes within the same evaluation chunk should only be evaluated once.")
    }
}
