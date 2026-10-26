import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showSearch: Bool
    private var columns: [GridItem] { INLayout.contentColumns }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Image("InwardLogo").resizable().scaledToFit().frame(width: 150)
                        Spacer()
                        Button { showSearch = true } label: { Image(systemName: "magnifyingglass").font(.title3).padding(10) }
                            .background(INTheme.white).clipShape(Circle())
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        INPill(text: "TOKYO · STUDENT LIFE", mint: true)
                        Text(model.t("东京留学生活，从一个入口开始")).font(.system(size: 28, weight: .heavy, design: .rounded)).tracking(-0.7)
                        Text("找房、淘好物、认识附近的人，也把临时的困难交给值得信任的同伴。").font(.subheadline).foregroundStyle(INTheme.muted)
                    }
                    HStack(spacing: 10) {
                        HomeStat(value: "\(model.catalog.rentals.count)", label: model.t("真实房源"), icon: "building.2")
                        HomeStat(value: "\(model.catalog.products.count)", label: model.t("闲置好物"), icon: "bag")
                        HomeStat(value: "\(model.catalog.help.count)", label: model.t("邻里互助"), icon: "hands.sparkles")
                    }
                    if !model.catalog.rentals.isEmpty || !model.catalog.products.isEmpty || !model.catalog.help.isEmpty {
                        INSectionTitle(title: "今天，也为你留了些好选择", subtitle: "来自云端数据库的实时内容")
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(model.catalog.rentals.prefix(4)) { rental in RentalCard(rental: rental) }
                            ForEach(model.catalog.products.prefix(4)) { product in ProductCard(product: product) }
                            ForEach(model.catalog.help.prefix(4)) { item in HelpCard(item: item) }
                        }
                    } else { EmptyState(text: model.t("当前没有云端数据")) }
                }
                .frame(maxWidth: INLayout.maximumContentWidth)
                .frame(maxWidth: .infinity)
                .padding(16)
            }
            .background(INTheme.paper)
            .dynamicTypeSize(.xSmall ... .xLarge)
            .refreshable { await model.refresh() }
        }
    }
}
struct HomeStat: View {
    let value: String; let label: String; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon).foregroundStyle(INTheme.green)
            Text(value).font(.title2.bold()); Text(label).font(.caption2).foregroundStyle(INTheme.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(INTheme.mint.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .minimumScaleFactor(0.8)
    }
}
struct RentalCard: View {
    let rental: Rental
    @EnvironmentObject private var model: AppModel
    var body: some View {
        NavigationLink { RentalDetailView(rental: rental) } label: {
            VStack(alignment: .leading, spacing: 8) {
                RemoteImage(path: rental.image, base: model.baseURL)
                Text(rental.name).font(.subheadline.weight(.bold)).lineLimit(2).multilineTextAlignment(.leading)
                Text("\(yen(rental.rent)) / 月").font(.headline).foregroundStyle(INTheme.green).lineLimit(1).minimumScaleFactor(0.75)
                Text("\(rental.area) · \(rental.layout) · \(rental.size)㎡").font(.caption2).foregroundStyle(INTheme.muted).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8).background(INTheme.white).clipShape(RoundedRectangle(cornerRadius: 16))
            .dynamicTypeSize(.xSmall ... .xLarge)
        }.buttonStyle(.plain)
    }
}
struct ProductCard: View {
    let product: Product
    @EnvironmentObject private var model: AppModel
    var body: some View {
        NavigationLink { ProductDetailView(product: product) } label: {
            VStack(alignment: .leading, spacing: 8) {
                RemoteImage(path: product.image, base: model.baseURL)
                HStack { if product.official { INPill(text: model.t("官方严选"), mint: true) }; Text(product.category).font(.caption2).foregroundStyle(INTheme.muted) }
                Text(product.title).font(.subheadline.weight(.bold)).lineLimit(2).multilineTextAlignment(.leading)
                Text(yen(product.price)).font(.headline).foregroundStyle(INTheme.green).lineLimit(1).minimumScaleFactor(0.75)
                Text("\(product.area) · \(product.condition)").font(.caption2).foregroundStyle(INTheme.muted).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8).background(INTheme.white).clipShape(RoundedRectangle(cornerRadius: 16))
            .dynamicTypeSize(.xSmall ... .xLarge)
        }.buttonStyle(.plain)
    }
}
struct HelpCard: View {
    let item: HelpItem
    var body: some View {
        NavigationLink { HelpDetailView(item: item) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack { INPill(text: item.category, mint: true); Spacer(); Text(item.status).font(.caption2).foregroundStyle(INTheme.green) }
                Text(item.title).font(.subheadline.weight(.bold)).lineLimit(3).multilineTextAlignment(.leading)
                Text(item.description).font(.caption).foregroundStyle(INTheme.muted).lineLimit(3).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Text(item.budget).font(.headline).foregroundStyle(INTheme.green)
                Label(item.area, systemImage: "mappin").font(.caption2).foregroundStyle(INTheme.muted).lineLimit(1)
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 205, maxHeight: .infinity, alignment: .topLeading)
            .background(INTheme.white).clipShape(RoundedRectangle(cornerRadius: 16))
            .dynamicTypeSize(.xSmall ... .xLarge)
        }.buttonStyle(.plain)
    }
}
struct GlobalSearchView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var users: [SocialProfile] = []
    private var rentals: [Rental] { model.catalog.rentals.filter { matches($0.name + $0.area + $0.station) } }
    private var products: [Product] { model.catalog.products.filter { matches($0.title + $0.category + $0.area) } }
    private var help: [HelpItem] { model.catalog.help.filter { matches($0.title + $0.category + $0.area) } }
    var body: some View {
        NavigationStack {
            List {
                if !users.isEmpty {
                    Section("用户") { ForEach(users, id: \.publicId) { profile in NavigationLink { SocialProfileView(publicId: profile.publicId) } label: { Label("\(profile.name) · \(profile.publicId)", systemImage: "person.crop.circle") } } }
                }
                Section("房源") { ForEach(rentals) { RentalSearchRow(rental: $0) } }
                Section("商品") { ForEach(products) { ProductSearchRow(product: $0) } }
                Section("互助") { ForEach(help) { HelpSearchRow(item: $0) } }
            }.navigationTitle(model.t("搜索")).searchable(text: $query, prompt: "房源、商品、需求、用户名或公开 ID")
            .onSubmit(of: .search) { Task { users = (try? await model.api.socialSearch(model.baseURL!, query: query)) ?? [] } }
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(model.t("关闭")) { dismiss() } } }
        }
    }
    private func matches(_ text: String) -> Bool { query.isEmpty || text.localizedCaseInsensitiveContains(query) }
}
struct RentalSearchRow: View { let rental: Rental; var body: some View { NavigationLink { RentalDetailView(rental: rental) } label: { VStack(alignment: .leading) { Text(rental.name); Text("\(rental.area) · \(yen(rental.rentalSafe))").font(.caption).foregroundStyle(.secondary) } } } }
private extension Rental { var rentalSafe: Int { rent } }
struct ProductSearchRow: View { let product: Product; var body: some View { NavigationLink { ProductDetailView(product: product) } label: { VStack(alignment: .leading) { Text(product.title); Text(yen(product.price)).font(.caption).foregroundStyle(.secondary) } } } }
struct HelpSearchRow: View { let item: HelpItem; var body: some View { NavigationLink { HelpDetailView(item: item) } label: { Text(item.title) } } }
