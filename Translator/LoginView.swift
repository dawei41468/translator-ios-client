import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authVM: AuthViewModel
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
                Task {
                    do {
                        try await authVM.login(email: email, password: password)
                    } catch {
                        // Ignore cancellation errors from session cleanup
                        if (error as? URLError)?.code != .cancelled {
                            authVM.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Guest") { showingGuest = true }
            Button("Register") { showingRegister = true }
        }
        .padding()
        .sheet(isPresented: $showingGuest) { GuestLoginView() }
        .sheet(isPresented: $showingRegister) { RegisterView() }
        .navigationTitle("Login")
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
