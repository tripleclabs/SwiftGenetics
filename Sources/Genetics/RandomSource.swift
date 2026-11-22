//
//  RandomSource.swift
//  SwiftGenetics
//
//  Created by Triple C Labs GmbH on 10/02/2026.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation
import Synchronization

/// A thread-safe, clonable random number provider suitable for genetic algorithms.
/// It wraps a `RandomNumberGenerator` in a `Synchronization.Mutex` and provides high-level sampling methods.
public final class RandomSource: Sendable, Codable, Equatable {
    
    @usableFromInline internal let generator: Mutex<Xoshiro256PlusPlus>
    
    /// Equatable conformance: RandomSources are considered equal for serialization purposes.
    /// This allows populations to be compared after serialization/deserialization.
    public static func == (lhs: RandomSource, rhs: RandomSource) -> Bool {
        return true
    }
    
    /// Creates a new random source with the given seed.
    public init(seed: UInt64) {
        self.generator = Mutex(Xoshiro256PlusPlus(seed: seed))
    }
    
    /// Creates a new random source from an existing generator state.
    private init(generator: Xoshiro256PlusPlus) {
        self.generator = Mutex(generator)
    }
    
    /// Creates a "forked" version of this random source for use in a parallel task.
    /// The forked source is deterministic based on the provided index.
    public func fork(index: Int) -> RandomSource {
        let childSeed = generator.withLock { rng in
            rng.next() ^ UInt64(bitPattern: Int64(index))
        }
        return RandomSource(seed: childSeed)
    }
    
    // MARK: - Sampling
    
    /// Acquires the mutex once and provides direct mutable access to the underlying generator.
    /// Use this to amortize lock overhead across hot loops (e.g. batch selection or mutation).
    @inlinable
    public func withGenerator<T>(_ body: (inout Xoshiro256PlusPlus) throws -> T) rethrows -> T {
        return try generator.withLock { rng in
            try body(&rng)
        }
    }
    
    /// Samples a Gaussian value using the provided generator directly (without locking).
    @inlinable
    public static func sampleGaussian<RNG: RandomNumberGenerator>(mu: Double, sigma: Double, using generator: inout RNG) -> Double {
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
        
        let u = Double.random(in: Double.leastNonzeroMagnitude..<1.0, using: &generator)
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
    
    /// Returns a random Double in the range [0, 1).
    @inlinable
    public func randomDouble() -> Double {
        generator.withLock { rng in
            Double.random(in: 0..<1, using: &rng)
        }
    }
    
    /// Returns a random Double in the specified range.
    @inlinable
    public func randomDouble(in range: Range<Double>) -> Double {
        generator.withLock { rng in
            Double.random(in: range, using: &rng)
        }
    }
    
    /// Returns a random Double in the specified closed range.
    @inlinable
    public func randomDouble(in range: ClosedRange<Double>) -> Double {
        generator.withLock { rng in
            Double.random(in: range, using: &rng)
        }
    }
    
    /// Returns a random Int in the specified range.
    @inlinable
    public func randomInt(in range: Range<Int>) -> Int {
        generator.withLock { rng in
            Int.random(in: range, using: &rng)
        }
    }
    
    /// Returns a random element from the collection, or nil if it's empty.
    @inlinable
    public func randomElement<C: Collection>(from collection: C) -> C.Element? {
        guard !collection.isEmpty else { return nil }
        let offset = generator.withLock { rng in
            Int.random(in: 0..<collection.count, using: &rng)
        }
        return collection[collection.index(collection.startIndex, offsetBy: offset)]
    }
    
    /// Returns a random number sampled from a Gaussian distribution.
    @inlinable
    public func randomGaussian(mu: Double, sigma: Double) -> Double {
        generator.withLock { rng in
            Self.sampleGaussian(mu: mu, sigma: sigma, using: &rng)
        }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case seed
        case state
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let state = try container.decodeIfPresent(Xoshiro256PlusPlus.self, forKey: .state) {
            self.generator = Mutex(state)
        } else {
            let seed = try container.decode(UInt64.self, forKey: .seed)
            self.generator = Mutex(Xoshiro256PlusPlus(seed: seed))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        let snapshot = generator.withLock { $0 }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(snapshot, forKey: .state)
    }
}
