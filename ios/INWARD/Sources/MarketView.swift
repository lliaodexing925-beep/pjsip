import SwiftUI

struct MarketView: View {
    @EnvironmentObject private var model: AppModel
    @State private var category = "全部"
    @State private var showPublish = false
    private var categories: [String] { ["全部"] + Array(Set(model.catalog.products.map(\.category))).sorted() }
    private var products: [Product] { category == "全部" ? model.catalog.products : model.catalog.products.filter { $0.category == category } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Picker(model.t("分类"), selection: $category) { ForEach(categories, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
                        Spacer()
                        Button { if model.requireLogin() { showPublish = true } } label: { Label(model.t("发布闲置"), systemImage: "plus") }.buttonStyle(.borderedProminent)
                    }
                    LazyVGrid(columns: INLayout.contentColumns, spacing: 12) {
                        ForEach(products) { ProductCard(product: $0) }
                    }
                    if products.isEmpty { EmptyState(text: model.t("暂无内容")) }
                }
                .frame(maxWidth: INLayout.maximumContentWidth)
                .frame(maxWidth: .infinity)
                .padding(16)
            }.background(INTheme.paper).navigationTitle(model.t("交易")).refreshable { await model.refresh() }
            .sheet(isPresented: $showPublish) { PublishProductForm() }
        }
    }
}
struct ProductDetailView: View {
    let product: Product
    @EnvironmentObject private var model: AppModel
    @State private var showOrder = false
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            RemoteImage(path: product.image, base: model.baseURL, height: 280)
            VStack(alignment: .leading, spacing: 12) {
                HStack { if product.official { INPill(text: model.t("官方严选")) }; INPill(text: product.category) }
                Text(product.title).font(.title2.bold()); Text(yen(product.price)).font(.title.bold()).foregroundStyle(INTheme.green)
                DetailRow(label: model.t("成色"), value: product.condition); DetailRow(label: "区域", value: product.area)
                if product.ownerId != model.user?.id {
                    Button { if model.requireLogin() { showOrder = true } } label: { Text(model.t("确认订单")).frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.large)
                } else { INPill(text: "这是我发布的商品", mint: true) }
                Button { Task { await model.favorite(type: "product", id: product.id) } } label: {
                    Label(model.account.favorites.contains(product.id) ? "已收藏" : model.t("收藏"), systemImage: model.account.favorites.contains(product.id) ? "heart.fill" : "heart").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
            }.padding(.horizontal, 18)
        } }.background(INTheme.paper).navigationTitle(model.t("商品详情")).navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showOrder) { OrderForm(product: product) }
    }
}
struct PublishProductForm: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""; @State private var price = ""; @State private var area = "新宿区"
    @State private var category = "数码"; @State private var condition = "九成新"
    var body: some View {
        NavigationStack { Form {
            TextField(model.t("标题"), text: $title); TextField(model.t("价格"), text: $price).keyboardType(.numberPad)
            Picker("区域", selection: $area) { ForEach(Countries.tokyoWards, id: \.self) { Text($0).tag($0) } }
            Picker(model.t("分类"), selection: $category) { ForEach(["数码", "家居", "家电", "书籍", "服饰", "其他"], id: \.self) { Text($0).tag($0) } }
            TextField(model.t("成色"), text: $condition)
            Button("发布到云端") { Task {
                do { try await model.api.publishProduct(model.baseURL!, title: title, price: Int(price) ?? 0, area: area, category: category, condition: condition, image: ""); await model.afterMutation("闲置已发布"); dismiss() }
                catch { model.errorMessage = error.localizedDescription }
            } }.disabled(title.count < 2 || (Int(price) ?? 0) <= 0)
        }.navigationTitle(model.t("发布闲置")).toolbar { ToolbarItem(placement: .cancellationAction) { Button(model.t("取消")) { dismiss() } } } }
    }
}
struct OrderForm: View {
    let product: Product
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var method = "INWARD 余额"; @State private var address = ""; @State private var note = ""
    var body: some View {
        NavigationStack { Form {
            LabeledContent(model.t("价格"), value: yen(product.price))
            Picker("支付方式", selection: $method) { ForEach(["INWARD 余额", "银行卡", "便利店支付", "见面自付"], id: \.self) { Text($0).tag($0) } }
            TextField(model.t("地址 / 交接地点"), text: $address); TextField(model.t("备注"), text: $note)
            Text(model.t("测试环境，不发生真实扣款")).font(.caption).foregroundStyle(.secondary)
            Button(model.t("确认订单")) { Task {
                do { try await model.api.createOrder(model.baseURL!, product: product, method: method, address: address, note: note); await model.afterMutation("订单已保存到云端"); dismiss() }
                catch { model.errorMessage = error.localizedDescription }
            } }.disabled(address.isEmpty)
        }.navigationTitle(model.t("确认订单")).toolbar { ToolbarItem(placement: .cancellationAction) { Button(model.t("取消")) { dismiss() } } } }
    }
}
