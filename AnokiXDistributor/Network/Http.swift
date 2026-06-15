import Foundation
import Alamofire

/// HTTP transport via Alamofire. Mirrors network/Http.java: JSON Accept header,
/// Bearer token, form POST, and AxApi logging.
enum Http {

    static let tag = "AxApi"

    struct Result {
        let code: Int
        let body: String?
        var ok: Bool { code >= 200 && code < 300 }
    }

    private static let session: Session = {
        let config = URLSessionConfiguration.default
        // Per-packet idle timeout. Uploads (multipart KYC docs) can pause between
        // chunks while the server stores files, so keep this generous.
        config.timeoutIntervalForRequest = 60
        // Total time allowed for the whole transfer — large for multi-image uploads.
        config.timeoutIntervalForResource = 300
        return Session(configuration: config)
    }()

    static func get(baseUrl: String, path: String, query: [String: String]?, token: String?,
                    completion: @escaping (Result) -> Void) {
        var components = URLComponents(string: baseUrl + path)
        if let query = query, !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else {
            completion(Result(code: -1, body: nil))
            return
        }
        session.request(url, method: .get, headers: headers(token: token))
            .responseString { response in
                completion(map(response))
            }
    }

    static func postForm(baseUrl: String, path: String, form: [String: String]?, token: String?,
                         completion: @escaping (Result) -> Void) {
        guard let url = URL(string: baseUrl + path) else {
            completion(Result(code: -1, body: nil))
            return
        }
        session.request(url, method: .post, parameters: form, encoding: URLEncoding.default,
                        headers: formHeaders(token: token))
            .responseString { response in
                completion(map(response))
            }
    }

    /// One file part for a multipart upload (content already read into memory).
    struct FilePart {
        let field: String
        let fileName: String
        let mimeType: String
        let data: Data
    }

    /// multipart/form-data POST with text fields and optional file parts.
    static func postMultipart(baseUrl: String, path: String, form: [String: String],
                              files: [FilePart], token: String?,
                              completion: @escaping (Result) -> Void) {
        guard let url = URL(string: baseUrl + path) else {
            completion(Result(code: -1, body: nil))
            return
        }
        session.upload(multipartFormData: { mp in
            for (key, value) in form {
                mp.append(Data(value.utf8), withName: key)
            }
            for file in files {
                mp.append(file.data, withName: file.field,
                          fileName: file.fileName, mimeType: file.mimeType)
            }
        }, to: url, method: .post, headers: headers(token: token))
        .responseString { response in
            completion(map(response))
        }
    }

    private static func headers(token: String?) -> HTTPHeaders {
        var h: HTTPHeaders = ["Accept": "application/json"]
        if let token = token, !token.isEmpty {
            h.add(name: "Authorization", value: "Bearer \(token)")
        }
        return h
    }

    private static func formHeaders(token: String?) -> HTTPHeaders {
        var h = headers(token: token)
        h.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
        return h
    }

    private static func map(_ response: AFDataResponse<String>) -> Result {
        if let error = response.error {
            print("\(tag): request failed: \(error.localizedDescription)")
            return Result(code: -1, body: nil)
        }
        let code = response.response?.statusCode ?? -1
        return Result(code: code, body: response.value)
    }
}
