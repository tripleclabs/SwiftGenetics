import Foundation
import SwiftGenetics

// MARK: - Shared Helpers

struct SilentLogger<G: Genome>: EvolutionLoggingDelegate {
    func evolutionStartingEpoch(_ i: Int) {}
    func evolutionFinishedEpoch(_ i: Int, duration: TimeInterval, population: Population<G>) {}
    func evolutionFoundSolution(_ solution: G, fitness: Double) {}
}

func measureMs(_ label: String, block: @Sendable () async throws -> Void) async throws {
    let start = DispatchTime.now().uptimeNanoseconds
    try await block()
    let end = DispatchTime.now().uptimeNanoseconds
    let ms = Double(end - start) / 1_000_000.0
    print(String(format: "%-46s %8.2f ms", (label as NSString).utf8String!, ms))
}

// MARK: - 1 & 2. Rastrigin Benchmark (LivingStringGenome)

typealias RealGene = ContinuousGene<Double, LivingStringEnvironment>
typealias RealGenome = LivingStringGenome<RealGene>

struct RastriginEvaluator: FitnessEvaluator {
    typealias G = RealGenome
    func fitnessFor(organism: Organism<RealGenome>) async throws -> Double {
        let a = 10.0
        var sum = a * Double(organism.genotype.genes.count)
        for gene in organism.genotype.genes {
            let x = gene.value
            sum += x * x - a * cos(2.0 * .pi * x)
        }
        // Negate for maximization (higher is better).
        return -sum
    }
}

func runRastrigin(selection: SelectionMethod, populationSize: Int, geneCount: Int, epochs: Int) async throws {
    let rng = RandomSource(seed: 42)
    let env = LivingStringEnvironment(
        populationSize: populationSize,
        selectionMethod: selection,
        selectableProportion: 1.0,
        mutationRate: 0.1,
        crossoverRate: 0.8,
        numberOfElites: 2,
        numberOfEliteCopies: 1,
        parameters: [
            ContinuousEnvironmentParameter.mutationSize.rawValue: AnyCodable(0.25),
            ContinuousEnvironmentParameter.mutationType.rawValue: AnyCodable(ContinuousMutationType.gaussian.rawValue)
        ],
        randomSource: rng
    )
    var pop = Population<RealGenome>(environment: env, evolutionType: .standard)
    pop.organisms = (0..<populationSize).map { _ in
        let genes = (0..<geneCount).map { _ in RealGene(value: rng.randomDouble(in: -5.12...5.12)) }
        return Organism(genotype: RealGenome(genes: genes))
    }
    let ga = GeneticAlgorithm(fitnessEvaluator: RastriginEvaluator(), loggingDelegate: SilentLogger<RealGenome>())
    let config = EvolutionAlgorithmConfiguration(maxEpochs: epochs, algorithmType: .standard)
    try await ga.evolve(population: &pop, configuration: config)
}

// MARK: - 3. TSP Benchmark (PermutationGenome)

struct TSPEvaluator: FitnessEvaluator {
    typealias G = PermutationGenome<Int>
    let coords: [(Double, Double)]

    init(cityCount: Int) {
        let rng = RandomSource(seed: 101)
        self.coords = (0..<cityCount).map { _ in (rng.randomDouble() * 100.0, rng.randomDouble() * 100.0) }
    }

    func fitnessFor(organism: Organism<PermutationGenome<Int>>) async throws -> Double {
        let route = organism.genotype.elements
        var dist = 0.0
        for i in 0..<route.count {
            let a = coords[route[i]]
            let b = coords[route[(i + 1) % route.count]]
            let dx = a.0 - b.0
            let dy = a.1 - b.1
            dist += sqrt(dx * dx + dy * dy)
        }
        return -dist
    }
}

func runTSP(populationSize: Int, cityCount: Int, epochs: Int) async throws {
    let rng = RandomSource(seed: 42)
    let env = PermutationEnvironment(
        populationSize: populationSize,
        selectionMethod: .tournament(size: 3),
        selectableProportion: 1.0,
        mutationRate: 0.2,
        crossoverRate: 0.8,
        numberOfElites: 2,
        numberOfEliteCopies: 1,
        randomSource: rng
    )
    var pop = Population<PermutationGenome<Int>>(environment: env, evolutionType: .standard)
    let base = Array(0..<cityCount)
    pop.organisms = (0..<populationSize).map { _ in
        var shuffled = base
        for i in stride(from: cityCount - 1, through: 1, by: -1) {
            let j = rng.randomInt(in: 0..<(i + 1))
            shuffled.swapAt(i, j)
        }
        return Organism(genotype: PermutationGenome(elements: shuffled))
    }
    let ga = GeneticAlgorithm(fitnessEvaluator: TSPEvaluator(cityCount: cityCount), loggingDelegate: SilentLogger<PermutationGenome<Int>>())
    let config = EvolutionAlgorithmConfiguration(maxEpochs: epochs, algorithmType: .standard)
    try await ga.evolve(population: &pop, configuration: config)
}

// MARK: - 4. Symbolic Regression Benchmark (TreeGenome)

enum SymRegOp: Int, TreeGeneType {
    case add, sub, mul, sin, cos, x, c1, c2

    var childCount: Int {
        switch self {
        case .add, .sub, .mul: return 2
        case .sin, .cos: return 1
        case .x, .c1, .c2: return 0
        }
    }

    static var binaryTypes: [SymRegOp] { [.add, .sub, .mul] }
    static var unaryTypes: [SymRegOp] { [.sin, .cos] }
    static var leafTypes: [SymRegOp] { [.x, .c1, .c2] }
}

struct SymRegEvaluator: FitnessEvaluator {
    typealias G = TreeGenome<SymRegOp>

    private func eval(_ nodes: [FlatTreeNode<SymRegOp>], index: inout Int, x: Double) -> Double {
        guard index < nodes.count else { return 0.0 }
        let op = nodes[index].geneType
        index += 1
        switch op {
        case .add:
            let l = eval(nodes, index: &index, x: x)
            let r = eval(nodes, index: &index, x: x)
            return l + r
        case .sub:
            let l = eval(nodes, index: &index, x: x)
            let r = eval(nodes, index: &index, x: x)
            return l - r
        case .mul:
            let l = eval(nodes, index: &index, x: x)
            let r = eval(nodes, index: &index, x: x)
            return l * r
        case .sin:
            return sin(eval(nodes, index: &index, x: x))
        case .cos:
            return cos(eval(nodes, index: &index, x: x))
        case .x:
            return x
        case .c1:
            return 1.0
        case .c2:
            return 2.0
        }
    }

    func fitnessFor(organism: Organism<TreeGenome<SymRegOp>>) async throws -> Double {
        let nodes = organism.genotype.nodes
        var mse = 0.0
        for step in -5...5 {
            let x = Double(step) * 0.5
            var idx = 0
            let pred = eval(nodes, index: &idx, x: x)
            let target = x * x + sin(x)
            let err = pred - target
            mse += err * err
        }
        let result = -mse / 11.0
        return result.isFinite ? result : -1e9
    }
}

func runSymbolicRegression(populationSize: Int, epochs: Int) async throws {
    let rng = RandomSource(seed: 42)
    let template = TreeGeneTemplate<SymRegOp>(
        binaryTypes: SymRegOp.binaryTypes,
        unaryTypes: SymRegOp.unaryTypes,
        leafTypes: SymRegOp.leafTypes
    )
    let env = TreeEnvironment(
        populationSize: populationSize,
        selectionMethod: .tournament(size: 3),
        selectableProportion: 1.0,
        mutationRate: 0.25,
        crossoverRate: 0.7,
        numberOfElites: 2,
        numberOfEliteCopies: 1,
        parameters: [:],
        scalarMutationMagnitude: 1,
        structuralMutationDeletionRate: 0.2,
        structuralMutationAdditionRate: 0.2,
        randomSource: rng
    )
    var pop = Population<TreeGenome<SymRegOp>>(environment: env, evolutionType: .standard)
    pop.organisms = try (0..<populationSize).map { _ in
        let tree = try TreeGenome<SymRegOp>.random(depth: 1, template: template, environment: env)
        return Organism(genotype: tree)
    }
    let ga = GeneticAlgorithm(fitnessEvaluator: SymRegEvaluator(), loggingDelegate: SilentLogger<TreeGenome<SymRegOp>>())
    let config = EvolutionAlgorithmConfiguration(maxEpochs: epochs, algorithmType: .standard)
    try await ga.evolve(population: &pop, configuration: config)
}

// MARK: - 5. NSGA-II Sort & Truncate Benchmark

func runNSGA2Sort(populationSize: Int, objectives: Int, iterations: Int) {
    let rng = RandomSource(seed: 42)
    let base: [Organism<RealGenome>] = (0..<(populationSize * 2)).map { _ in
        var org = Organism(genotype: RealGenome(genes: [RealGene(value: 0.0)]))
        org.objectives = (0..<objectives).map { _ in rng.randomDouble() }
        return org
    }
    var checksum = 0
    for _ in 0..<iterations {
        let truncated = NSGA2.sortAndTruncate(base, to: populationSize)
        checksum &+= truncated.count
    }
    precondition(checksum == populationSize * iterations)
}

// MARK: - 6. FitnessCache Benchmark: Actor vs Lock-Protected Final Class

actor ActorFitnessCache<G: Genome> {
    private let bucketLimit: Int
    private var current: [G: Double] = [:]
    private var previous: [G: Double] = [:]

    init(maxEntries: Int = 50_000) {
        self.bucketLimit = max(1, maxEntries / 2)
    }

    func fitness(for genome: G) -> Double? {
        return current[genome] ?? previous[genome]
    }

    func fitnesses(for genomes: [G]) -> [Double?] {
        var out = [Double?]()
        out.reserveCapacity(genomes.count)
        for g in genomes {
            out.append(current[g] ?? previous[g])
        }
        return out
    }

    func setFitness(_ value: Double, for genome: G) {
        if current.count >= bucketLimit && current[genome] == nil {
            previous = current
            current = [:]
        }
        current[genome] = value
    }

    func setFitnesses(_ entries: [(G, Double)]) {
        for (g, v) in entries {
            if current.count >= bucketLimit && current[g] == nil {
                previous = current
                current = [:]
            }
            current[g] = v
        }
    }
}

func makeCacheWorkload(epochs: Int, populationSize: Int, geneCount: Int) -> [[RealGenome]] {
    let rng = RandomSource(seed: 123)
    return (0..<epochs).map { _ in
        (0..<populationSize).map { _ in
            RealGenome(genes: (0..<geneCount).map { _ in RealGene(value: rng.randomDouble(in: -5.12...5.12)) })
        }
    }
}

func runCacheActorPerItem(workload: [[RealGenome]]) async {
    let cache = ActorFitnessCache<RealGenome>()
    let cores = max(1, ProcessInfo.processInfo.activeProcessorCount)
    for generation in workload {
        let chunkSize = max(1, (generation.count + cores - 1) / cores)
        await withTaskGroup(of: Void.self) { group in
            for start in stride(from: 0, to: generation.count, by: chunkSize) {
                let slice = Array(generation[start..<min(start + chunkSize, generation.count)])
                group.addTask {
                    for g in slice {
                        if await cache.fitness(for: g) == nil {
                            await cache.setFitness(1.0, for: g)
                        }
                    }
                }
            }
        }
    }
}

func runCacheActorBatched(workload: [[RealGenome]]) async {
    let cache = ActorFitnessCache<RealGenome>()
    let cores = max(1, ProcessInfo.processInfo.activeProcessorCount)
    for generation in workload {
        let chunkSize = max(1, (generation.count + cores - 1) / cores)
        await withTaskGroup(of: Void.self) { group in
            for start in stride(from: 0, to: generation.count, by: chunkSize) {
                let slice = Array(generation[start..<min(start + chunkSize, generation.count)])
                group.addTask {
                    let hits = await cache.fitnesses(for: slice)
                    var misses = [(RealGenome, Double)]()
                    misses.reserveCapacity(slice.count)
                    for i in 0..<slice.count where hits[i] == nil {
                        misses.append((slice[i], 1.0))
                    }
                    if !misses.isEmpty {
                        await cache.setFitnesses(misses)
                    }
                }
            }
        }
    }
}

func runCacheLockPerItem(workload: [[RealGenome]]) async {
    let cache = FitnessCache<RealGenome>()
    let cores = max(1, ProcessInfo.processInfo.activeProcessorCount)
    for generation in workload {
        let chunkSize = max(1, (generation.count + cores - 1) / cores)
        await withTaskGroup(of: Void.self) { group in
            for start in stride(from: 0, to: generation.count, by: chunkSize) {
                let slice = Array(generation[start..<min(start + chunkSize, generation.count)])
                group.addTask {
                    for g in slice {
                        if cache.fitness(for: g) == nil {
                            cache.setFitness(1.0, for: g)
                        }
                    }
                }
            }
        }
    }
}

func runCacheLockBatched(workload: [[RealGenome]]) async {
    let cache = FitnessCache<RealGenome>()
    let cores = max(1, ProcessInfo.processInfo.activeProcessorCount)
    for generation in workload {
        let chunkSize = max(1, (generation.count + cores - 1) / cores)
        await withTaskGroup(of: Void.self) { group in
            for start in stride(from: 0, to: generation.count, by: chunkSize) {
                let slice = Array(generation[start..<min(start + chunkSize, generation.count)])
                group.addTask {
                    let hits = cache.fitnesses(for: slice)
                    var misses = [(RealGenome, Double)]()
                    misses.reserveCapacity(slice.count)
                    for i in 0..<slice.count where hits[i] == nil {
                        misses.append((slice[i], 1.0))
                    }
                    if !misses.isEmpty {
                        cache.setFitnesses(misses)
                    }
                }
            }
        }
    }
}

// MARK: - Entry Point

@main
struct SwiftGeneticsBenchmarks {
    static func main() async throws {
        print("SwiftGenetics Benchmarks (Release)")
        print(String(repeating: "-", count: 58))

        try await measureMs("Rastrigin Roulette (N=1000, G=100, 25 ep)") {
            try await runRastrigin(selection: .roulette, populationSize: 1000, geneCount: 100, epochs: 25)
        }
        try await measureMs("Rastrigin Tournament (N=1000, G=100, 25 ep)") {
            try await runRastrigin(selection: .tournament(size: 3), populationSize: 1000, geneCount: 100, epochs: 25)
        }
        try await measureMs("TSP Permutation (N=500, C=60, 25 ep)") {
            try await runTSP(populationSize: 500, cityCount: 60, epochs: 25)
        }
        try await measureMs("Symbolic Regression Tree (N=300, 25 ep)") {
            try await runSymbolicRegression(populationSize: 300, epochs: 25)
        }
        try await measureMs("NSGA-II Sort+Truncate (2N=1000, 3 obj, 20x)") {
            runNSGA2Sort(populationSize: 500, objectives: 3, iterations: 20)
        }

        print("")
        print("FitnessCache Comparison (25 ep x 1000 x 100-gene genomes)")
        print(String(repeating: "-", count: 58))
        let workload = makeCacheWorkload(epochs: 25, populationSize: 1000, geneCount: 100)
        try await measureMs("FitnessCache: Actor (per-item)") {
            await runCacheActorPerItem(workload: workload)
        }
        try await measureMs("FitnessCache: Actor (batched per-chunk)") {
            await runCacheActorBatched(workload: workload)
        }
        try await measureMs("FitnessCache: NSLock class (per-item)") {
            await runCacheLockPerItem(workload: workload)
        }
        try await measureMs("FitnessCache: NSLock class (batched per-chunk)") {
            await runCacheLockBatched(workload: workload)
        }
    }
}
