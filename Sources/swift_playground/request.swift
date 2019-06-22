import Foundation

extension Dictionary {
    var queryString: String {
        return self.map { key, value in
            ((value is Array<Any>) ? (value as! Array<Any>).map { "\(key)=\($0)" }.joined(separator: "&"): "\(key)=\(value)")
        }.joined(separator: "&")
    }
}

extension URLRequest {
    init(type: String, url: URL, data:[String:Any] = [:], headers:[String:String] = [:]) {
        self.init(url: url)
        httpMethod = type

        for (key, value) in headers { self.setValue(value, forHTTPHeaderField: key) }

        if headers["Accept"] == nil { setValue("application/json", forHTTPHeaderField: "Accept") }
        if headers["Content-Type"] == nil { setValue("application/json", forHTTPHeaderField: "Content-Type") }

        if !data.isEmpty { httpBody = try? JSONSerialization.data(withJSONObject: data) }
    }
}

class Request {
    var session:URLSession

    init(useCredStore:Bool = false) {
        let config = URLSessionConfiguration.default

        if !useCredStore { config.urlCredentialStorage = nil }

        self.session = URLSession.init(configuration: config)
    }

    @discardableResult
    func post(_ urlStr:String, _ data:[String:Any], headers:[String:String] = [:], onComplete:((Response) -> Void)? = nil) -> Response {
        return self.request("POST", urlStr, data: data, headers: headers, onComplete: onComplete)
    }

    @discardableResult
    func patch(_ urlStr:String, _ data:[String:Any], headers:[String:String] = [:], onComplete:((Response) -> Void)? = nil) -> Response {
        return self.request("PATCH", urlStr, data: data, headers: headers, onComplete: onComplete)
    }

    @discardableResult
    func put(_ urlStr:String, _ data:[String:Any], headers:[String:String] = [:], onComplete:((Response) -> Void)? = nil) -> Response {
        return self.request("PUT", urlStr, data: data, headers: headers, onComplete: onComplete)
    }

    @discardableResult
    func get(_ urlStr:String, params:[String:Any] = [:], headers:[String:String] = [:], onComplete:((Response) -> Void)? = nil) -> Response {
        return self.request("GET", urlStr, params: params, headers: headers, onComplete: onComplete)
    }

    @discardableResult
    func delete(_ urlStr:String, params:[String:Any] = [:], headers:[String:String] = [:], onComplete:((Response) -> Void)? = nil) -> Response {
        return self.request("DELETE", urlStr, params: params, headers: headers, onComplete: onComplete)
    }

    @discardableResult
    func request(_ type: String, _ urlStr:String, data:[String:Any] = [:], params:[String:Any] = [:], headers:[String:String] = [:], onComplete:((Response) -> Void)? = nil) -> Response {
        guard let url = URL(string: (params.isEmpty ? urlStr : "\(urlStr)?\(params.queryString)")) else {
            let resp = Response(error: Response.RequestError(code: 0, type: .urlError))

            if onComplete != nil { onComplete!(resp) }
            return resp
        }

        var respObj:Response?

        let request = URLRequest(type: type, url: url, data: data, headers: headers)
        let semaphore:DispatchSemaphore? = (onComplete == nil ? DispatchSemaphore(value: 0) : nil)
        self.session.dataTask(with:request) { data, resp, err in
            guard let data = data, let response = resp as? HTTPURLResponse, err == nil else {
                respObj = Response(error: err ?? Response.RequestError(code: 0, type: .unknownError))
                if onComplete != nil { onComplete!(respObj!) }
                if semaphore != nil { semaphore!.signal() }
                return
            }

            let respBody = String(data: data, encoding: .utf8) ?? "Invalid response returned"
            respObj = Response(
                    status: response.statusCode,
                    body: respBody,
                    headers: response.allHeaderFields as! [String:Any],
                    error: ((200...299) ~= response.statusCode ? nil : Response.RequestError(code: response.statusCode, body: respBody))
            )
            if onComplete != nil { onComplete!(respObj!) }
            if semaphore != nil { semaphore!.signal() }
        }.resume()

        if semaphore != nil { _ = semaphore!.wait(timeout: DispatchTime.distantFuture) }
        return respObj ?? Response(status: 0, body: "Could not perform request")
    }

    class Response {
        var statusCode:Int
        var body:String?
        var error:Error?
        var json:Any?
        var headers:[String:Any]

        init(status code:Int = 0, body msg:String? = nil, headers:[String:Any] = [:], error err:Error? = nil) {
            self.statusCode = code
            self.body = msg
            self.error = err
            self.headers = headers

            if self.body != nil { self.json = try? JSONSerialization.jsonObject(with: String(describing: self.body ?? "").data(using: .utf8)!) }
        }

        func asJSON() -> [String:Any] {
            return [ "responseCode": self.statusCode, "body": self.body ?? "", "headers": self.headers, "error": self.error ?? "" ]
        }

        func display() {
            print("\(self.asJSON() as AnyObject)\n")
        }

        struct RequestError:Error {
            let code:Int
            let body:String
            let type:RequestErrorType

            init(code:Int, body:String? = nil, type: RequestErrorType? = nil) {
                self.code = code
                self.body = body ?? "Unknown Error"
                self.type = type ?? RequestErrorType(code: code, body: body)
            }

            enum RequestErrorType {
                case urlError
                case jsonParseError
                case unknownError
                case invalidResponse(code: Int)
                case badRequest(msg: String)
                case unauthorized(msg: String)
                case notFound(msg: String)
                case forbidden(msg: String)
                case unprocessableEntity(msg: String)
                case internalServer
                case badGateway
                case serviceUnavailable
                case gatewayTimeout

                init(code:Int, body:String?) {
                    let msg = body ?? ""

                    switch(code) {
                    case 400: self = .badRequest(msg: msg)
                    case 401: self = .unauthorized(msg: msg)
                    case 403: self = .forbidden(msg: msg)
                    case 404: self = .notFound(msg: msg)
                    case 422: self = .unprocessableEntity(msg: msg)
                    case 500: self = .internalServer
                    case 502: self = .badGateway
                    case 503: self = .serviceUnavailable
                    case 504: self = .gatewayTimeout
                    default:
                        self = .invalidResponse(code: code)
                    }
                }
            }
        }
    }
}
