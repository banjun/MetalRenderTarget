import SwiftUI
import RealityKit

@main
struct MetalRenderTargetExampleApp: App {
    @State private var appModel = AppModel()
    @Environment(\.openImmersiveSpace) var openImmersiveSpace

    var body: some SwiftUI.Scene {
        #if os(visionOS)
        WindowGroup {
            ContentView()
                .environment(appModel)
                .onAppear {Task {await openImmersiveSpace(id: appModel.immersiveSpaceID)}}
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        .immersiveEnvironmentBehavior(.coexist)
        #else
        WindowGroup {
            ImmersiveView()
                .environment(appModel)
                .realityViewCameraControls(.orbit)
        }
        #endif
    }
}
