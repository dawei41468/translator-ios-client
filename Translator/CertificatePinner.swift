import Foundation

@MainActor
class CertificatePinner: NSObject, @preconcurrency URLSessionDelegate {
    // For production, these would be the actual certificate data
    // For now, we'll implement the structure for certificate pinning
    private let pinnedCertificates: [Data] = []

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Check if this is a server trust challenge
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            // For non-server-trust challenges, use default handling
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Evaluate server trust
        if evaluateServerTrust(serverTrust) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private func evaluateServerTrust(_ serverTrust: SecTrust) -> Bool {
        // For development, we'll accept any valid certificate
        // In production, implement proper certificate pinning logic

        let policy = SecPolicyCreateSSL(true, nil)
        SecTrustSetPolicies(serverTrust, policy)

        let status = SecTrustEvaluateWithError(serverTrust, nil)

        if status {
            // Check certificate chain using modern API
            if let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] {
                for certificate in certificateChain {
                    let certificateData = SecCertificateCopyData(certificate) as Data

                    // In production, compare against pinned certificates
                    // For now, we'll log the certificate info
                    print("Certificate pinning: Found certificate with length \(certificateData.count)")

                    // TODO: Implement actual certificate pinning logic
                    // if pinnedCertificates.contains(certificateData) {
                    //     return true
                    // }
                }
            }

            // For development, accept valid certificates
            // In production, this should be: return false
            // With the new API, if SecTrustEvaluateWithError returns true, trust is valid
            return true
        }

        return false
    }
}