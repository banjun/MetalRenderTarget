import RealityKit
import ARKit
import QuartzCore

public struct DeviceAnchorComponent: Component {
    public var originFromDeviceTransform: simd_float4x4?
    @MainActor public static func entity() -> Entity {
        let e = Entity(components: DeviceAnchorComponent())
        e.name = "DeviceAnchorComponent"
        return e
    }

    public init(originFromDeviceTransform: simd_float4x4? = nil) {
        self.originFromDeviceTransform = originFromDeviceTransform
    }
}

public struct WorldTrackingProviderComponent: Component {
    public var arkitSession: ARKitSession?
    public var worldTrackingProvider: WorldTrackingProvider?
    @MainActor public static func entity() -> Entity {
        let e = Entity(components: WorldTrackingProviderComponent())
        e.name = "WorldTrackingProviderComponent"
        return e
    }

    public init(arkitSession: ARKitSession? = nil, worldTrackingProvider: WorldTrackingProvider? = nil) {
        self.arkitSession = arkitSession
        self.worldTrackingProvider = worldTrackingProvider
    }
}

public struct WorldTrackingSystem: System {
    static let worldTrackingProviderQuery = EntityQuery(where: .has(WorldTrackingProviderComponent.self))
    static let deviceAnchorQuery = EntityQuery(where: .has(DeviceAnchorComponent.self))

    public init(scene: Scene) {}
    public func update(context: SceneUpdateContext) {
        let worldTrackingProviders = context.entities(matching: Self.worldTrackingProviderQuery, updatingSystemWhen: .rendering)
        guard let worldTrackingProvider = (worldTrackingProviders.lazy.compactMap {$0.components[WorldTrackingProviderComponent.self]!.worldTrackingProvider}.first) else {
            let arkitSession = ARKitSession()
            let worldTrackingProvider = WorldTrackingProvider()
            worldTrackingProviders.forEach {$0.components.set(WorldTrackingProviderComponent(arkitSession: arkitSession, worldTrackingProvider: worldTrackingProvider))}
            Task {
                do {
                    try await arkitSession.run([worldTrackingProvider])
                } catch {
                    NSLog("%@", "⚠️ \(String(describing: error))")
                    worldTrackingProviders.forEach {$0.components.set(WorldTrackingProviderComponent())}
                }
            }
            return
        }

        let deviceAnchor = worldTrackingProvider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        context.entities(matching: Self.deviceAnchorQuery, updatingSystemWhen: .rendering).forEach { e in
            var c = e.components[DeviceAnchorComponent.self]!
            defer {e.components.set(c)}
            c.originFromDeviceTransform = deviceAnchor?.originFromAnchorTransform
        }
    }
}
