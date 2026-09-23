import RealityKit
import UIKit
public struct CameraToBillboardFrustumVisualizationComponent: Component {
    public var visualizationRoot: Entity
    @MainActor public init() {
        let visualizationRoot = Entity()
        visualizationRoot.name = "CameraToBillboardFrustumVisualization"
        self.visualizationRoot = visualizationRoot
    }
}
public struct CameraToBillboardFrustumVisualizationSystem: System {
    static let query = EntityQuery(where: .has(CameraToBillboardFrustumVisualizationComponent.self) && .has(CameraProjectionBillBoardComponent.self))
    static let deviceAnchorQuery = EntityQuery(where: .has(DeviceAnchorComponent.self))
    static let deviceViewpointQuery = EntityQuery(where: .has(DeviceViewpointComponent.self))
    public static var dependencies: [SystemDependency] {[.after(WorldTrackingSystem.self), .after(StereoPropertiesSystem.self)]}
    public init(scene: Scene) {}
    public func update(context: SceneUpdateContext) {
        let originFromDeviceTransform = context.entities(matching: Self.deviceAnchorQuery, updatingSystemWhen: .rendering).lazy.compactMap({$0.components[DeviceAnchorComponent.self]!.originFromDeviceTransform}).first
        let deviceViewpointTransforms = context.entities(matching: Self.deviceViewpointQuery, updatingSystemWhen: .rendering).lazy.compactMap({$0.components[DeviceViewpointComponent.self].flatMap(\.deviceViewpointTransforms)}).first ?? [.init(diagonal: .one)]

        context.entities(matching: Self.query, updatingSystemWhen: .rendering).forEach { e in
            let vc = e.components[CameraToBillboardFrustumVisualizationComponent.self]!
            let pc = e.components[CameraProjectionBillBoardComponent.self]!
            guard let originFromDeviceTransform else {
                vc.visualizationRoot.removeFromParent()
                return
            }

            if vc.visualizationRoot.parent != e || vc.visualizationRoot.children.count != deviceViewpointTransforms.count * 4 {
                vc.visualizationRoot.children.removeAll()
                e.addChild(vc.visualizationRoot)

                deviceViewpointTransforms.enumerated().flatMap { i, _ in
                    let cylinder = ModelEntity(mesh: .generateCylinder(height: 1, radius: 0.005), materials: [UnlitMaterial(color: [UIColor.green, UIColor.red][i % 2], applyPostProcessToneMap: false)])
                    return [cylinder.clone(recursive: true), cylinder.clone(recursive: true), cylinder.clone(recursive: true), cylinder.clone(recursive: true)]
                }.forEach {vc.visualizationRoot.addChild($0)}
            }

            for i in 0..<deviceViewpointTransforms.count {
                let deviceFromViewPointTransform = deviceViewpointTransforms[i]
                let lt = vc.visualizationRoot.children[i * 4 + 0]
                let lb = vc.visualizationRoot.children[i * 4 + 1]
                let rb = vc.visualizationRoot.children[i * 4 + 2]
                let rt = vc.visualizationRoot.children[i * 4 + 3]
                let visualizationRootFromViewPoint = vc.visualizationRoot.convert(transform: Transform(matrix: originFromDeviceTransform * deviceFromViewPointTransform), from: nil)

                lt.transform = vc.visualizationRoot.convert(
                    transform: Transform(
                        scale: .init(1, length(pc.lt - visualizationRootFromViewPoint.translation) / 2, 1),
                        rotation: .init(from: [0, 1, 0], to: normalize(pc.lt - visualizationRootFromViewPoint.translation)),
                        translation: (pc.lt + visualizationRootFromViewPoint.translation) / 2,
                    ), from: vc.visualizationRoot)
                lb.transform = vc.visualizationRoot.convert(
                    transform: Transform(
                        scale: .init(1, length(pc.lb - visualizationRootFromViewPoint.translation) / 2, 1),
                        rotation: .init(from: [0, 1, 0], to: normalize(pc.lb - visualizationRootFromViewPoint.translation)),
                        translation: (pc.lb + visualizationRootFromViewPoint.translation) / 2,
                    ), from: vc.visualizationRoot)
                rb.transform = vc.visualizationRoot.convert(
                    transform: Transform(
                        scale: .init(1, length(pc.rb - visualizationRootFromViewPoint.translation) / 2, 1),
                        rotation: .init(from: [0, 1, 0], to: normalize(pc.rb - visualizationRootFromViewPoint.translation)),
                        translation: (pc.rb + visualizationRootFromViewPoint.translation) / 2,
                    ), from: vc.visualizationRoot)
                rt.transform = vc.visualizationRoot.convert(
                    transform: Transform(
                        scale: .init(1, length(pc.rt - visualizationRootFromViewPoint.translation) / 2, 1),
                        rotation: .init(from: [0, 1, 0], to: normalize(pc.rt - visualizationRootFromViewPoint.translation)),
                        translation: (pc.rt + visualizationRootFromViewPoint.translation) / 2,
                    ), from: vc.visualizationRoot)
            }
        }
    }
}
