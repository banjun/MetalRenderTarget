import RealityKit
import Metal
import UIKit

public extension Entity {
    static func renderingTarget(renderer: any RenderingSystemRenderer, boardSize: SIMD2<Float> = [1, 1], textureSize: SIMD2<Int> = [1024, 1024], blending: RenderingTargetComponent.Blending = .over, useDepth: Bool = true, vertexFunction: any MTLFunction, device: any MTLDevice = MTLCreateSystemDefaultDevice()!, fragmentFunction: any MTLFunction, rasterizationRateMap: (horizontal: [Float], vertical: [Float])? = nil, rgbGamma: Float = 1, edgeFalloff: Float = 0) throws -> ModelEntity {
        let rasterizationRateMapDescriptor = if let rasterizationRateMap { MTLRasterizationRateMapDescriptor(screenSize: .init(width: textureSize.x, height: textureSize.y, depth: 1), layers: [
                // assuming viewCount = 2
                MTLRasterizationRateLayerDescriptor(
                    horizontal: rasterizationRateMap.horizontal,
                    vertical: rasterizationRateMap.vertical,
                ),
                MTLRasterizationRateLayerDescriptor(
                    horizontal: rasterizationRateMap.horizontal.reversed(),
                    vertical: rasterizationRateMap.vertical,
                )
            ])
        } else { MTLRasterizationRateMapDescriptor?.none }
        // use physical size converted by rrm
        NSLog("%@", "logical size: \(textureSize.x) x \(textureSize.y)")
        let rateMap = RateMap(logicalWidth: textureSize.x, height: textureSize.y, device: device, descriptor: rasterizationRateMapDescriptor)
        NSLog("%@", "physical size: \(rateMap.physical)")

        let llTexture = try LowLevelTexture(descriptor: .init(textureType: .type2DArray, pixelFormat: .rgba16Float, width: rateMap.physical.width, height: rateMap.physical.height, depth: 1, arrayLength: 2, textureUsage: [.renderTarget, .shaderRead]))
        return renderingTarget(renderer: renderer, boardSize: boardSize, texture: llTexture, blending: blending, useDepth: useDepth, vertexFunction: vertexFunction, fragmentFunction: fragmentFunction, rateMap: rateMap, rgbGamma: rgbGamma, edgeFalloff: edgeFalloff)
    }
    static func renderingTarget(renderer: any RenderingSystemRenderer, boardSize: SIMD2<Float> = [1, 1], texture: LowLevelTexture, blending: RenderingTargetComponent.Blending = .over, useDepth: Bool = true, vertexFunction: any MTLFunction, fragmentFunction: any MTLFunction, rateMap: RateMap, rgbGamma: Float = 1, edgeFalloff: Float = 0) -> ModelEntity {
        let e = ModelEntity(mesh: .generatePlane(width: boardSize.x, height: boardSize.y), materials: [UnlitMaterial(color: .clear)])
        e.name = "renderingTarget"
        e.components.set(CameraProjectionBillBoardComponent(
            lt: [-boardSize.x / 2, boardSize.y / 2, 0],
            lb: [-boardSize.x / 2, -boardSize.y / 2, 0],
            rb: [boardSize.x / 2, -boardSize.y / 2, 0],
            rt: [boardSize.x / 2, boardSize.y / 2, 0]))
        let rateMapDecodeTexture = rateMap.underlyingMap.map {_ in RateMapDecodeTexture(rateMap: rateMap)}
        e.components.set(RenderingTargetComponent(renderer: renderer, vertexFunction: vertexFunction, fragmentFunction: fragmentFunction, llTexture: texture, blending: blending, rateMap: rateMap, rateMapDecodeTexture: rateMapDecodeTexture, depthPixelFormat: useDepth ? .depth32Float : nil))
        e.components.set(CameraOrientationAlignedBillboardComponent())
        e.components.set(CameraToBillboardFrustumVisualizationComponent())
        Task {
            var m = try! await ShaderGraphMaterial.unlit(texture2DArray: TextureResource(from: texture), premultipliedAlpha: blending == .preMultiplied, rgbGamma: rgbGamma, edgeFalloff: edgeFalloff, rateMapDecodeTexture: rateMapDecodeTexture)
//            m.readsDepth = false
//            m.writesDepth = false
            m.faceCulling = .back
            e.model!.materials = [m]
        }
        return e
    }

    static func renderingSystemHelperEntities(registerSystems: Bool = true, registerDebugSystems: Bool = false) -> Entity {
        let e = Entity()
        e.name = "renderingSystemHelperEntities"
        e.addChild(DeviceAnchorComponent.entity())
        e.addChild(WorldTrackingProviderComponent.entity())
        e.addChild(DeviceViewpointComponent.entity())
        e.addChild(StereoPropertiesProviderComponent.entity())
        if registerSystems {
            CameraOrientationAlignedBillboardSystem.registerSystem()
            WorldTrackingSystem.registerSystem()
            StereoPropertiesSystem.registerSystem()
            CameraProjectionBillBoardSystem.registerSystem()
            RenderingSystem.registerSystem()
        }
        if registerDebugSystems {
            CameraToBillboardFrustumVisualizationSystem.registerSystem()
        }
        return e
    }
}


