// SimpleKMeans.swift
// Speaker Diarization Spike - Swift-only approach validation
//
// Purpose: Simple k-means clustering for speaker separation
// Uses k-means++ initialization for better convergence

import Foundation
import Accelerate

/// Result of k-means clustering
struct ClusterResult {
    let labels: [Int]           // Cluster assignment for each data point
    let centroids: [[Float]]    // Final centroid positions
    let iterations: Int         // Iterations until convergence
    let inertia: Float          // Sum of squared distances to centroids
}

/// Simple k-means clustering implementation
class SimpleKMeans {
    
    // MARK: - Configuration
    
    private let maxIterations: Int
    private let tolerance: Float
    private let randomSeed: UInt64?
    
    init(maxIterations: Int = 100, tolerance: Float = 1e-4, randomSeed: UInt64? = nil) {
        self.maxIterations = maxIterations
        self.tolerance = tolerance
        self.randomSeed = randomSeed
    }
    
    // MARK: - Public API
    
    /// Perform k-means clustering
    /// - Parameters:
    ///   - data: Array of feature vectors (one per data point)
    ///   - k: Number of clusters
    /// - Returns: Cluster assignments and centroids
    func cluster(data: [[Float]], k: Int) -> ClusterResult {
        guard !data.isEmpty else {
            return ClusterResult(labels: [], centroids: [], iterations: 0, inertia: 0)
        }

        guard let featureCount = data.first?.count, featureCount > 0 else {
            return ClusterResult(labels: [], centroids: [], iterations: 0, inertia: 0)
        }

        guard k > 0 && k <= data.count else {
            return ClusterResult(labels: [], centroids: [], iterations: 0, inertia: 0)
        }

        // Normalize features for better clustering
        let (normalizedData, _, _) = normalizeFeatures(data)

        // Initialize centroids using k-means++
        var centroids = initializeCentroidsKMeansPlusPlus(data: normalizedData, k: k)
        var labels = [Int](repeating: 0, count: normalizedData.count)
        var previousCentroids: [[Float]] = []
        var iterations = 0
        
        for iteration in 0..<maxIterations {
            iterations = iteration + 1
            previousCentroids = centroids
            
            // Assignment step: assign each point to nearest centroid
            labels = assignToClusters(data: normalizedData, centroids: centroids)
            
            // Update step: move centroids to mean of assigned points
            centroids = updateCentroids(
                data: normalizedData,
                labels: labels,
                k: k,
                featureCount: featureCount
            )
            
            // Check for convergence
            if hasConverged(centroids: centroids, previousCentroids: previousCentroids) {
                break
            }
        }
        
        // Calculate inertia (sum of squared distances)
        let inertia = calculateInertia(data: normalizedData, labels: labels, centroids: centroids)
        
        return ClusterResult(
            labels: labels,
            centroids: centroids,
            iterations: iterations,
            inertia: inertia
        )
    }
    
    /// Estimate optimal k using silhouette score (for when k is unknown)
    func estimateOptimalK(data: [[Float]], maxK: Int = 10) -> Int {
        guard data.count > 2 else { return 1 }
        
        let actualMaxK = min(maxK, data.count - 1)
        var bestK = 2
        var bestScore: Float = -1
        
        for k in 2...actualMaxK {
            let result = cluster(data: data, k: k)
            let score = silhouetteScore(data: data, labels: result.labels)
            
            if score > bestScore {
                bestScore = score
                bestK = k
            }
        }
        
        return bestK
    }
    
    // MARK: - Private Helpers
    
    /// Normalize features to zero mean and unit variance
    private func normalizeFeatures(_ data: [[Float]]) -> (normalized: [[Float]], means: [Float], stds: [Float]) {
        guard let first = data.first else { 
            return (data, [], []) 
        }
        let featureCount = first.count
        
        // Compute mean and std for each feature
        var means = [Float](repeating: 0, count: featureCount)
        var stds = [Float](repeating: 0, count: featureCount)
        
        for j in 0..<featureCount {
            let column = data.map { $0[j] }
            
            // Mean
            var mean: Float = 0
            vDSP_meanv(column, 1, &mean, vDSP_Length(column.count))
            means[j] = mean
            
            // Variance
            let centered = column.map { $0 - mean }
            var variance: Float = 0
            vDSP_svesq(centered, 1, &variance, vDSP_Length(centered.count))
            variance /= Float(centered.count)
            stds[j] = sqrt(variance) + 1e-10  // Avoid division by zero
        }
        
        // Normalize
        let normalized = data.map { row in
            row.enumerated().map { (j, val) in (val - means[j]) / stds[j] }
        }
        
        return (normalized, means, stds)
    }
    
    /// Initialize centroids using k-means++ algorithm
    private func initializeCentroidsKMeansPlusPlus(data: [[Float]], k: Int) -> [[Float]] {
        var centroids: [[Float]] = []
        var usedIndices = Set<Int>()

        // First centroid: random selection
        let firstIndex = Int.random(in: 0..<data.count)
        centroids.append(data[firstIndex])
        usedIndices.insert(firstIndex)
        
        // Remaining centroids: weighted by squared distance to nearest existing centroid
        for _ in 1..<k {
            let countBefore = centroids.count
            var distances = [Float](repeating: 0, count: data.count)
            var totalDistance: Float = 0

            for (i, point) in data.enumerated() {
                if usedIndices.contains(i) {
                    distances[i] = 0
                    continue
                }

                // Find minimum distance to any existing centroid
                let minDist = centroids.map { euclideanDistance(point, $0) }.min() ?? 0
                distances[i] = minDist * minDist  // Square for D² weighting
                totalDistance += distances[i]
            }

            // Weighted random selection
            if totalDistance > 0 {
                let threshold = Float.random(in: 0..<totalDistance)
                var cumulative: Float = 0

                for (i, dist) in distances.enumerated() {
                    cumulative += dist
                    if cumulative >= threshold && !usedIndices.contains(i) {
                        centroids.append(data[i])
                        usedIndices.insert(i)
                        break
                    }
                }
            }

            // Fallback only if we didn't add a centroid this iteration
            if centroids.count == countBefore {
                for i in 0..<data.count {
                    if !usedIndices.contains(i) {
                        centroids.append(data[i])
                        usedIndices.insert(i)
                        break
                    }
                }
            }
        }
        
        return centroids
    }
    
    /// Assign each data point to nearest centroid
    private func assignToClusters(data: [[Float]], centroids: [[Float]]) -> [Int] {
        return data.map { point in
            findNearestCentroid(point: point, centroids: centroids)
        }
    }
    
    /// Find index of nearest centroid
    private func findNearestCentroid(point: [Float], centroids: [[Float]]) -> Int {
        var minDistance: Float = .infinity
        var nearestIndex = 0
        
        for (i, centroid) in centroids.enumerated() {
            let distance = euclideanDistance(point, centroid)
            if distance < minDistance {
                minDistance = distance
                nearestIndex = i
            }
        }
        
        return nearestIndex
    }
    
    /// Update centroids to mean of assigned points
    private func updateCentroids(data: [[Float]], labels: [Int], k: Int, featureCount: Int) -> [[Float]] {
        var newCentroids = [[Float]](repeating: [Float](repeating: 0, count: featureCount), count: k)
        var counts = [Int](repeating: 0, count: k)
        
        // Sum all points for each cluster
        for (i, label) in labels.enumerated() {
            counts[label] += 1
            for j in 0..<featureCount {
                newCentroids[label][j] += data[i][j]
            }
        }
        
        // Divide by counts to get mean
        for i in 0..<k {
            if counts[i] > 0 {
                for j in 0..<featureCount {
                    newCentroids[i][j] /= Float(counts[i])
                }
            }
        }
        
        return newCentroids
    }
    
    /// Check if centroids have converged
    private func hasConverged(centroids: [[Float]], previousCentroids: [[Float]]) -> Bool {
        guard centroids.count == previousCentroids.count else { return false }
        
        for (c1, c2) in zip(centroids, previousCentroids) {
            let distance = euclideanDistance(c1, c2)
            if distance > tolerance {
                return false
            }
        }
        
        return true
    }
    
    /// Calculate inertia (sum of squared distances to assigned centroids)
    private func calculateInertia(data: [[Float]], labels: [Int], centroids: [[Float]]) -> Float {
        var inertia: Float = 0
        
        for (i, point) in data.enumerated() {
            let centroid = centroids[labels[i]]
            let distance = euclideanDistance(point, centroid)
            inertia += distance * distance
        }
        
        return inertia
    }
    
    /// Calculate silhouette score for clustering quality
    private func silhouetteScore(data: [[Float]], labels: [Int]) -> Float {
        guard data.count > 1 else { return 0 }
        
        let uniqueLabels = Set(labels)
        guard uniqueLabels.count > 1 else { return 0 }
        
        var totalScore: Float = 0
        
        for (i, point) in data.enumerated() {
            let label = labels[i]
            
            // a(i) = mean distance to other points in same cluster
            let sameClusterPoints = data.enumerated().filter { labels[$0.offset] == label && $0.offset != i }
            let a: Float
            if sameClusterPoints.isEmpty {
                a = 0
            } else {
                a = sameClusterPoints.map { euclideanDistance(point, $0.element) }.reduce(0, +) / Float(sameClusterPoints.count)
            }
            
            // b(i) = min mean distance to points in other clusters
            var minMeanDistance: Float = .infinity
            for otherLabel in uniqueLabels where otherLabel != label {
                let otherClusterPoints = data.enumerated().filter { labels[$0.offset] == otherLabel }
                if !otherClusterPoints.isEmpty {
                    let meanDistance = otherClusterPoints.map { euclideanDistance(point, $0.element) }.reduce(0, +) / Float(otherClusterPoints.count)
                    minMeanDistance = min(minMeanDistance, meanDistance)
                }
            }
            let b = minMeanDistance
            
            // s(i) = (b - a) / max(a, b)
            let maxAB = max(a, b)
            if maxAB > 0 {
                totalScore += (b - a) / maxAB
            }
        }
        
        return totalScore / Float(data.count)
    }
    
    /// Euclidean distance between two vectors
    private func euclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return .infinity }
        
        var sum: Float = 0
        vDSP_distancesq(a, 1, b, 1, &sum, vDSP_Length(a.count))
        return sqrt(sum)
    }
}
