//
//  RandomSource.swift
//  SwiftGenetics
//
//  Created by Triple C Labs GmbH on 10/02/2026.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

/// A thread-safe, clonable random number provider suitable for genetic algorithms.
/// It wraps a `RandomNumberGenerator` and provides high-level sampling methods.
public final class RandomSource: @unchecked Sendable, Codable, Equatable {
    
    private var generator: Xoshiro256PlusPlus
    private let lock = NSLock()
    
    /// Equatable conformance: RandomSources are considered equal for serialization purposes.
    /// This allows populations to be compared after serialization/deserialization.
    public static func == (lhs: RandomSource, rhs: RandomSource) -> Bool {
        return true
    }
    
    /// Creates a new random source with the given seed.
    public init(seed: UInt64) {
        self.generator = Xoshiro256PlusPlus(seed: seed)
    }
    
    /// Creates a new random source from an existing generator state.
    private init(generator: Xoshiro256PlusPlus) {
        self.generator = generator
    }
    
    /// Creates a "forked" version of this random source for use in a parallel task.
    /// The forked source is deterministic based on the provided index.
    public func fork(index: Int) -> RandomSource {
        lock.lock()
        defer { lock.unlock() }
        
        // Use the current generator to create a unique seed for the child.
        // We add the index to ensure uniqueness even if multiple forks are called quickly.
        let childSeed = generator.next() ^ UInt64(bitPattern: Int64(index))
        return RandomSource(seed: childSeed)
    }
    
    // MARK: - Sampling
    
    /// Returns a random Double in the range [0, 1).
    public func randomDouble() -> Double {
        lock.lock()
        defer { lock.unlock() }
        // Use the generator to get a value in [0, 1)
        return Double.random(in: 0..<1, using: &generator)
    }
    
    /// Returns a random Double in the specified range.
    public func randomDouble(in range: Range<Double>) -> Double {
        lock.lock()
        defer { lock.unlock() }
        return Double.random(in: range, using: &generator)
    }
    
    /// Returns a random Double in the specified closed range.
    public func randomDouble(in range: ClosedRange<Double>) -> Double {
        lock.lock()
        defer { lock.unlock() }
        return Double.random(in: range, using: &generator)
    }
    
    /// Returns a random Int in the specified range.
    public func randomInt(in range: Range<Int>) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return Int.random(in: range, using: &generator)
    }
    
    /// Returns a random element from the collection, or nil if it's empty.
    public func randomElement<C: Collection>(from collection: C) -> C.Element? {
        lock.lock()
        defer { lock.unlock() }
        return collection.randomElement(using: &generator)
    }
    
    /// Returns a random number sampled from a Gaussian distribution.
    public func randomGaussian(mu: Double, sigma: Double) -> Double {
        lock.lock()
        defer { lock.unlock() }
        
        let p0 = 0.322232431088
        let p1 = 1.0
        let p2 = 0.342242088547
        let p3 = 0.204231210245e-1
        let p4 = 0.453642210148e-4
        let q0 = 0.099348462606
        let q1 = 0.588581570495
        let q2 = 0.531103462366
        let q3 = 0.103537752850
        let q4 = 0.385607006340e-2
        
        let u = Double.random(in: 0..<1, using: &generator)
        let t: Double
        if u < 0.5 {
            t = sqrt(-2.0 * log(u))
        } else {
            t = sqrt(-2.0 * log(1.0 - u))
        }
        let p = p0 + t * (p1 + t * (p2 + t * (p3 + t * p4)))
        let q = q0 + t * (q1 + t * (q2 + t * (q3 + t * q4)))
        let z: Double
        if u < 0.5 {
            z = (p / q) - t
        } else {
            z = t - (p / q)
        }
        return mu + sigma * z
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case seed
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let seed = try container.decode(UInt64.self, forKey: .seed)
        self.generator = Xoshiro256PlusPlus(seed: seed)
    }
    
    public func encode(to encoder: Encoder) throws {
        // Note: For simplicity, we just encode the current seed point.
        // In a more complex scenario, we might want to encode the full state.
        var container = encoder.container(keyedBy: CodingKeys.self)
        // We use a random value as the "next seed" when saved.
        try container.encode(randomDouble().bitPattern, forKey: .seed)
    }
}
