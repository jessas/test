import SwiftUI

struct ContentView: View {
    @State private var selectedDate = Date()
    @State private var hebrewDate: HebrewDate?
    @State private var animateResult = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.05, blue: 0.16),
                    Color(red: 0.19, green: 0.17, blue: 0.39),
                    Color(red: 0.14, green: 0.14, blue: 0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 20)

                    // Header
                    VStack(spacing: 6) {
                        Text("Gregorian to Hebrew")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.65, green: 0.55, blue: 0.98),
                                        Color(red: 0.38, green: 0.65, blue: 0.98)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("Date Converter")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.65, green: 0.55, blue: 0.98),
                                        Color(red: 0.38, green: 0.65, blue: 0.98)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }

                    // Date picker card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("SELECT DATE")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.5)
                            .foregroundColor(.gray)

                        DatePicker(
                            "",
                            selection: $selectedDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .tint(Color(red: 0.65, green: 0.55, blue: 0.98))
                        .colorScheme(.dark)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)

                    // Convert button
                    Button(action: convertDate) {
                        Text("Convert")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.49, green: 0.23, blue: 0.93),
                                        Color(red: 0.23, green: 0.51, blue: 0.96)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(14)
                    }
                    .padding(.horizontal)

                    // Result card
                    if let hd = hebrewDate {
                        VStack(spacing: 18) {
                            Text("HEBREW DATE")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.5)
                                .foregroundColor(.gray)

                            Text(hd.formatted)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.75, green: 0.52, blue: 0.99),
                                            Color(red: 0.38, green: 0.65, blue: 0.98)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .multilineTextAlignment(.center)

                            HStack(spacing: 36) {
                                DetailColumn(label: "Day", value: "\(hd.day)")
                                DetailColumn(label: "Month", value: hd.monthName)
                                DetailColumn(label: "Year", value: "\(hd.year)")
                            }

                            if HebrewCalendar.isLeapYear(hd.year) {
                                Text("Leap Year")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(red: 0.65, green: 0.55, blue: 0.98))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color(red: 0.65, green: 0.55, blue: 0.98).opacity(0.15))
                                    )
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(red: 0.65, green: 0.55, blue: 0.98).opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color(red: 0.65, green: 0.55, blue: 0.98).opacity(0.15), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal)
                        .opacity(animateResult ? 1 : 0)
                        .offset(y: animateResult ? 0 : 12)
                    }

                    Spacer().frame(height: 40)
                }
            }
        }
        .onAppear { convertDate() }
    }

    private func convertDate() {
        animateResult = false
        hebrewDate = HebrewCalendar.convert(from: selectedDate)
        withAnimation(.easeOut(duration: 0.35)) {
            animateResult = true
        }
    }
}

private struct DetailColumn: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 0.83, green: 0.83, blue: 0.83))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    ContentView()
}
