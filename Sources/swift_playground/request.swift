import Foundation

extension Dictionary {
    var queryString: String {
        return self.map { key, value in
            ((value is Array<Any>) ? (value as! Array<Any>).map { "\(key)=\($0)" }.joined(separator: "&"): "\(key)=\(value)")
        }.joined(separator: "&")
    }
}

class Request {
    var session:URLSession

    init(useCredStore:Bool = false) {
        let config = URLSessionConfiguration.default

        if !useCredStore { config.urlCredentialStorage = nil }

        self.session = URLSession.init(configuration: config)
    }

    func post(_ urlStr:String, _ data:[String:Any], headers:[String:String] = [:], onComplete:((Response) -> Void)? = nil) -> Response {
        guard let url = URL(string: urlStr) else {
            let resp = Response(error: Response.RequestError(code: 0, type: .urlError))

            if onComplete != nil { onComplete!(resp) }
            return resp
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data) as! Data else {
            let resp = Response(error: Response.RequestError(code: 0, type: .jsonParseError))

            if onComplete != nil { onComplete!(resp) }
            return resp
        }

        var request = URLRequest(url: url)
        self.setHeaders(request: &request, headers: headers)

        request.httpMethod = "POST"
        request.httpBody = jsonData

        return self.request(with: request, onComplete: onComplete)
    }

    func patch(_ urlStr:String, _ data:[String:Any], headers:[String:String] = [:], onComplete:((Response) -> Void)? = nil) -> Response {
        guard let url = URL(string: urlStr) else {
            let resp = Response(error: Response.RequestError(code: 0, type: .urlError))

            if onComplete != nil { onComplete!(resp) }
            return resp
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data) as! Data else {
            let resp = Response(error: Response.RequestError(code: 0, type: .jsonParseError))

            if onComplete != nil { onComplete!(resp) }
            return resp
        }

        var request = URLRequest(url: url)
        self.setHeaders(request: &request, headers: headers)

        request.httpMethod = "PATCH"
        request.httpBody = jsonData

        return self.request(with: request, onComplete: onComplete)
    }

    func put(_ urlStr:String, _ data:[String:Any], headers:[String:String] = [:], onComplete:((Response) -> Void)? = nil) -> Response {
        guard let url = URL(string: urlStr) else {
            let resp = Response(error: Response.RequestError(code: 0, type: .urlError))

            if onComplete != nil { onComplete!(resp) }
            return resp
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data) as! Data else {
            let resp = Response(error: Response.RequestError(code: 0, type: .jsonParseError))

            if onComplete != nil { onComplete!(resp) }
            return resp
        }

        var request = URLRequest(url: url)
        self.setHeaders(request: &request, headers: headers)

        request.httpMethod = "PUT"
        request.httpBody = jsonData

        return self.request(with: request, onComplete: onComplete)
    }

    func get(_ urlStr:String, params:[String:Any] = [:], headers:[String:String] = [:], onComplete:((Response) -> Void)? = nil) -> Response {
        guard let url = URL(string: (params.isEmpty ? urlStr : "\(urlStr)?\(params.queryString)")) else {
            let resp = Response(error: Response.RequestError(code: 0, type: .urlError))

            if onComplete != nil { onComplete!(resp) }
            return resp
        }

        var request = URLRequest(url: url)
        self.setHeaders(request: &request, headers: headers)

        return self.request(with: request, onComplete: onComplete)
    }

    func delete(_ urlStr:String, params:[String:Any] = [:], headers:[String:String] = [:], onComplete:((Response) -> Void)? = nil) -> Response {
        guard let url = URL(string: (params.isEmpty ? urlStr : "\(urlStr)?\(params.queryString)")) else {
            let resp = Response(error: Response.RequestError(code: 0, type: .urlError))

            if onComplete != nil { onComplete!(resp) }
            return resp
        }

        var request = URLRequest(url: url)
        self.setHeaders(request: &request, headers: headers)

        request.httpMethod = "DELETE"

        return self.request(with: request, onComplete: onComplete)
    }

    private func setHeaders(request: inout URLRequest, headers:[String:String] = [:]) {
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }

        if headers["Accept"] == nil { request.setValue("application/json", forHTTPHeaderField: "Accept") }
        if headers["Content-Type"] == nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
    }

    private func request(with request:URLRequest, onComplete:((Response) -> Void)? = nil) -> Response {
        var respObj:Response?

        let semaphore:DispatchSemaphore? = (onComplete == nil ? DispatchSemaphore(value: 0) : nil)
        self.session.dataTask(with:request) { data, resp, err in
            guard let data = data, let response = resp as? HTTPURLResponse, err == nil else {
                respObj = Response(error: err ?? Response.RequestError(code: 0, type: .unknownError))
                if onComplete != nil { onComplete!(respObj!) }
                if semaphore != nil { semaphore!.signal() }
                return
            }

            let respBody = String(data: data, encoding: .utf8) ?? "Invalid response returned"
            let err:Error? = ((200...299) ~= response.statusCode ? nil : Response.RequestError(code: response.statusCode, body: respBody))

            respObj = Response(status: response.statusCode, body: respBody, error: err)
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

        init(status code:Int = 0, body msg:String? = nil, error err:Error? = nil) {
            self.statusCode = code
            self.body = msg
            self.error = err
        }

        func json() -> Any {
            return ((self.body ?? "{}").starts(with: "{") ? jsonObject() : jsonArray())
        }

        func display() {
            var output = "Response Code: \(self.statusCode)\nResponse Str: \(self.body ?? "")\nResponse JSON: \(self.json())\n"

            if self.error != nil {
                if String(describing: type(of: self.error!)) == "RequestError" {
                    let err:RequestError = self.error as! RequestError
                    output += "Error: \(String(describing: err.code)) => \(String(describing: err.body))\n"
                } else {
                    output += "Error: \(String(describing: self.error))\n"
                }
            }

            print(output)
        }

        private func jsonObject() -> [String:Any] {
            return (try? JSONSerialization.jsonObject(with: String(describing: self.body ?? "{\"msg\":\"Invalid JSON\"}").data(using: .utf8) as! Data) as! [String:Any]) ?? [:]
        }

        private func jsonArray() -> [[String:Any]] {
            return (try? JSONSerialization.jsonObject(with: String(describing: self.body ?? "{\"msg\":\"Invalid JSON\"}").data(using: .utf8) as! Data) as! [[String:Any]]) ?? []
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
