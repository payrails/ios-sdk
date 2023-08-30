import Foundation

public extension Payrails {
    struct Configuration {
        public init(
            initData: Payrails.InitData,
            option: Payrails.Options
        ) {
            self.initData = initData
            self.option = option
        }

        let initData: Payrails.InitData
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
