import XCTest
import SwiftGenetics

final class PermutationCrossoverEquivalenceTests: XCTestCase {
    // Frozen pre-optimization algorithm, driven by the same random sequence.
    private func legacy(_ a: [Int], _ b: [Int], rate: Double, random: RandomSource) -> ([Int], [Int]) {
        guard random.randomDouble() < rate, a.count > 1 else { return (a, b) }
        func child(_ p: [Int], _ q: [Int]) -> [Int] {
            let n = p.count
            let start = random.randomInt(in: 0..<n - 1)
            let end = random.randomInt(in: start + 1..<n)
            let slice = p[start...end]
            var result = [Int?](repeating: nil, count: n)
            for i in start...end { result[i] = p[i] }
            var source = (end + 1) % n, destination = source
            while destination != start {
                if !slice.contains(q[source]) {
                    result[destination] = q[source]
                    destination = (destination + 1) % n
                }
                source = (source + 1) % n
            }
            return result.map { $0! }
        }
        return (child(a, b), child(b, a))
    }

    func testCrossoverPreservesChildrenAndRandomConsumption() {
        for size in [0, 1, 2, 7, 64, 128] {
            let a = Array(0..<size), b = Array(a.reversed())
            for seed in 0..<32 {
                for rate in [0.0, 0.5, 1.0] {
                    let actualRandom = RandomSource(seed: UInt64(seed))
                    let referenceRandom = RandomSource(seed: UInt64(seed))
                    let environment = PermutationEnvironment(populationSize: 2, randomSource: actualRandom)
                    let actual = PermutationGenome(elements: a).crossover(with: .init(elements: b), rate: rate, environment: environment)
                    let expected = legacy(a, b, rate: rate, random: referenceRandom)
                    XCTAssertEqual(actual.0.elements, expected.0)
                    XCTAssertEqual(actual.1.elements, expected.1)
                    XCTAssertEqual(Set(actual.0.elements), Set(a))
                    XCTAssertEqual(Set(actual.1.elements), Set(b))
                    XCTAssertEqual(actualRandom.randomDouble(), referenceRandom.randomDouble())
                }
            }
        }
    }
}
