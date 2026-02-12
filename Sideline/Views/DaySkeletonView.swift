import SwiftUI

private struct Shimmer: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if !isActive {
            content
        } else {
            content
                .overlay {
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let phase = CGFloat((t.truncatingRemainder(dividingBy: 1.2)) / 1.2)

                        GeometryReader { geo in
                            let w = geo.size.width
                            let x = (-w)...(w * 2)
                            let pos = x.lowerBound + (x.upperBound - x.lowerBound) * phase

                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .white.opacity(0.25), location: 0.5),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(width: w * 0.55)
                            .rotationEffect(.degrees(18))
                            .offset(x: pos)
                            .blendMode(.plusLighter)
                        }
                        .mask(content)
                    }
                    .allowsHitTesting(false)
                }
        }
    }
}

private extension View {
    func shimmer(_ active: Bool) -> some View { modifier(Shimmer(isActive: active)) }

    func skeletonify(_ active: Bool) -> some View {
        self
            .redacted(reason: active ? .placeholder : [])
            .shimmer(active)
            .opacity(active ? 0.95 : 1.0)
    }
}

private struct SkeletonBar: View {
    let width: CGFloat
    let height: CGFloat
    var corner: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color.secondary.opacity(0.25))
            .frame(width: width, height: height)
    }
}

private struct SkeletonCircle: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(Color.secondary.opacity(0.25))
            .frame(width: size, height: size)
    }
}

private struct SkeletonGameCard: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    SkeletonCircle(size: 40)

                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBar(width: 140, height: 14, corner: 5)
                        SkeletonBar(width: 70, height: 10, corner: 4)
                    }

                    Spacer()

                    SkeletonBar(width: 26, height: 22, corner: 6)
                }

                HStack(spacing: 8) {
                    Rectangle().fill(.separator).frame(height: 1)

                    VStack(spacing: 6) {
                        SkeletonBar(width: 64, height: 12, corner: 5)
                        SkeletonBar(width: 44, height: 10, corner: 4)
                    }

                    Rectangle().fill(.separator).frame(height: 1)
                }

                HStack(spacing: 10) {
                    SkeletonCircle(size: 40)

                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBar(width: 120, height: 14, corner: 5)
                        SkeletonBar(width: 60, height: 10, corner: 4)
                    }

                    Spacer()

                    SkeletonBar(width: 26, height: 22, corner: 6)
                }
            }
        }
        .padding(10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

private struct SkeletonLeagueSection: View {
    let titleWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SkeletonCircle(size: 24)
                SkeletonBar(width: titleWidth, height: 16, corner: 6)
                Spacer()
            }

            GlassEffectContainer {
                VStack(spacing: 12) {
                    SkeletonGameCard()
                    SkeletonGameCard()
                    SkeletonGameCard()
                }
                .skeletonify(true)
            }
        }
    }
}

struct DaySkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SkeletonLeagueSection(titleWidth: 60)
                SkeletonLeagueSection(titleWidth: 54)
                SkeletonLeagueSection(titleWidth: 70)
            }
            .padding(.horizontal, 20)
            .padding(.top)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }
}
