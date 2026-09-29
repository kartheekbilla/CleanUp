import SwiftUI

struct CompletionView: View {
    let freedBytes: Int64
    let deletedCount: Int
    let onDone: () -> Void
    
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0.0
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 130, height: 130)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            
            VStack(spacing: 12) {
                Text("Storage Cleaned!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(StorageManager.formatBytes(freedBytes))
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundColor(.green)
                
                Text("You successfully reclaimed space across \(deletedCount) item(s).")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(opacity)
            
            Spacer()
            
            PrimaryActionButton(
                title: "Back to Dashboard",
                iconName: "house.fill",
                color: .blue
            ) {
                onDone()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
