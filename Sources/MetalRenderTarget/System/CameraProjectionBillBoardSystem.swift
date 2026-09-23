import RealityKit

public struct CameraProjectionBillBoardComponent: Component {
    public var lt: SIMD3<Float>
    public var lb: SIMD3<Float>
    public var rb: SIMD3<Float>
    public var rt: SIMD3<Float>
    public var zNear: Float
    public var zFar: Float
    // output
    public var cameraMatrices: [(transform: simd_float4x4, projection: simd_float4x4)] = []

    public init(lt: SIMD3<Float>, lb: SIMD3<Float>, rb: SIMD3<Float>, rt: SIMD3<Float>, zNear: Float = 0.097, zFar: Float = .infinity, cameraMatrices: [(transform: simd_float4x4, projection: simd_float4x4)] = []) {
        self.lt = lt
        self.lb = lb
        self.rb = rb
        self.rt = rt
        self.zNear = zNear
        self.zFar = zFar
        self.cameraMatrices = cameraMatrices
    }
}

public struct CameraProjectionBillBoardSystem: System {
    static let billboardQuery = EntityQuery(where: .has(CameraProjectionBillBoardComponent.self))
    static let deviceAnchorQuery = EntityQuery(where: .has(DeviceAnchorComponent.self))
    static let deviceViewpointQuery = EntityQuery(where: .has(DeviceViewpointComponent.self))
    public static var dependencies: [SystemDependency] {[.after(WorldTrackingSystem.self), .after(StereoPropertiesSystem.self), .after(CameraOrientationAlignedBillboardSystem.self)]}

    public init(scene: Scene) {}
    public func update(context: SceneUpdateContext) {
        guard let originFromDeviceTransform = context.entities(matching: Self.deviceAnchorQuery, updatingSystemWhen: .rendering).lazy.compactMap({$0.components[DeviceAnchorComponent.self]!.originFromDeviceTransform}).first else { return }
        let deviceViewpointTransforms = context.entities(matching: Self.deviceViewpointQuery, updatingSystemWhen: .rendering).lazy.compactMap({$0.components[DeviceViewpointComponent.self].flatMap(\.deviceViewpointTransforms)}).first ?? [.init(diagonal: .one)]

        context.entities(matching: Self.billboardQuery, updatingSystemWhen: .rendering).forEach { e in
            var c = e.components[CameraProjectionBillBoardComponent.self]!
            defer {e.components.set(c)}
            let lt = e.convert(transform: Transform(translation: c.lt), to: nil).translation
            let lb = e.convert(transform: Transform(translation: c.lb), to: nil).translation
            let rb = e.convert(transform: Transform(translation: c.rb), to: nil).translation
            // let rt = e.convert(transform: Transform(translation: c.rt), to: nil).translation
            c.cameraMatrices = deviceViewpointTransforms.map { deviceViewpointTransform in
                let cameraTransform = Transform(matrix: originFromDeviceTransform * deviceViewpointTransform)
                let camera = cameraTransform.translation
                let cameraToLB = lb - camera
                let cameraToRB = rb - camera
                let cameraToLT = lt - camera
                let rightDir = normalize(rb - lb)
                let upDir = normalize(lt - lb)
                var normal = normalize(cross(rightDir, upDir))

                var distance = -dot(cameraToLB, normal)
                if distance < 0 {
                    normal = -normal
                    distance = -dot(cameraToLB, normal)
                }
                distance = max(1e-6, distance)

                let left = c.zNear * dot(rightDir, cameraToLB) / distance
                let right = c.zNear * dot(rightDir, cameraToRB) / distance
                let bottom = c.zNear * dot(upDir, cameraToLB) / distance
                let top = c.zNear * dot(upDir, cameraToLT) / distance
                let scale = SIMD3<Float>(
                    2 * c.zNear / (right - left),
                    2 * c.zNear / (top - bottom),
                    c.zFar == .infinity ? 0 : c.zFar / (c.zNear - c.zFar),
                )
                let offset = SIMD2<Float>((right + left) / (right - left), (top + bottom) / (top - bottom))
                return (
                    transform: cameraTransform.matrix,
                    projection: simd_float4x4(
                        SIMD4<Float>(scale.x, 0, 0, 0),
                        SIMD4<Float>(0, scale.y, 0, 0),
                        SIMD4<Float>(offset.x, offset.y, scale.z, -1),
                        SIMD4<Float>(0, 0, (scale.z != 0 ? scale.z : 1) * c.zNear , 0),
                    )
                )
            }
        }
    }
}
