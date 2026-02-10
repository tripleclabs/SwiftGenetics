//
//  Entropy.swift
//  SwiftGenetics
//
//  Created by Triple C Labs GmbH on 10/02/2026.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

/// A fast, seedable 64-bit random number generator using the xoshiro256++ algorithm.
/// Reference: https://prng.di.unimi.it/xoshiro256plusplus.c
public struct Xoshiro256PlusPlus: RandomNumberGenerator, Sendable {
    private var s0: UInt64
    private var s1: UInt64
    private var s2: UInt64
    private var s3: UInt64

    /// Initializes the generator with a 64-bit seed.
    public init(seed: UInt64) {
        // Use splitmix64 to seed the state, as xoshiro requires non-zero state components.
        var sm = SplitMix64(state: seed)
        self.s0 = sm.next()
        self.s1 = sm.next()
        self.s2 = sm.next()
        self.s3 = sm.next()
    }
    
    /// Initializes the generator with the full 256-bit state.
    public init(s0: UInt64, s1: UInt64, s2: UInt64, s3: UInt64) {
        self.s0 = s0
        self.s1 = s1
        self.s2 = s2
        self.s3 = s3
    }

    public mutating func next() -> UInt64 {
        let result = rotl(s0 &+ s3, 23) &+ s0

        let t = s1 << 17

        s2 ^= s0
        s3 ^= s1
        s1 ^= s2
        s0 ^= s3

        s2 ^= t

        s3 = rotl(s3, 45)

        return result
    }

    private func rotl(_ x: UInt64, _ k: Int) -> UInt64 {
        return (x << k) | (x >> (64 - k))
    }
}

/// A helper generator for seeding other generators.
private struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
