import Foundation

/// The one rule every LLM request passes through: Dictum only talks to servers
/// on this Mac. A base URL is allowed only when its host is a loopback address
/// (`127.0.0.0/8`, `::1`, or `localhost`). Anything else, including a hostname
/// that merely starts with `127.` or a URL with credentials, is refused before a
/// socket is opened.
public enum LocalEndpoint {
    public static func isLoopback(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return isLoopback(url)
    }

    public static func isLoopback(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return false }
        // `user:pass@host` URLs are a classic way to disguise the real host.
        guard url.user == nil, url.password == nil else { return false }
        guard let host = url.host?.lowercased() else { return false }
        return isLoopbackHost(host)
    }

    static func isLoopbackHost(_ host: String) -> Bool {
        let bare = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if bare == "localhost" || bare == "::1" { return true }
        // Dotted-quad 127.x.x.x only: exactly four numeric octets, first is 127.
        let octets = bare.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4, octets[0] == "127" else { return false }
        return octets.allSatisfy { octet in
            guard !octet.isEmpty, octet.count <= 3, octet.allSatisfy(\.isASCII), let value = Int(octet) else { return false }
            return (0...255).contains(value)
        }
    }
}
