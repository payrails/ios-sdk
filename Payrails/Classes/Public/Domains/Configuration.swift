import Foundation

public extension Payrails {
    struct Configuration {
        public init(
            data: String,
            option: Payrails.Options
        ) {
            self.data = data
            self.option = option
        }

        let data: String
        let option: Options
    }

    struct Options {
        public init(env: Payrails.Env = .prod) {
            self.env = env
        }
        let env: Env
    }

    enum Env: String {
        case prod, dev
    }
}
