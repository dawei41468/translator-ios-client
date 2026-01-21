import SwiftUI

struct GuestLoginView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var displayName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Guest Login")
                .font(.largeTitle.bold())

            TextField("Display Name", text: $displayName)
                .textFieldStyle(.roundedBorder)

            if let error = authVM.errorMessage {
                Text(error).foregroundStyle(.red)
            }

            Button("Continue as Guest") {
                Task {
                    do {
                        try await authVM.guest(displayName: displayName)
                        dismiss()  // Success, dismiss sheet
                    } catch {
                        // Ignore cancellation errors from session cleanup
                        if (error as? URLError)?.code != .cancelled {
                            authVM.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Guest")
    }
}

#Preview {
    GuestLoginView()
        .environmentObject(AuthViewModel())
}