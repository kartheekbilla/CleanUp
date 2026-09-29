import SwiftUI

struct PermissionDeniedView: View {
    let title: String
    let description: String
    let iconName: String
    let onOpenSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 100, height: 100)
                
                Image(systemName: iconName)
                    .font(.system(size: 44))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: onOpenSettings) {
                HStack {
                    Image(systemName: "gear")
                    Text("Open System Settings")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding()
    }
}
