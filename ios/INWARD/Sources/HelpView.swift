import SwiftUI

struct HelpView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showPublish = false
    @State private var ownOnly = false
    private var items: [HelpItem] { ownOnly ? model.catalog.help.filter { $0.requesterId == model.user?.id } : model.catalog.help }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Picker("需求范围", selection: $ownOnly) { Text(model.t("需求大厅")).tag(false); Text(model.t("我的发布")).tag(true) }.pickerStyle(.segmented)
                        Button { if model.requireLogin() { showPublish = true } } label: { Image(systemName: "plus") }.buttonStyle(.borderedProminent)
                    }
                    LazyVGrid(columns: INLayout.contentColumns, spacing: 12) { ForEach(items) { HelpCard(item: $0) } }
                    if items.isEmpty { EmptyState(text: model.t("暂无内容")) }
                    INCard { VStack(alignment: .leading, spacing: 8) { Label("每周 28 小时总上限", systemImage: "clock.badge.checkmark").font(.headline); Text("报名前服务端会按东京时间本周一重新核对工时，并锁定记录防止并发超限。").font(.caption).foregroundStyle(INTheme.muted) } }
                }
                .frame(maxWidth: INLayout.maximumContentWidth)
                .frame(maxWidth: .infinity)
                .padding(16)
            }.background(INTheme.paper).navigationTitle(model.t("互助")).refreshable { await model.refresh() }
            .sheet(isPresented: $showPublish) { PublishHelpForm() }
        }
    }
}
struct HelpDetailView: View {
    let item: HelpItem
    @EnvironmentObject private var model: AppModel
    @State private var externalMinutes = "0"
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { INPill(text: item.category, mint: true); INPill(text: item.status) }
                Text(item.title).font(.title2.bold()); Text(item.description).foregroundStyle(INTheme.muted)
                Divider(); DetailRow(label: "区域", value: item.area); DetailRow(label: "期望时间", value: item.requestTime)
                DetailRow(label: model.t("预算"), value: item.budget); DetailRow(label: model.t("预计工时"), value: "\(item.estimatedMinutes) 分钟")
                DetailRow(label: "发布人", value: "\(item.requesterName) · 信用 \(item.score)")
                if item.requesterId != model.user?.id {
                    TextField("本周校外已申报工时（分钟）", text: $externalMinutes).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    Text("我确认申报真实，并同意计入每周 28 小时总上限。").font(.caption).foregroundStyle(INTheme.muted)
                    Button(model.t("报名帮助")) { Task {
                        guard model.requireLogin() else { return }
                        do { try await model.api.applyHelp(model.baseURL!, id: item.id, externalMinutes: Int(externalMinutes) ?? 0); await model.afterMutation("报名已提交，服务端已完成工时校验") }
                        catch { model.errorMessage = error.localizedDescription }
                    } }.buttonStyle(.borderedProminent).controlSize(.large)
                } else {
                    Button(model.t("取消发布"), role: .destructive) { Task {
                        do { try await model.api.cancelHelp(model.baseURL!, id: item.id); await model.afterMutation("需求已取消") }
                        catch { model.errorMessage = error.localizedDescription }
                    } }.buttonStyle(.bordered)
                }
            }.padding(18)
        } }.background(INTheme.paper).navigationTitle(model.t("需求详情")).navigationBarTitleDisplayMode(.inline)
    }
}
struct PublishHelpForm: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""; @State private var category = "生活协助"; @State private var area = "新宿区"
    @State private var time = ""; @State private var budget = ""; @State private var description = ""; @State private var minutes = 60
    var body: some View {
        NavigationStack { Form {
            TextField(model.t("标题"), text: $title)
            Picker(model.t("分类"), selection: $category) { ForEach(["生活协助", "搬家搬运", "语言支持", "手续陪同", "学习交流", "其他"], id: \.self) { Text($0).tag($0) } }
            Picker("区域", selection: $area) { ForEach(Countries.tokyoWards, id: \.self) { Text($0).tag($0) } }
            TextField(model.t("期望时间"), text: $time); TextField(model.t("预算"), text: $budget)
            TextField(model.t("需求描述"), text: $description, axis: .vertical).lineLimit(3...6)
            Stepper("\(model.t("预计分钟数"))：\(minutes)", value: $minutes, in: 30...480, step: 30)
            Button("发布到云端") { Task {
                do { try await model.api.publishHelp(model.baseURL!, title: title, category: category, area: area, time: time, budget: budget, description: description, minutes: minutes); await model.afterMutation("需求已发布"); dismiss() }
                catch { model.errorMessage = error.localizedDescription }
            } }.disabled(title.count < 4 || description.count < 8 || time.isEmpty || budget.isEmpty)
        }.navigationTitle(model.t("发布需求")).toolbar { ToolbarItem(placement: .cancellationAction) { Button(model.t("取消")) { dismiss() } } } }
    }
}
