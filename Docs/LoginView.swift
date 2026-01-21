import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var email = ""
    @State private var password = ""
    @State private var showingGuest = false
    @State private var showingRegister = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Translator")
                .font(.largeTitle.bold())
            
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            if let error = authVM.errorMessage {
                Text(error).foregroundStyle(.red)
            }
            
            Button("Login") {
                Task { try? await authVM.login(email: email, password: password) }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Guest") { showingGuest = true }
            Button("Register") { showingRegister = true }
        }
        .padding()
        .sheet("Guest Sheet Stub") { EmptyView() }  // Replace w/ GuestView
        .sheet("Register Stub") { EmptyView() }
        .navigationTitle("Login")
    }
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}
