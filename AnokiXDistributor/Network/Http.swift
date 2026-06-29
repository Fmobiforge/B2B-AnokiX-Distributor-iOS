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

    /// Dedicated session for multipart uploads (Create Trader / Create Product).
    ///
    /// Uploads to this backend are slow (measured ~40s for 1MB against the live server),
    /// and `timeoutIntervalForRequest` is an *idle* timer that only resets when data is
    /// **received** — during a long upload nothing comes back, so a slow-but-progressing
    /// upload trips -1001 "request timed out" on iOS even though it is still sending.
    /// (Android/OkHttp reset their write timeout per chunk; curl has no idle timeout — so
    /// they succeed where iOS fails.) We give the request a very generous idle window so
    /// the body has time to finish, then the response arrives normally.
    private static let multipartSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
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

    /// application/json POST — for endpoints that expect a JSON body (e.g. preferences/update).
    /// Uses the plain headers (Accept + Authorization only) so `JSONEncoding` sets
    /// `Content-Type: application/json` itself — passing `formHeaders` here would pin a
    /// `x-www-form-urlencoded` content-type that JSONEncoding won't override, making the
    /// server read an empty form body (HTTP 422 "No preference fields supplied").
    static func postJson(baseUrl: String, path: String, json: [String: Any], token: String?,
                         completion: @escaping (Result) -> Void) {
        guard let url = URL(string: baseUrl + path) else {
            completion(Result(code: -1, body: nil))
            return
        }
        session.request(url, method: .post, parameters: json, encoding: JSONEncoding.default,
                        headers: headers(token: token))
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
    ///
    /// Bypasses Alamofire and uses a raw `URLSession` **data task** with the body set as
    /// `httpBody` (not an upload task / `httpBodyStream`), sent on `multipartSession` whose
    /// generous `timeoutIntervalForRequest` (300s) keeps the slow upload to this backend
    /// from tripping -1001 mid-transfer (see the session's note). The completion may fire
    /// off the main thread; ApiClient re-dispatches to main.
    static func postMultipart(baseUrl: String, path: String, form: [String: String],
                              files: [FilePart], token: String?,
                              completion: @escaping (Result) -> Void) {
        guard let url = URL(string: baseUrl + path) else {
            completion(Result(code: -1, body: nil))
            return
        }
        let boundary = "AnokiXBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("", forHTTPHeaderField: "Expect")
        let body = multipartBody(form: form, files: files, boundary: boundary)
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = body

        let kb = body.count / 1024
        let started = Date()
        print("\(tag): multipart upload → \(path) (\(kb) KB)")
        let task = multipartSession.dataTask(with: request) { data, response, error in
            let elapsed = String(format: "%.1f", Date().timeIntervalSince(started))
            if let error = error {
                print("\(tag): multipart upload failed after \(elapsed)s: \(error.localizedDescription)")
                completion(Result(code: -1, body: nil))
                return
            }
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("\(tag): multipart upload done in \(elapsed)s → HTTP \(code)")
            let text = data.flatMap { String(data: $0, encoding: .utf8) }
            completion(Result(code: code, body: text))
        }
        task.resume()
    }

    private static func multipartBody(form: [String: String], files: [FilePart], boundary: String) -> Data {
        var body = Data()
        let crlf = "\r\n"
        func append(_ string: String) { body.append(Data(string.utf8)) }

        for (key, value) in form {
            append("--\(boundary)\(crlf)")
            append("Content-Disposition: form-data; name=\"\(key)\"\(crlf)\(crlf)")
            append("\(value)\(crlf)")
        }
        for file in files {
            append("--\(boundary)\(crlf)")
            append("Content-Disposition: form-data; name=\"\(file.field)\"; filename=\"\(file.fileName)\"\(crlf)")
            append("Content-Type: \(file.mimeType)\(crlf)\(crlf)")
            body.append(file.data)
            append(crlf)
        }
        append("--\(boundary)--\(crlf)")
        return body
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
