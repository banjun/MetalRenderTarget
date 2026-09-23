import SwiftUI
import RealityKit

struct ContentView: View {
    var body: some View {
        VStack {
            Text("MetalRenderTargetExample").font(.largeTitle)
                .padding()
            ToggleImmersiveSpaceButton()
        }
        .padding()
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
