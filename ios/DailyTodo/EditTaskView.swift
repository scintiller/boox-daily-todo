import SwiftUI

struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    let original: TodoTask
    let onSave: (TodoTask) -> Void
    let onDelete: () -> Void

    @State private var title: String
    @State private var category: String
    @State private var section: String
    @State private var hasDue: Bool
    @State private var due: Date
    @State private var memo: Bool

    init(task: TodoTask, onSave: @escaping (TodoTask) -> Void, onDelete: @escaping () -> Void) {
        original = task
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: task.title)
        _category = State(initialValue: task.category ?? "工作")
        _section = State(initialValue: task.workSection ?? "focus")
        _hasDue = State(initialValue: task.dueDate != nil)
        _due = State(initialValue: Cal.date(task.dueDate ?? "") ?? Date())
        _memo = State(initialValue: task.memo)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("标题", text: $title, axis: .vertical)
                        .font(.body)
                }
                Section("分类") {
                    Picker("分类", selection: $category) {
                        Text("工作").tag("工作")
                        Text("科研").tag("科研")
                        Text("生活").tag("生活")
                        Text("运动").tag("运动")
                    }
                    .pickerStyle(.segmented)
                    if category == "工作" {
                        Picker("分区", selection: $section) {
                            ForEach(WorkSections.order, id: \.self) { k in
                                Text(WorkSections.name[k] ?? k).tag(k)
                            }
                        }
                    }
                }
                Section {
                    Toggle("设为备忘（不进今日）", isOn: $memo)
                    Toggle("有截止日期", isOn: $hasDue.animation())
                    if hasDue {
                        DatePicker("截止", selection: $due, displayedComponents: .date)
                    }
                }
                Section {
                    Button(role: .destructive) { onDelete(); dismiss() } label: {
                        HStack { Spacer(); Label("删除", systemImage: "trash"); Spacer() }
                    }
                }
            }
            .navigationTitle("编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        var t = original
        t.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        t.category = category
        t.workSection = category == "工作" ? section : nil
        t.memo = memo
        t.dueDate = hasDue ? Cal.string(due) : nil
        onSave(t)
        dismiss()
    }
}
