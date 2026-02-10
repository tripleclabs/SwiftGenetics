//
//  NSGA2.swift
//  SwiftGenetics
//
//  Created by Triple C Labs GmbH 10/02/2026.
//  Copyright © 2026 Triple C Labs GmbH. All rights reserved.
//

import Foundation

/// Provides core utility functions for the NSGA-II (Nondominated Sorting Genetic Algorithm II) algorithm.
public struct NSGA2 {
    
    /// Assigns rank and crowding distance to a population of organisms based on their objectives.
    /// - Parameters:
    ///   - organisms: The population to sort and rank.
    ///   - n: The number of organisms to keep (the desired population size).
    /// - Returns: A sorted and ranked array of organisms, truncated to size `n`.
    public static func sortAndTruncate<G: Genome>(_ organisms: [Organism<G>], to n: Int) -> [Organism<G>] {
        let population = organisms
        
        // 1. Fast non-dominated sort
        let fronts = fastNonDominatedSort(population)
        
        var newPopulation = [Organism<G>]()
        var currentFrontIndex = 0
        
        // 2. Fill the new population front by front
        while newPopulation.count + fronts[currentFrontIndex].count <= n {
            var front = fronts[currentFrontIndex].map { population[$0] }
            
            // Assign crowding distance to the front
            assignCrowdingDistance(&front)
            
            // Assign rank to organisms in this front
            for i in 0..<front.count {
                front[i].dominanceRank = currentFrontIndex
            }
            
            newPopulation.append(contentsOf: front)
            currentFrontIndex += 1
            if currentFrontIndex >= fronts.count { break }
        }
        
        // 3. Fill the remaining slots from the last front using crowding distance
        if newPopulation.count < n && currentFrontIndex < fronts.count {
            var lastFront = fronts[currentFrontIndex].map { population[$0] }
            assignCrowdingDistance(&lastFront)
            for i in 0..<lastFront.count {
                lastFront[i].dominanceRank = currentFrontIndex
            }
            
            // Sort last front by crowding distance (descending)
            lastFront.sort { $0.crowdingDistance > $1.crowdingDistance }
            
            let remainingSlots = n - newPopulation.count
            newPopulation.append(contentsOf: lastFront.prefix(remainingSlots))
        }
        
        return newPopulation
    }
    
    /// Performs a fast non-dominated sort on the given population.
    /// Returns indices of organisms grouped by their Pareto fronts.
    public static func fastNonDominatedSort<G: Genome>(_ population: [Organism<G>]) -> [[Int]] {
        let size = population.count
        var S = Array(repeating: [Int](), count: size) // Sets of organisms dominated by each individual
        var n = Array(repeating: 0, count: size)      // Number of individuals dominating each individual
        var fronts = [[Int]]()
        var currentFront = [Int]()
        
        for p in 0..<size {
            for q in 0..<size {
                if p == q { continue }
                
                if dominates(population[p], population[q]) {
                    S[p].append(q)
                } else if dominates(population[q], population[p]) {
                    n[p] += 1
                }
            }
            
            if n[p] == 0 {
                currentFront.append(p)
            }
        }
        
        fronts.append(currentFront)
        
        var i = 0
        while !fronts[i].isEmpty {
            var nextFront = [Int]()
            for p in fronts[i] {
                for q in S[p] {
                    n[q] -= 1
                    if n[q] == 0 {
                        nextFront.append(q)
                    }
                }
            }
            i += 1
            fronts.append(nextFront)
        }
        
        // Remove the last empty front if it exists
        if fronts.last?.isEmpty ?? false {
            fronts.removeLast()
        }
        
        return fronts
    }
    
    /// Calculates and assigns crowding distances to a front of organisms.
    public static func assignCrowdingDistance<G: Genome>(_ front: inout [Organism<G>]) {
        guard !front.isEmpty else { return }
        let size = front.count
        
        // Reset distances
        for i in 0..<size {
            front[i].crowdingDistance = 0.0
        }
        
        guard let firstObjectives = front.first?.objectives else { return }
        let numObjectives = firstObjectives.count
        
        for m in 0..<numObjectives {
            // Sort by objective m
            front.sort { ($0.objectives?[m] ?? 0.0) < ($1.objectives?[m] ?? 0.0) }
            
            // Boundary points get infinite distance
            front[0].crowdingDistance = Double.infinity
            front[size - 1].crowdingDistance = Double.infinity
            
            let minVal = front[0].objectives?[m] ?? 0.0
            let maxVal = front[size - 1].objectives?[m] ?? 0.0
            let range = maxVal - minVal
            
            if range > 0 {
                for i in 1..<(size - 1) {
                    let nextVal = front[i+1].objectives?[m] ?? 0.0
                    let prevVal = front[i-1].objectives?[m] ?? 0.0
                    front[i].crowdingDistance += (nextVal - prevVal) / range
                }
            }
        }
    }
    
    /// Returns true if $p$ dominates $q$.
    /// Definition: $p$ is no worse than $q$ in all objectives, and strictly better in at least one.
    /// This implementation assumes MINIMIZATION (lower is better).
    public static func dominates<G: Genome>(_ p: Organism<G>, _ q: Organism<G>) -> Bool {
        guard let pObj = p.objectives, let qObj = q.objectives, pObj.count == qObj.count else {
            return (p.fitness ?? 0.0) > (q.fitness ?? 0.0) // Fallback to single fitness
        }
        
        var betterInAtLeastOne = false
        for i in 0..<pObj.count {
            if pObj[i] > qObj[i] { // p is worse than q
                return false
            }
            if pObj[i] < qObj[i] { // p is strictly better than q
                betterInAtLeastOne = true
            }
        }
        
        return betterInAtLeastOne
    }
}
