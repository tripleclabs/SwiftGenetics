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
    @inlinable
    public static func sortAndTruncate<G: Genome>(_ organisms: [Organism<G>], to n: Int) -> [Organism<G>] {
        guard !organisms.isEmpty, n > 0 else { return [] }
        let population = organisms
        
        // 1. Fast non-dominated sort
        let fronts = fastNonDominatedSort(population)
        
        var newPopulation = [Organism<G>]()
        newPopulation.reserveCapacity(min(n, population.count))
        var currentFrontIndex = 0
        
        // 2. Fill the new population front by front
        while currentFrontIndex < fronts.count && newPopulation.count + fronts[currentFrontIndex].count <= n {
            var front = fronts[currentFrontIndex].map { population[$0] }
            
            // Assign crowding distance to the front
            assignCrowdingDistance(&front)
            
            // Assign rank to organisms in this front
            for i in 0..<front.count {
                front[i].dominanceRank = currentFrontIndex
            }
            
            newPopulation.append(contentsOf: front)
            currentFrontIndex += 1
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
    @inlinable
    public static func fastNonDominatedSort<G: Genome>(_ population: [Organism<G>]) -> [[Int]] {
        let size = population.count
        guard size > 0 else { return [] }
        
        var S = Array(repeating: [Int](), count: size) // Sets of organisms dominated by each individual
        var n = [Int](repeating: 0, count: size)       // Number of individuals dominating each individual
        var fronts = [[Int]]()
        var currentFront = [Int]()
        
        // Fast path: hoist uniform-length objective arrays into a single contiguous buffer
        // and evaluate each unordered pair (p, q) once.
        let objectiveCount = population[0].objectives?.count ?? 0
        var uniformObjectives = objectiveCount > 0
        if uniformObjectives {
            for p in 1..<size {
                if population[p].objectives?.count != objectiveCount {
                    uniformObjectives = false
                    break
                }
            }
        }
        
        if uniformObjectives {
            var flatObjectives = [Double]()
            flatObjectives.reserveCapacity(size * objectiveCount)
            for organism in population {
                flatObjectives.append(contentsOf: organism.objectives!)
            }
            flatObjectives.withUnsafeBufferPointer { buf in
                for p in 0..<size {
                    let pBase = p * objectiveCount
                    for q in (p + 1)..<size {
                        let qBase = q * objectiveCount
                        var pBetter = false
                        var qBetter = false
                        for k in 0..<objectiveCount {
                            let pv = buf[pBase + k]
                            let qv = buf[qBase + k]
                            if pv > qv {
                                pBetter = true
                                if qBetter { break }
                            } else if qv > pv {
                                qBetter = true
                                if pBetter { break }
                            }
                        }
                        if pBetter && !qBetter {
                            S[p].append(q)
                            n[q] += 1
                        } else if qBetter && !pBetter {
                            S[q].append(p)
                            n[p] += 1
                        }
                    }
                }
            }
        } else {
            for p in 0..<size {
                for q in (p + 1)..<size {
                    if dominates(population[p], population[q]) {
                        S[p].append(q)
                        n[q] += 1
                    } else if dominates(population[q], population[p]) {
                        S[q].append(p)
                        n[p] += 1
                    }
                }
            }
        }
        
        for p in 0..<size {
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
    @inlinable
    public static func assignCrowdingDistance<G: Genome>(_ front: inout [Organism<G>]) {
        guard !front.isEmpty else { return }
        let size = front.count
        
        // Reset distances
        for i in 0..<size {
            front[i].crowdingDistance = 0.0
        }
        
        guard let firstObjectives = front.first?.objectives else { return }
        let numObjectives = firstObjectives.count
        guard numObjectives > 0 else { return }
        
        if size <= 2 {
            for i in 0..<size {
                front[i].crowdingDistance = Double.infinity
            }
            return
        }
        
        var indices = Array(0..<size)
        var objValues = [Double](repeating: 0.0, count: size)
        
        for m in 0..<numObjectives {
            for i in 0..<size {
                objValues[i] = front[i].objectives?[m] ?? 0.0
            }
            
            // Sort indices by objective m without copying Organism structs
            indices.sort { objValues[$0] < objValues[$1] }
            
            // Boundary points get infinite distance
            front[indices[0]].crowdingDistance = Double.infinity
            front[indices[size - 1]].crowdingDistance = Double.infinity
            
            let minVal = objValues[indices[0]]
            let maxVal = objValues[indices[size - 1]]
            let range = maxVal - minVal
            
            if range > 0 {
                for i in 1..<(size - 1) {
                    let nextVal = objValues[indices[i + 1]]
                    let prevVal = objValues[indices[i - 1]]
                    front[indices[i]].crowdingDistance += (nextVal - prevVal) / range
                }
            }
        }
    }
    
    /// Returns true if $p$ dominates $q$.
    /// Definition: $p$ is no worse than $q$ in all objectives, and strictly better in at least one.
    /// This implementation assumes MAXIMIZATION (larger is better).
    @inlinable
    public static func dominates<G: Genome>(_ p: Organism<G>, _ q: Organism<G>) -> Bool {
        guard let pObj = p.objectives, let qObj = q.objectives, pObj.count == qObj.count else {
            return (p.fitness ?? 0.0) > (q.fitness ?? 0.0) // Fallback to single fitness
        }
        
        var betterInAtLeastOne = false
        for i in 0..<pObj.count {
            if pObj[i] < qObj[i] { // p is worse than q in maximization
                return false
            }
            if pObj[i] > qObj[i] { // p is strictly better than q in maximization
                betterInAtLeastOne = true
            }
        }
        
        return betterInAtLeastOne
    }
}
