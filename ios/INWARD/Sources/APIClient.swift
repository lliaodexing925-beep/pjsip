import Foundation

enum APIError: LocalizedError {
    case notConfigured, invalidServer, unauthorized, transport(String), server(String), invalidResponse
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "请先填写已发布的 INWARD 服务地址。"
        case .invalidServer: return "服务地址格式不正确，请输入完整的 https:// 地址。"
        case .unauthorized: return "登录状态已失效，请重新登录。"
        case .transport(let message), .server(let message): return message
        case .invalidResponse: return "服务器返回了无法识别的数据。"
        }
    }
}

final class APIClient: @unchecked Sendable {
    private let session: URLSession
    private let decoderQueue = DispatchQueue(label: "inward.api", qos: .userInitiated)
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = .shared
        configuration.httpShouldSetCookies = true
        configuration.timeoutIntervalForRequest = 25
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration)
    }

    static func normalizedBaseURL(_ raw: String) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: trimmed), let host = components.host, !host.isEmpty else { throw APIError.invalidServer }
        if components.scheme == nil { components.scheme = "https" }
        guard components.scheme == "https" || host == "localhost" || host == "127.0.0.1" else { throw APIError.invalidServer }
        components.path = ""; components.query = nil; components.fragment = nil
        guard let url = components.url else { throw APIError.invalidServer }
        return url
    }

    private func call(_ base: URL, _ path: String, input: JSON?, method: String) async throws -> JSON {
        var endpoint = base.appendingPathComponent("api/trpc/\(path)")
        if method == "GET", let input {
            let wrapped = try JSONSerialization.data(withJSONObject: ["json": input])
            guard let text = String(data: wrapped, encoding: .utf8), var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else { throw APIError.invalidServer }
            components.queryItems = [URLQueryItem(name: "input", value: text)]
            guard let url = components.url else { throw APIError.invalidServer }
            endpoint = url
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if method == "POST" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let bodyValue: Any = input.map { $0 as Any } ?? NSNull()
            request.httpBody = try JSONSerialization.data(withJSONObject: ["json": bodyValue])
        }
        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw APIError.transport(error.localizedDescription) }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        return try Self.decodeResponse(data: data, statusCode: http.statusCode)
    }

    static func decodeResponse(data: Data, statusCode: Int) throws -> JSON {
        let root = try? JSONSerialization.jsonObject(with: data) as? JSON
        if (200..<300).contains(statusCode) {
            guard let result = root?["result"] as? JSON,
                  let resultData = result["data"] as? JSON,
                  let value = resultData["json"] else { throw APIError.invalidResponse }
            if let object = value as? JSON { return object }
            if let array = value as? [Any] { return ["items": array] }
            return ["value": value]
        }
        let errorJSON = jsonObject(jsonObject(root?["error"])["json"])
        if statusCode == 401 || stringValue(errorJSON["code"]) == "UNAUTHORIZED" { throw APIError.unauthorized }
        throw APIError.server(stringValue(errorJSON["message"], "请求失败（\(statusCode)），请稍后重试。"))
    }

    func ping(_ base: URL) async throws -> JSON { try await call(base, "ping", input: nil, method: "GET") }
    func me(_ base: URL) async throws -> User { User(try await call(base, "auth.me", input: nil, method: "GET")) }
    func catalog(_ base: URL) async throws -> Catalog {
        var data = try await call(base, "catalog.list", input: nil, method: "GET")
        data["help"] = data["helpRequests"]
        return Catalog(data)
    }
    func bootstrap(_ base: URL) async throws -> AccountData { AccountData(try await call(base, "account.bootstrap", input: nil, method: "GET")) }
    func logout(_ base: URL) async throws { _ = try await call(base, "auth.logout", input: nil, method: "POST") }
    func sendCode(_ base: URL, channel: String, destination: String, locale: String) async throws {
        _ = try await call(base, "localAuth.sendCode", input: ["channel": channel, "destination": destination, "locale": locale], method: "POST")
    }
    func verifyCode(_ base: URL, channel: String, destination: String, code: String, name: String, locale: String, country: String) async throws -> User {
        User(try await call(base, "localAuth.verifyCode", input: ["channel": channel, "destination": destination, "code": code, "name": name, "locale": locale, "country": country], method: "POST"))
    }
    func savePreference(_ base: URL, locale: String, country: String) async throws {
        _ = try await call(base, "localization.savePreference", input: ["locale": locale, "country": country], method: "POST")
    }
    func translate(_ base: URL, locale: String, texts: [String]) async throws -> [String] {
        let result = try await call(base, "localization.translate", input: ["targetLocale": locale, "texts": texts], method: "POST")
        return result["translations"] as? [String] ?? texts
    }
    func updateProfile(_ base: URL, user: User) async throws {
        _ = try await call(base, "account.updateProfile", input: ["name": user.name, "school": user.school, "area": user.area, "identity": user.identity, "language": user.language, "bio": user.bio], method: "POST")
    }
    func toggleFavorite(_ base: URL, type: String, id: Int) async throws -> Bool {
        boolValue(try await call(base, "account.toggleFavorite", input: ["targetType": type, "targetId": id], method: "POST")["favorite"])
    }
    func threads(_ base: URL) async throws -> [ThreadSummary] {
        jsonArray(try await call(base, "account.threads", input: nil, method: "GET")["items"]).map(ThreadSummary.init)
    }
    func messages(_ base: URL, threadKey: String) async throws -> [Message] {
        jsonArray(try await call(base, "account.messages", input: ["threadKey": threadKey], method: "GET")["items"]).map(Message.init)
    }
    func sendMessage(_ base: URL, threadKey: String, body: String, title: String) async throws {
        _ = try await call(base, "account.sendMessage", input: ["threadKey": threadKey, "body": body], method: "POST")
    }
    func markThreadRead(_ base: URL, threadKey: String) async throws {
        _ = try await call(base, "account.markThreadRead", input: nil, method: "POST")
    }
    func markAllThreadsRead(_ base: URL) async throws {
        _ = try await call(base, "account.markAllThreadsRead", input: nil, method: "POST")
    }
    func deleteThread(_ base: URL, threadKey: String) async throws {
        _ = try await call(base, "account.deleteThread", input: ["threadKey": threadKey], method: "POST")
    }
    func socialSearch(_ base: URL, query: String) async throws -> [SocialProfile] {
        jsonArray(try await call(base, "social.search", input: ["query": query], method: "GET")["items"]).map(SocialProfile.init)
    }
    func socialProfile(_ base: URL, publicId: String) async throws -> SocialProfile {
        SocialProfile(try await call(base, "social.profile", input: ["publicId": publicId]))
    }
    func toggleFollow(_ base: URL, publicId: String) async throws -> Bool {
        boolValue(try await call(base, "social.toggleFollow", input: ["publicId": publicId], method: "POST")["following"])
    }
    func addReview(_ base: URL, publicId: String, rating: Int, body: String) async throws {
        _ = try await call(base, "social.addReview", input: ["publicId": publicId, "rating": rating, "body": body], method: "POST")
    }
    func connections(_ base: URL, publicId: String, kind: String) async throws -> [SocialProfile] {
        jsonArray(try await call(base, "social.connections", input: ["publicId": publicId, "kind": kind], method: "GET")["items"]).map(SocialProfile.init)
    }
    func createBooking(_ base: URL, rental: Rental, date: String, time: String, address: String, note: String) async throws {
        _ = try await call(base, "account.createBooking", input: ["kind": "viewing", "targetId": rental.id, "title": rental.name, "bookingDate": date, "bookingTime": time, "address": address], method: "POST")
    }
    func createOrder(_ base: URL, product: Product, method: String, address: String, note: String) async throws {
        _ = try await call(base, "account.createOrder", input: ["scenario": product.official ? "official" : "secondhand", "targetId": product.id, "method": method, "address": address, "idempotencyKey": UUID().uuidString], method: "POST")
    }
    func publishProduct(_ base: URL, title: String, price: Int, area: String, category: String, condition: String, image: String) async throws {
        _ = try await call(base, "account.publishProduct", input: ["title": title, "price": price, "area": area, "category": category, "condition": condition], method: "POST")
    }
    func publishHelp(_ base: URL, title: String, category: String, area: String, time: String, budget: String, description: String, minutes: Int) async throws {
        _ = try await call(base, "account.publishHelp", input: ["title": title, "category": category, "area": area, "requestTime": time, "budget": budget, "description": description, "estimatedMinutes": minutes], method: "POST")
    }
    func applyHelp(_ base: URL, id: Int, externalMinutes: Int) async throws {
        _ = try await call(base, "catalog.applyHelp", input: ["requestId": id, "externalMinutes": externalMinutes, "attested": true], method: "POST")
    }
    func cancelHelp(_ base: URL, id: Int) async throws {
        _ = try await call(base, "catalog.cancelHelp", input: ["requestId": id], method: "POST")
    }
    func myWork(_ base: URL) async throws -> [WorkRecord] {
        jsonArray(try await call(base, "catalog.myWork", input: nil, method: "GET")["items"]).map(WorkRecord.init)
    }
    func walletAction(_ base: URL, kind: String, amount: Int) async throws {
        _ = try await call(base, "account.walletAction", input: ["action": kind, "amount": amount], method: "POST")
    }
}
