import RealityKit
import ARKit

public struct DeviceViewpointComponent: Component {
    public var viewpointProperties: ViewpointProperties?
    public var lastUpdated: Date
    public var minimumInterval: TimeInterval // rarely updated, most sessions are just one shot
    @MainActor public static func entity() -> Entity {
        let e = Entity(components: DeviceViewpointComponent())
        e.name = "DeviceViewpointComponent"
        return e
    }
    public var deviceViewpointTransforms: [simd_float4x4]? {
        viewpointProperties.map {[$0.deviceFromLeftViewpointTransform, $0.deviceFromRightViewpointTransform]}
    }
    
    public init(viewpointProperties: ViewpointProperties? = nil, lastUpdated: Date = .distantPast, minimumInterval: TimeInterval = 60) {
        self.viewpointProperties = viewpointProperties
        self.lastUpdated = lastUpdated
        self.minimumInterval = minimumInterval
    }
}

public struct StereoPropertiesProviderComponent: Component {
    public var arkitSession: ARKitSession?
    public var stereoPropertiesProvider: StereoPropertiesProvider?
    public var latestViewpointProperties: ViewpointProperties?
    public var isSessionEnabled: Bool = true
    @MainActor public static func entity() -> Entity {
        let e = Entity(components: StereoPropertiesProviderComponent())
        e.name = "StereoPropertiesProviderComponent"
        return e
    }
}

public struct StereoPropertiesSystem: System {
    static let stereoPropertiesProviderQuery = EntityQuery(where: .has(StereoPropertiesProviderComponent.self))
    static let deviceViewpointQuery = EntityQuery(where: .has(DeviceViewpointComponent.self))
    public init(scene: Scene) {}
    public func update(context: SceneUpdateContext) {
        guard StereoPropertiesProvider.isSupported else { return }
        // choose first enabled one
        guard let stereoPropertiesProviderEntity = (context.entities(matching: Self.stereoPropertiesProviderQuery, updatingSystemWhen: .rendering).first {$0.isEnabledInHierarchy}) else { return }
        var stereoPropertiesProviderComponent = stereoPropertiesProviderEntity.components[StereoPropertiesProviderComponent.self]!
        defer {stereoPropertiesProviderEntity.components.set(stereoPropertiesProviderComponent)}

        if stereoPropertiesProviderComponent.isSessionEnabled {
            guard let stereoPropertiesProvider = stereoPropertiesProviderComponent.stereoPropertiesProvider else {
                let arkitSession = ARKitSession()
                let stereoPropertiesProvider = StereoPropertiesProvider()
                stereoPropertiesProviderComponent.arkitSession = arkitSession
                stereoPropertiesProviderComponent.stereoPropertiesProvider = stereoPropertiesProvider
                Task {
                    do {
                        try await arkitSession.run([stereoPropertiesProvider])
                    } catch {
                        NSLog("%@", "⚠️ \(String(describing: error))")
                        stereoPropertiesProviderComponent = StereoPropertiesProviderComponent()
                    }
                }
                return
            }

            if let latestViewpointProperties = stereoPropertiesProvider.latestViewpointProperties {
                stereoPropertiesProviderComponent.latestViewpointProperties = latestViewpointProperties
                NSLog("%@", "found viewpoint properties: \(latestViewpointProperties)")

                // stop session, one shot
                stereoPropertiesProviderComponent.arkitSession?.stop()
                stereoPropertiesProviderComponent.arkitSession = nil
                stereoPropertiesProviderComponent.stereoPropertiesProvider = nil
                stereoPropertiesProviderComponent.isSessionEnabled = false
            }
        }

        guard let latestViewpointProperties = stereoPropertiesProviderComponent.latestViewpointProperties else { return }
        let now = Date()
        context.entities(matching: Self.deviceViewpointQuery, updatingSystemWhen: .rendering).forEach { e in
            var c = e.components[DeviceViewpointComponent.self]!
            guard now.timeIntervalSince(c.lastUpdated) >= c.minimumInterval else { return }
            defer {e.components.set(c)}
            c.lastUpdated = now
            c.viewpointProperties = latestViewpointProperties
            NSLog("%@", "feed viewpoint properties: \(String(describing: c.viewpointProperties))")
        }
    }
}
