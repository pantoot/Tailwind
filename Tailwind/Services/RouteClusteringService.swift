import Foundation

/// Groups rides that represent the same repeated route.
///
/// Distance alone does not identify a route. A 20-minute trainer spin and a
/// 55-minute road climb both cover 7 miles, and bucketing them together produces
/// "trends" that track the changing mix of rides rather than the rider's fitness.
/// Rides only cluster when they share an environment, a distance, and a duration.
enum RouteClusteringService {

    /// Distance bucket width. Same-route rides drift by a few tenths of a mile
    /// depending on where the computer starts and stops recording.
    static let distanceBucketMiles = 0.5

    /// How far a ride's duration may sit from its cluster's shortest ride. The
    /// same route varies with wind, traffic and legs — but not by half again.
    static let durationTolerance = 0.15

    /// Minimum rides before a cluster carries enough signal to trend.
    static let minimumRidesPerRoute = 3

    /// Shortest ride that counts as a route at all. Shares the import bar — a ride
    /// too short to be a session is too short to be a route.
    static let minimumRideDuration = Constants.Import.minimumWorkoutDuration

    /// A set of rides believed to be the same route, oldest first.
    struct RouteCluster {
        let environment: RideEnvironment
        let distanceKey: Double
        let rides: [Ride]

        /// Rides sorted oldest first, for trend reading.
        var chronological: [Ride] { rides.sorted { $0.date < $1.date } }

        var label: String {
            let distance = String(format: "%.1f", distanceKey)
            let typical = chronological.first?.formattedDuration ?? ""
            switch environment {
            case .indoor:  return "~\(distance) mi indoor (~\(typical))"
            case .outdoor: return "~\(distance) mi outdoor (~\(typical))"
            case .unknown: return "~\(distance) mi unclassified (~\(typical))"
            }
        }

        /// Indoor speed is derived from power by the trainer, so miles per beat
        /// says nothing extra. Watts per beat is the honest efficiency read.
        var prefersPowerEfficiency: Bool {
            environment == .indoor && rides.allSatisfy { $0.bestKnownAveragePower != nil }
        }
    }

    /// All repeated routes found in `rides`, most-ridden first.
    static func cluster(_ rides: [Ride]) -> [RouteCluster] {
        let eligible = rides.filter { $0.duration >= minimumRideDuration }

        let buckets = Dictionary(grouping: eligible) { ride in
            BucketKey(environment: ride.environment, distance: distanceBucket(for: ride.distance))
        }

        return buckets
            .flatMap { key, group in
                splitByDuration(group).map {
                    RouteCluster(environment: key.environment, distanceKey: key.distance, rides: $0)
                }
            }
            .filter { $0.rides.count >= minimumRidesPerRoute }
            .sorted { left, right in
                if left.rides.count != right.rides.count {
                    return left.rides.count > right.rides.count
                }
                return left.distanceKey > right.distanceKey
            }
    }

    /// Rides excluded from clustering for being too short to be a route.
    static func shortRides(in rides: [Ride]) -> [Ride] {
        rides.filter { $0.duration < minimumRideDuration }
    }

    // MARK: - Internals

    private struct BucketKey: Hashable {
        let environment: RideEnvironment
        let distance: Double
    }

    private static func distanceBucket(for distance: Double) -> Double {
        (distance / distanceBucketMiles).rounded() * distanceBucketMiles
    }

    /// Splits a same-distance group into runs of comparable duration.
    ///
    /// Walks the group shortest-first and starts a new run whenever a ride
    /// exceeds the current run's shortest duration by more than the tolerance,
    /// so an outlier lands in its own run instead of stretching the average.
    private static func splitByDuration(_ rides: [Ride]) -> [[Ride]] {
        rides
            .sorted { $0.duration < $1.duration }
            .reduce(into: [[Ride]]()) { runs, ride in
                guard let baseline = runs.last?.first?.duration,
                      ride.duration <= baseline * (1 + durationTolerance) else {
                    runs.append([ride])
                    return
                }
                runs[runs.count - 1].append(ride)
            }
    }
}
