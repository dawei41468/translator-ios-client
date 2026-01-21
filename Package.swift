// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Translator",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "Translator",
            targets: ["Translator"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/socketio/socket.io-client-swift.git", from: "16.0.0"),
        .package(url: "https://github.com/evgenyneu/keychain-swift.git", from: "20.0.0")
    ],
    targets: [
        .target(
            name: "Translator",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift"),
                .product(name: "KeychainSwift", package: "keychain-swift")
            ],
            path: "Translator"
        ),
        .testTarget(
            name: "TranslatorTests",
            dependencies: ["Translator"],
            path: "TranslatorTests"
        ),
    ]
)