import SwiftUI

struct DateButton: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void

    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .secondary)

                Text(dayNumber)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(isSelected ? .white : .primary)

                if isToday {
                    Circle()
                        .fill(isSelected ? .white : .blue)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 50)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color.clear)
                    .shadow(
                        color: isSelected ? .blue.opacity(0.3) : .clear,
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
