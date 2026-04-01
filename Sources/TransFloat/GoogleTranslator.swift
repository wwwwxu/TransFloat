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

    /// Translate text to Simplified Chinese using Google Translate free API.
    /// Auto-detects source language.
    static func translate(_ text: String, targetLang: String = "zh-CN") async throws -> String {
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=\(targetLang)&dt=t&q=\(encoded)")
        else {
            throw TranslationError.invalidURL
        }

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(from: url)
        } catch {
            throw TranslationError.networkError(error)
        }

        // Response is a nested JSON array: [[["translated","original",...], ...], ...]
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let sentences = json.first as? [Any]
        else {
            throw TranslationError.parseError
        }

        // Concatenate all translated sentence fragments
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
