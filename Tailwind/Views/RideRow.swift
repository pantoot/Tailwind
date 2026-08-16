import SwiftUI

/// Compact ride summary row, shared by the Today tab's recent-rides list and
/// the Rides tab's history list.
struct RideRow: View {
    let ride: Ride

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ride.formattedDate)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    Label(ride.formattedDistance, systemImage: "road.lanes")
                    Label(ride.formattedDuration, systemImage: "clock")
                    if let tss = ride.hrTSS {
                        Label(String(format: "%.0f", tss), systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if ride.averageHeartRate > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("\(Int(ride.averageHeartRate))")
                }
                .font(.subheadline)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
