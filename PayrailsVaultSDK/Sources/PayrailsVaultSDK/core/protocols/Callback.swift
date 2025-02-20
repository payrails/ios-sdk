/*
 * Copyright (c) 2022 Skyflow
*/

// Object that describes the Callbacksss

public protocol Callback {
    func onSuccess(_ responseBody: Any)
    func onFailure(_ error: Any)
}
