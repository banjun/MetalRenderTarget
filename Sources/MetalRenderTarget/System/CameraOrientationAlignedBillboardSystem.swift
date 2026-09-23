import RealityKit

public struct CameraOrientationAlignedBillboardComponent: Component {
    public init() {}
}
/// Provides camera orientation aligned billboard, which is stable around any view angle, but not always exactly facing to the camera.
/// DeviceAnchorComponent should be updated for working, and you can use WorldTrackingSystem to feed them.
/// Standard RealityKit.BillboardComponents provides view-facing billboard, which uses relative positions from camera to entity and might be unstable from top view angle, due to Hairy Ball Theorem.
public struct CameraOrientationAlignedBillboardSystem: System {
    static let billboardQuery = EntityQuery(where: .has(CameraOrientationAlignedBillboardComponent.self))
    static let deviceAnchorQuery = EntityQuery(where: .has(DeviceAnchorComponent.self))
    public static var dependencies: [SystemDependency] {[.after(WorldTrackingSystem.self)]}
    public init(scene: Scene) {}
    public func update(context: SceneUpdateContext) {
        guard let originFromDeviceTransform = context.entities(matching: Self.deviceAnchorQuery, updatingSystemWhen: .rendering).lazy.compactMap({$0.components[DeviceAnchorComponent.self]!.originFromDeviceTransform}).first else { return }
        context.entities(matching: Self.billboardQuery, updatingSystemWhen: .rendering).forEach { e in
            e.setOrientation(simd_quatf(originFromDeviceTransform), relativeTo: nil)
        }
    }
}

