import Foundation
import Testing
import SwiftGenetics

@Suite("Genetic cancellation", .timeLimit(.minutes(1)))
struct GeneticCancellationTests {
    typealias G = PermutationGenome<Int>
    struct Log: EvolutionLoggingDelegate {
        typealias G = PermutationGenome<Int>
        func evolutionStartingEpoch(_ i: Int) {}
        func evolutionFinishedEpoch(_ i: Int, duration: TimeInterval, population: Population<G>) {}
        func evolutionFoundSolution(_ solution: G, fitness: Double) {}
    }
    enum Failure: Error { case translatedCancellation }
    struct Evaluator: FitnessEvaluator {
        typealias G = PermutationGenome<Int>
        let started: AsyncStream<Void>.Continuation?
        var translated = false
        var succeed = false
        func fitnessFor(organism: Organism<G>) async throws -> Double {
            if succeed { return 1 }
            guard let started else { throw CancellationError() }
            started.yield(())
            do { try await Task.sleep(for: .seconds(10)) }
            catch { if translated { throw Failure.translatedCancellation }; throw error }
            return 1
        }
        func objectivesFor(organism: Organism<G>) async throws -> [Double] {
            [try await fitnessFor(organism: organism)]
        }
    }
    func population(_ type: EvolutionAlgorithmType, evaluated: Bool = false) -> Population<G> {
        let env = PermutationEnvironment(populationSize: 4, selectionMethod: type == .nsga2 ? .nsga2 : .tournament(size: 2), mutationRate: 0, crossoverRate: 0, numberOfElites: 0)
        var p = Population<G>(environment: env, evolutionType: type)
        p.organisms = (0..<4).map { _ in
            var o = Organism(genotype: G(elements: [0, 1]))
            if evaluated { o.fitness = 1; o.objectives = [1] }
            return o
        }
        return p
    }
    @Test(arguments: [EvolutionAlgorithmType.standard, .nsga2])
    func evaluatorCancellationIsNotConvertedToFitness(_ type: EvolutionAlgorithmType) async {
        var p = population(type)
        let ga = GeneticAlgorithm(fitnessEvaluator: Evaluator(started: nil), loggingDelegate: Log())
        await #expect(throws: CancellationError.self) {
            try await ga.evolve(population: &p, configuration: .init(maxEpochs: 3, algorithmType: type))
        }
        #expect(p.generation == 0)
        #expect(p.organisms.allSatisfy { $0.fitness == nil && $0.objectives == nil })
    }
    @Test(arguments: [EvolutionAlgorithmType.standard, .nsga2], [false, true])
    func parentCancellationInterruptsEvaluation(_ type: EvolutionAlgorithmType, translated: Bool) async {
        let (stream, started) = AsyncStream<Void>.makeStream()
        let task = Task {
            var p = population(type)
            let ga = GeneticAlgorithm(fitnessEvaluator: Evaluator(started: started, translated: translated), loggingDelegate: Log())
            try await ga.evolve(population: &p, configuration: .init(maxEpochs: 3, algorithmType: type, parallelEvaluationThreads: 2))
        }
        var iterator = stream.makeAsyncIterator()
        await iterator.next()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        started.finish()
    }
    @Test(arguments: [EvolutionAlgorithmType.standard, .nsga2])
    func preCancelledEvaluatedPopulationStops(_ type: EvolutionAlgorithmType) async {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            var p = population(type, evaluated: true)
            let ga = GeneticAlgorithm(fitnessEvaluator: Evaluator(started: nil, succeed: true), loggingDelegate: Log())
            try await ga.evolve(population: &p, configuration: .init(maxEpochs: 3, algorithmType: type))
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
    @Test(arguments: [EvolutionAlgorithmType.standard, .nsga2])
    func cancellationFromEpochCallbackStopsCachedEvolution(_ type: EvolutionAlgorithmType) async {
        let task = Task {
            var p = population(type)
            var ga = GeneticAlgorithm(fitnessEvaluator: Evaluator(started: nil, succeed: true), loggingDelegate: Log())
            ga.afterEachEpoch { _ in withUnsafeCurrentTask { $0?.cancel() } }
            do {
                try await ga.evolve(population: &p, configuration: .init(maxEpochs: 3, algorithmType: type))
                Issue.record("Evolution returned success after cancellation")
            } catch is CancellationError { #expect(p.generation == 1) }
            catch { Issue.record("Unexpected error: \(error)") }
        }
        await task.value
    }
}
