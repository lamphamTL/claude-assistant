import SwiftUI

struct TimeRangePicker: View {
    @Binding var selectedKind: TimeRangeKind

    var body: some View {
        Picker("Range", selection: $selectedKind) {
            ForEach(TimeRangeKind.allCases) { kind in
                Text(kind.rawValue).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
    }
}
