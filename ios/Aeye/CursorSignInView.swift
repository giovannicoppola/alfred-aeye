import AuthenticationServices
import SwiftUI
import UIKit

/// Cursor sign-in through the browser, for the same reason as
/// ``ClaudeSignInView``: Google and the other SSO providers refuse to serve
/// their login inside an app's web view.
///
/// Cursor's flow polls for the result, so unlike Claude there is nothing to
/// paste — finishing in Safari is enough.
struct CursorSignInView: View {
    let onCapture: (String) throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var status = "Not started"
    @State private var isWaiting = false
    @State private var error: String?
    @State private var presenter = WebAuthPresenter()
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Aeye opens Cursor's sign-in in Safari, so Google and the other providers work. Finish there and come back — Aeye picks up the session on its own.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        start()
                    } label: {
                        Label(
                            isWaiting ? "Open Cursor sign-in again" : "Open Cursor sign-in",
                            systemImage: "safari"
                        )
                    }
                    HStack {
                        if isWaiting { ProgressView() }
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Sign in to Cursor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onDisappear {
                pollTask?.cancel()
                pollTask = nil
            }
        }
    }

    private func start() {
        error = nil
        pollTask?.cancel()

        let attempt = CursorAuth.begin()

        // The session has no callback scheme to match — Cursor hands the result
        // back over the poll endpoint, not a redirect into the app.
        let session = ASWebAuthenticationSession(
            url: attempt.url,
            callbackURLScheme: "aeye"
        ) { _, _ in }
        session.presentationContextProvider = presenter
        session.prefersEphemeralWebBrowserSession = false
        // The session must outlive this call or it tears itself down immediately.
        presenter.session = session

        guard session.start() else {
            presenter.session = nil
            error = "Could not open Safari for sign-in."
            return
        }

        isWaiting = true
        status = "Waiting for you to finish in Safari…"
        pollTask = Task {
            do {
                let token = try await CursorAuth.awaitToken(attempt: attempt)
                try onCapture(CursorClient.normalizeCookieValue(token))
                isWaiting = false
                status = "Signed in"
                dismiss()
            } catch is CancellationError {
                // Sheet closed; nothing to report.
            } catch {
                isWaiting = false
                status = "Not signed in"
                self.error = error.localizedDescription
            }
        }
    }
}

@MainActor
final class WebAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    /// Holds the running session; ARC would otherwise release it on return.
    var session: ASWebAuthenticationSession?

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
            return scene?.keyWindow ?? ASPresentationAnchor()
        }
    }
}
