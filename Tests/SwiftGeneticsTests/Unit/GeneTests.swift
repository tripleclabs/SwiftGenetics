import XCTest
@testable import SwiftGenetics

final class GeneTests: XCTestCase {
    
    struct MockEnv: GeneticEnvironment {
        var populationSize: Int = 10
        var selectionMethod: SelectionMethod = .roulette
        var selectableProportion: Double = 1.0
        var mutationRate: Double = 1.0
        var crossoverRate: Double = 1.0
        var numberOfElites: Int = 0
        var numberOfEliteCopies: Int = 0
        var parameters: [String : AnyCodable] = [:]
    }
    
    // MARK: - ContinuousGene
    
    func testContinuousGeneMutation() throws {
        var gene = ContinuousGene<Double, MockEnv>(value: 0.5)
        let env = MockEnv(parameters: [
            ContinuousEnvironmentParameter.mutationSize.rawValue: AnyCodable(0.1),
            ContinuousEnvironmentParameter.mutationType.rawValue: AnyCodable(ContinuousMutationType.uniform.rawValue)
        ])
        
        // Mutate should change the value
        try gene.mutate(rate: 1.0, environment: env)
        XCTAssertNotEqual(gene.value, 0.5)
    }
    
    // MARK: - DiscreteChoiceGene
    
    func testDiscreteChoiceGeneMutation() throws {
        enum Choice: String, DiscreteChoice {
            case a, b, c
        }
        
        var gene = DiscreteChoiceGene<Choice, MockEnv>(choice: .a)
        let env = MockEnv()
        
        // Mutate should change the value eventually (stochastic but with rate 1.0 it should)
        try gene.mutate(rate: 1.0, environment: env)
    }
    
    // MARK: - Probability Distributions
    
    func testGaussianDistribution() {
        var values = [Double]()
        for _ in 0..<1000 {
            values.append(Double.randomGaussian(mu: 0, sigma: 1))
        }
        
        let average = values.reduce(0, +) / Double(values.count)
        XCTAssertEqual(average, 0.0, accuracy: 0.2)
        
        let variance = values.map { pow($0 - average, 2) }.reduce(0, +) / Double(values.count)
        XCTAssertEqual(variance, 1.0, accuracy: 0.2)
    }

    static let allTests = [
        ("testContinuousGeneMutation", testContinuousGeneMutation),
        ("testDiscreteChoiceGeneMutation", testDiscreteChoiceGeneMutation),
        ("testGaussianDistribution", testGaussianDistribution),
    ]
}
