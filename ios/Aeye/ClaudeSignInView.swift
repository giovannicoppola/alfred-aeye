import AuthenticationServices
import SwiftUI
import UIKit

/// Claude sign-in, run through `ASWebAuthenticationSession` rather than an
/// embedded web view: Google and the other SSO providers refuse to serve OAuth
/// inside `WKWebView`, and the session shares Safari's cookies so an existing
/// claude.ai login carries over.
///
/// The Claude Code OAuth client only registers the copy-the-code redirect, so
/// the last step is a paste back into the app.
struct ClaudeSignInView: View {
    let onCapture: (ClaudeOAuth.Tokens) throws -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var attempt: ClaudeOAuth.Attempt?
    @State private var pasted = ""
    @State private var isExchanging = false
    @State private var error: String?
    @State private var presenter = WebAuthPresenter()

    private var canFinish: Bool {
        attempt != nil
            && !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isExchanging
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Aeye signs in with the same Claude Code OAuth flow your Mac uses, in Safari so Google and SSO work. Approve access, copy the code Claude shows you, then paste it below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Step 1") {
                    Button {
                        startAuthorization()
                    } label: {
                        Label(
                            attempt == nil ? "Open Claude sign-in" : "Open Claude sign-in again",
                            systemImage: "safari"
                        )
                    }
                    .disabled(isExchanging)
                }

                Section("Step 2") {
                    TextField("Paste the code Claude showed", text: $pasted)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(attempt == nil)
                    Button("Paste from clipboard") {
                        pasted = UIPasteboard.general.string ?? ""
                    }
                    .disabled(attempt == nil)
                    Button {
                        finish()
                    } label: {
                        if isExchanging {
                            ProgressView()
                        } else {
                            Text("Finish sign-in")
                        }
                    }
                    .disabled(!canFinish)
                }

                if let error {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Sign in to Claude")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func startAuthorization() {
        error = nil
        let attempt = ClaudeOAuth.begin()
        self.attempt = attempt

        // No custom scheme is registered for this client, so the session never
        // hands the code back — the user copies it and closes Safari. Cancelling
        // is the expected ending, not an error.
        let session = ASWebAuthenticationSession(
            url: attempt.url,
            callbackURLScheme: "aeye"
        ) { _, _ in }
        session.presentationContextProvider = presenter
        session.prefersEphemeralWebBrowserSession = false
        // The session must outlive this call or it tears itself down immediately.
        presenter.session = session
        if !session.start() {
            presenter.session = nil
            self.attempt = nil
            error = "Could not open Safari for sign-in."
        }
    }

    private func finish() {
        guard let attempt else { return }
        isExchanging = true
        error = nil
        Task {
            do {
                let tokens = try await ClaudeOAuth.exchange(pasted: pasted, attempt: attempt)
                try onCapture(tokens)
                isExchanging = false
                dismiss()
            } catch {
                isExchanging = false
                self.error = error.localizedDescription
            }
        }
    }
}
