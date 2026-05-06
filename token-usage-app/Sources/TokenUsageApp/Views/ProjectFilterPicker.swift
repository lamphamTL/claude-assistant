import SwiftUI

struct ProjectFilterPicker: View {
    let projects: [String]
    @Binding var selectedProject: String?

    var body: some View {
        Picker("Project", selection: $selectedProject) {
            Text("All Projects").tag(String?.none)
            if !projects.isEmpty {
                Divider()
                ForEach(projects, id: \.self) { path in
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .tag(Optional(path))
                        .help(path)
                }
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 200)
    }
}
