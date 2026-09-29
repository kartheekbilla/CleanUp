import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case media = "Media"
    case contacts = "Contacts"
    case utilities = "Utilities"
    case extras = "Extras"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .dashboard: return "house.fill"
        case .media: return "photo.stack.fill"
        case .contacts: return "person.2.fill"
        case .utilities: return "sparkles"
        case .extras: return "gearshape.fill"
        }
    }
}

struct GlassyTabBar: View {
    @Binding var selectedTab: AppTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        ZStack {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.blue.opacity(0.18))
                                    .matchedGeometryEffect(id: "ActiveTabPill", in: tabNamespace)
                                    .frame(width: 48, height: 28)
                            }
                            
                            Image(systemName: tab.iconName)
                                .font(.system(size: 17, weight: selectedTab == tab ? .bold : .medium))
                                .foregroundColor(selectedTab == tab ? .blue : .secondary)
                        }
                        
                        Text(tab.rawValue)
                            .font(.system(size: 9, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundColor(selectedTab == tab ? .blue : .secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .liquidGlassCard(cornerRadius: 30, highlightOpacity: 0.4)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
    
    @Namespace private var tabNamespace
}
