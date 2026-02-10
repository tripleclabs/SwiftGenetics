import XCTest
import SwiftGenetics

final class UtilityTests: XCTestCase {
    
    func testAnyCodableEncodingDecoding() throws {
        let dict: [String: Codable] = [
            "string": "hello",
            "int": 42,
            "double": 3.14,
            "bool": true,
            "array": [1, 2, 3] as [Int],
            "nested": ["a": 1] as [String: Int]
        ]
        
        let anyCodableDict = dict.mapValues { AnyCodable($0) }
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodableDict)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([String: AnyCodable].self, from: data)
        
        XCTAssertEqual(decoded["string"]?.value as? String, "hello")
        XCTAssertEqual(decoded["int"]?.value as? Int, 42)
        XCTAssertEqual(decoded["double"]?.value as? Double, 3.14)
        XCTAssertEqual(decoded["bool"]?.value as? Bool, true)
        XCTAssertEqual(decoded["array"]?.value as? [Int], [1, 2, 3])
        XCTAssertEqual((decoded["nested"]?.value as? [String: Int])?["a"], 1)
    }
    
    func testAnyCodableEquality() {
        let a = AnyCodable(1)
        let b = AnyCodable(1)
        let c = AnyCodable(2)
        let d = AnyCodable("1")
        
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertNotEqual(a, d)
        
        let dict1 = AnyCodable(["a": 1, "b": 2])
        let dict2 = AnyCodable(["b": 2, "a": 1])
        XCTAssertEqual(dict1, dict2) // Sorted keys in AnyCodable.==
    }
    
    func testSelectionMethodSerialization() throws {
        let methods: [SelectionMethod] = [
            .roulette,
            .tournament(size: 3),
            .truncation(takePortion: 0.5)
        ]
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for method in methods {
            let data = try encoder.encode(method)
            let decoded = try decoder.decode(SelectionMethod.self, from: data)
            XCTAssertEqual(method, decoded)
        }
    }

    func testFitnessResult() {
        let result = FitnessResult(fitness: 10.0)
        XCTAssertEqual(result.fitness, 10.0)
    }

    static let allTests = [
        ("testAnyCodableEncodingDecoding", testAnyCodableEncodingDecoding),
        ("testAnyCodableEquality", testAnyCodableEquality),
        ("testSelectionMethodSerialization", testSelectionMethodSerialization),
    ]
}
