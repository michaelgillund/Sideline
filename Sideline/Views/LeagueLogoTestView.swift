import SwiftUI

struct LeagueLogoTestView: View {

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 160), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(ESPN_League.allCases, id: \.self) { league in
                    LeagueLogoTestCard(league: league)
                }
            }
            .padding(16)
        }
        .navigationTitle("League Logos")
        .background(Color(.systemGroupedBackground))
    }
}

struct LeagueLogoTestCard: View {
    let league: ESPN_League
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text(league.displayName)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)

            HStack(spacing: 14) {
                VStack(spacing: 6) {
                    Image(league.logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .padding(8)
                        .background(chipBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text("Asset")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 6) {
                    Image(systemName: league.symbol)
                        .font(.system(size: 26, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .padding(8)
                        .background(chipBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text("SF")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("asset: \(league.logo)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("symbol: \(league.symbol)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    private var chipBackground: some ShapeStyle {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }
}

#Preview {
    LeagueLogoTestView()
}
