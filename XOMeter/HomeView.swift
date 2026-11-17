import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var store: XOStore
    let openTab: (XOTab) -> Void
    @State private var appeared = false
    private let points: [Double] = [106, 153, 227, 183, 140]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("XO METER").font(.system(size: 25, weight: .heavy, design: .rounded))
                        Text("Your smart electricity companion").font(.caption).foregroundStyle(XOTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "bolt.fill").foregroundStyle(XOTheme.accent).font(.title)
                }.padding(.top, 12)
                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ESTIMATED CHARGES SO FAR").font(.caption2).foregroundStyle(XOTheme.muted)
                        Text(Billing.pesos(store.estimate)).font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("\(store.usage.formatted()) kWh since last bill").foregroundStyle(XOTheme.accent).font(.subheadline)
                        Chart(Array(points.enumerated()), id: \.offset) { item in
                            LineMark(x: .value("Month", item.offset), y: .value("kWh", item.element))
                                .foregroundStyle(XOTheme.accent)
                                .interpolationMethod(.catmullRom)
                            AreaMark(x: .value("Month", item.offset), y: .value("kWh", item.element))
                                .foregroundStyle(LinearGradient(colors: [XOTheme.accentGlow.opacity(0.33), .clear], startPoint: .top, endPoint: .bottom))
                        }.chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 95)
                        Text("Illustrative history — updated meter readings are not live").font(.system(size: 10)).foregroundStyle(XOTheme.muted)
                    }
                }
                GlassPanel {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MONTHLY BUDGET").font(.caption2).foregroundStyle(XOTheme.muted)
                        HStack {
                            Text(Billing.pesos(store.monthlyBudget)).font(.title3.bold())
                            Spacer()
                            Text("\(Int(min(999, store.estimate / max(store.monthlyBudget, 1) * 100)))% used")
                                .font(.caption).foregroundStyle(XOTheme.muted)
                        }
                        ProgressView(value: min(1, store.estimate / max(store.monthlyBudget, 1)))
                            .tint(XOTheme.accent)
                        Text("Budget comparison is based on estimated current charges, not a live utility balance.")
                            .font(.caption2).foregroundStyle(XOTheme.muted)
                    }
                }
                HStack(spacing: 10) {
                    quick("Scan Meter", "viewfinder", .scan)
                    quick("Energy Saver", "leaf.fill", .saver)
                    quick("Bills", "receipt", .bills)
                }
                GlassPanel {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Latest Meter Reading").foregroundStyle(XOTheme.muted).font(.caption)
                            Text(store.currentReading.formatted()).font(.title2.bold())
                            Text("Previous: \(store.previousReading.formatted()) kWh").font(.caption).foregroundStyle(XOTheme.muted)
                        }
                        Spacer()
                        Image(systemName: "gauge.with.dots.needle.33percent").foregroundStyle(XOTheme.accent).font(.title)
                    }
                }
                GlassPanel {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("Appliance Energy", systemImage: "leaf").font(.headline)
                        Text("\(store.applianceKWh.formatted(.number.precision(.fractionLength(1)))) kWh / month based on entered schedules")
                            .font(.subheadline).foregroundStyle(XOTheme.muted)
                        Text("Verify appliance wattage for accurate estimates.").font(.caption2).foregroundStyle(XOTheme.muted)
                    }
                }
            }.padding(.horizontal, 17).padding(.bottom, 24)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .onAppear { withAnimation(.easeOut(duration: 0.45)) { appeared = true } }
    }
    func quick(_ title: String, _ icon: String, _ tab: XOTab) -> some View {
        Button { openTab(tab) } label: {
            VStack(spacing: 9) {
                Image(systemName: icon).font(.title2).foregroundStyle(XOTheme.accent)
                Text(title).font(.caption2).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.75)
            }.frame(maxWidth: .infinity).padding(.vertical, 17)
            .background(XOTheme.surface, in: RoundedRectangle(cornerRadius: 17))
        }.buttonStyle(.plain)
    }
}
