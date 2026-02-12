//
//  ContentView.swift
//  Sideline
//
//  Created by Michael Gillund on 2/6/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScoreboardViewModel()
    @State private var currentPage: Int?

    private var showSkeleton: Bool {
        viewModel.isLoading && viewModel.scoreboards.isEmpty
    }

    private var weekDates: [Date] {
        var cal = Calendar.current
        cal.firstWeekday = 1

        let base = cal.startOfDay(for: viewModel.selectedDate)
        let weekday = cal.component(.weekday, from: base)
        let daysFromSunday = (weekday - cal.firstWeekday + 7) % 7

        guard let sunday = cal.date(byAdding: .day, value: -daysFromSunday, to: base) else {
            return []
        }

        return (0...6).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: sunday)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                                DateButton(date: date, isSelected: currentPage == index) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        currentPage = index
                                        viewModel.selectedDate = date
                                    }
                                }
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .background(Color(.systemBackground))
                    .onAppear {
                        guard currentPage == nil else { return }
                        let target = Calendar.current.startOfDay(for: viewModel.selectedDate)
                        let initial = weekDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: target) }) ?? 0
                        DispatchQueue.main.async {
                            currentPage = initial
                            proxy.scrollTo(initial, anchor: .center)
                        }
                    }
                    .onChange(of: currentPage) { _, newValue in
                        if let newValue {
                            withAnimation { proxy.scrollTo(newValue, anchor: .center) }
                        }
                    }
                }

                Divider()

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                            DayContentView(
                                date: date,
                                scoreboards: viewModel.scoreboards,
                                isLoading: viewModel.isLoading,
                                showSkeleton: showSkeleton
                            )
                            .containerRelativeFrame(.horizontal)
                            .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .scrollPosition(id: $currentPage)
                .onChange(of: currentPage) { _, newValue in
                    if let newValue, weekDates.indices.contains(newValue) {
                        viewModel.selectedDate = weekDates[newValue]
                    }
                }
            }
            .task {
                await viewModel.fetchCurrentWeek()
                viewModel.startPolling()
            }
            .onDisappear {
                viewModel.stopPolling()
            }
        }
    }
}

#Preview {
    ContentView()
}
