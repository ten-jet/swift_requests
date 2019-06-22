import Foundation

func asyncTest(urls:[String], params:[String:Any] = [:]) {
    let request = Request()
    for url in urls {
        let semaphore = DispatchSemaphore(value: 0)
        request.get(url, params: params) { resp in
            resp.display()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
    }
}

func syncTest(urls:[String], params:[String:Any] = [:]) {
    let request = Request()
    for url in urls { request.get(url, params: params).display() }
}

//let request = Request()
//
//print("Test POST")
//request.post("https://httpstat.us/200", ["test": true]).display()
//
//print("Test PATCH")
//request.patch("https://httpstat.us/200", ["test": true]).display()
//
//print("Test PUT")
//request.put("https://httpstat.us/200", ["test": true]).display()
//
//print("Test DELETE")
//request.delete("https://httpstat.us/200", params: ["test": true]).display()

let urls:[String] = [
    "https://httpstat.us/200",
    "https://httpstat.us/400",
//    "https://httpstat.us/401",
    "https://httpstat.us/403",
    "https://httpstat.us/404",
    "https://httpstat.us/500"
]
let test:[String:Any] = ["trial": true, "error": [true, false]]

print("\nStarting SYNC Testing\n")
syncTest(urls: urls, params: test)
print("-----\n")
print("Starting ASYNC Testing\n")
asyncTest(urls: urls, params: test)
