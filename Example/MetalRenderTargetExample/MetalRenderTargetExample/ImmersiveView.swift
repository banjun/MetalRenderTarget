import SwiftUI
import RealityKit
import MetalRenderTarget
import Metal

struct ImmersiveView: View {
    @State private var renderer = Renderer()
    var body: some View {
        RealityView { content in
            // place render target billboard, showing renderer result
            let renderTarget = try! Entity.renderingTarget(renderer: renderer, vertexFunction: renderer.vertexFunction, fragmentFunction: renderer.fragmentFunction)
            renderTarget.position = [0, 1, -1]
            content.add(renderTarget)
            // activate rendering system
            content.add(Entity.renderingSystemHelperEntities(registerSystems: true, registerDebugSystems: true))

            let box1 = ModelEntity(mesh: .generateBox(size: 0.05))
            box1.components.set(RenderingSystemEncoderComponent(renderers: [renderer])) // let box1 processed by the renderer
            box1.position = [0, 1, -1]
            content.add(box1)

            let box2 = ModelEntity(mesh: .generateBox(size: 0.1))
            box2.components.set(RenderingSystemEncoderComponent(renderers: [renderer])) // let box2 processed by the renderer
            box2.position = [0.5, 1, -1]
            content.add(box2)

            #if os(visionOS)
            // move around render target and other entities by gesture
            [renderTarget, box1, box2].forEach { e in
                ManipulationComponent.configureEntity(e)
                e.components[ManipulationComponent.self]!.releaseBehavior = .stay
                e.components[ManipulationComponent.self]!.dynamics.translationBehavior = .unconstrained
                e.components[ManipulationComponent.self]!.dynamics.scalingBehavior = .unconstrained
                e.components[ManipulationComponent.self]!.dynamics.primaryRotationBehavior = .unconstrained
                e.components[ManipulationComponent.self]!.dynamics.secondaryRotationBehavior = .unconstrained
            }
            #else
            // in macOS, one camera entity should be added to get from WorldTrackingSystem
            let camera = Entity()
            camera.components.set(PerspectiveCameraComponent())
            // camera.position = [0, 1.5, 0]
            content.add(camera)
            content.cameraTarget = renderTarget
            #endif
        }
    }
}

#if os(visionOS)
#Preview {
    ImmersiveView()
}
#endif
