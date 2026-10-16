import Observation

@MainActor
@Observable
final class APNsTokenStore {
    static let shared = APNsTokenStore()
    // Obtain a fresh registration from APNs on every launch, not from disk.
    var token: String?
    private init() {}
}
