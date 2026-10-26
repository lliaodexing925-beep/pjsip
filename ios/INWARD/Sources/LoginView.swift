import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var channel = "email"
    @State private var destination = ""
    @State private var code = ""
    @State private var name = ""
    @State private var country = "中国"
    @State private var locale = "zh"
    @State private var codeSent = false
    @State private var isSending = false
    @State private var localError = ""
    @State private var statusMessage = ""
    private var languages: [String] {
        let official = Countries.profiles.first { $0.name == country }?.languages ?? ["zh"]
        return official + Countries.supportedLanguages.filter { !official.contains($0) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image("InwardLogo").resizable().scaledToFit().frame(width: 180).padding(.top, 20)
                    Text("在新的城市，找到你的生活。").font(.system(size: 27, weight: .heavy))
                    Text("邮箱或手机验证码登录，新用户会自动创建账号。账号与网页版互通。").foregroundStyle(INTheme.muted).font(.subheadline)
                    INCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Picker(model.t("国家 / 地区"), selection: $country) {
                                ForEach(Countries.profiles, id: \.name) { profile in
                                    Text("\(profile.local) · \(profile.languages.map(Countries.languageName).joined(separator: " / "))").tag(profile.name)
                                }
                            }.onChange(of: country) { _ in locale = languages.first ?? "zh" }
                            Picker(model.t("界面语言"), selection: $locale) {
                                ForEach(languages, id: \.self) { Text(Countries.languageName($0)).tag($0) }
                            }
                            Picker("联系方式", selection: $channel) {
                                Text(model.t("邮箱")).tag("email"); Text(model.t("手机")).tag("phone")
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: channel) { _ in resetChallenge() }
                            TextField(channel == "email" ? "name@example.com" : "+818012345678", text: $destination)
                                .keyboardType(channel == "email" ? .emailAddress : .phonePad).textInputAutocapitalization(.never).autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: destination) { _ in
                                    codeSent = false
                                    code = ""
                                    statusMessage = ""
                                    localError = ""
                                }
                            Button {
                                sendCode()
                            } label: {
                                if isSending { ProgressView() } else { Text(model.t("获取验证码")) }
                            }
                            .buttonStyle(.bordered)
                            .disabled(destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || model.isBusy)
                            if !statusMessage.isEmpty {
                                Text(statusMessage).font(.caption).foregroundStyle(INTheme.green).fixedSize(horizontal: false, vertical: true)
                            }
                            if !localError.isEmpty {
                                Text(localError).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                            }
                            if codeSent {
                                TextField(model.t("姓名"), text: $name).textFieldStyle(.roundedBorder)
                                TextField("6 位验证码", text: $code).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                                Button {
                                    Task { await model.login(channel: channel, destination: destination, code: code, name: name, locale: locale, country: country) }
                                } label: { Text(model.t("注册 / 登录")).frame(maxWidth: .infinity) }
                                .buttonStyle(.borderedProminent).controlSize(.large).disabled(code.count != 6 || model.isBusy)
                            }
                        }
                    }
                    Text("验证码 10 分钟内有效。短信与邮件送达依赖正式服务的 Twilio / SMTP 配置。").font(.caption).foregroundStyle(INTheme.muted)
                }.padding(22)
            }.background(INTheme.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(model.t("关闭")) { dismiss() } } }
        }
    }

    @MainActor
    private func sendCode() {
        guard !isSending, let url = model.baseURL else { return }
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        if channel == "phone" {
            let digits = trimmed.dropFirst(trimmed.hasPrefix("+") ? 1 : 0)
            guard trimmed.hasPrefix("+"), digits.count >= 8, digits.count <= 15, digits.allSatisfy(\.isNumber) else {
                localError = "请输入带国家区号的手机号，例如 +818012345678。"
                statusMessage = ""
                return
            }
        }
        isSending = true
        localError = ""
        statusMessage = ""
        let selectedChannel = channel
        let selectedLocale = locale
        Task { @MainActor in
            defer { isSending = false }
            do {
                try await model.api.sendCode(url, channel: selectedChannel, destination: trimmed, locale: selectedLocale)
                codeSent = true
                statusMessage = "验证码已发送，10 分钟内有效。"
            } catch {
                codeSent = false
                localError = error.localizedDescription.isEmpty ? APIError.invalidResponse.localizedDescription : error.localizedDescription
            }
        }
    }

    private func resetChallenge() {
        destination = ""
        code = ""
        codeSent = false
        localError = ""
        statusMessage = ""
    }
}
