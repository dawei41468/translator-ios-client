import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Register")
                .font(.largeTitle.bold())

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            if let error = authVM.errorMessage {
                Text(error).foregroundStyle(.red)
            }

            Button("Register") {
                Task {
                    do {
                        try await authVM.register(email: email, password: password, name: name)
                        dismiss()  // Success, dismiss sheet
                    } catch {
                        authVM.errorMessage = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Register")
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthViewModel())
}