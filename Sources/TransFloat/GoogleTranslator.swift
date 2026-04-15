import Foundation

enum TranslationError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的请求"
        case .networkError(let error): return error.localizedDescription
        case .parseError: return "解析翻译结果失败"
        }
    }
}

enum GoogleTranslator {

    /// Translate text using Google Translate free API (POST to avoid URL length limits).
    static func translate(_ text: String, targetLang: String = "zh-CN") async throws -> String {
        guard let url = URL(string: "https://translate.googleapis.com/translate_a/single") else {
            throw TranslationError.invalidURL
        }

        // Use POST with form body to handle long text
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = "client=gtx&sl=auto&tl=\(targetLang)&dt=t&q=\(text.urlEncoded)"
        request.httpBody = params.data(using: .utf8)

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            throw TranslationError.networkError(error)
        }

        // Response is a nested JSON array: [[["translated","original",...], ...], ...]
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let sentences = json.first as? [Any]
        else {
            throw TranslationError.parseError
        }

        var result = ""
        for sentence in sentences {
            if let parts = sentence as? [Any], let translated = parts.first as? String {
                result += translated
            }
        }

        guard !result.isEmpty else {
            throw TranslationError.parseError
        }

        return result
    }
}

private extension String {
    var urlEncoded: String {
        self.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? self
    }
}

private extension CharacterSet {
    /// URL query value safe characters (more restrictive than .urlQueryAllowed)
    static let urlQueryValueAllowed: CharacterSet = {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "&=+")
        return cs
    }()
}
