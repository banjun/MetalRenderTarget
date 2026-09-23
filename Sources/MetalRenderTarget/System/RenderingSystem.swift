import RealityKit
import Metal
import QuartzCore

public struct RenderingTargetComponent: Component {
    public var renderer: any RenderingSystemRenderer
    /// [[vertex]] func
    public var vertexFunction: any MTLFunction
    /// [[fragment]] func
    public var fragmentFunction: any MTLFunction
    /// output color texture, this should be feed by caller
    public var llTexture: LowLevelTexture
    /// set blend mode
    public var blending: Blending?
    public enum Blending { case over, preMultiplied
        #if !targetEnvironment(simulator)
        case preMultipliedFrontToBack
        #endif
    }
    public var rateMap: RateMap
    public var rateMapDecodeTexture: RateMapDecodeTexture?
    /// set depth pixel format to support depth (default is supported)
    public var depthPixelFormat: MTLPixelFormat? = .depth32Float
    /// System automatically creates this depth texture if needed
    public var depthTexture: (any MTLTexture)?
    /// System automatically creates this queue if needed
    public var commandQueue: (any MTLCommandQueue)?
    /// System automatically creates this state if needed
    public var renderPipelineState: (any MTLRenderPipelineState)?
    /// System automatically creates this state if needed
    public var depthStencilState: (any MTLDepthStencilState)?

    public init(renderer: any RenderingSystemRenderer, vertexFunction: any MTLFunction, fragmentFunction: any MTLFunction, llTexture: LowLevelTexture, blending: Blending? = nil, rateMap: RateMap, rateMapDecodeTexture: RateMapDecodeTexture? = nil, depthPixelFormat: MTLPixelFormat? = nil, depthTexture: (any MTLTexture)? = nil, commandQueue: (any MTLCommandQueue)? = nil, renderPipelineState: (any MTLRenderPipelineState)? = nil, depthStencilState: (any MTLDepthStencilState)? = nil) {
        self.renderer = renderer
        self.vertexFunction = vertexFunction
        self.fragmentFunction = fragmentFunction
        self.llTexture = llTexture
        self.blending = blending
        self.rateMap = rateMap
        self.rateMapDecodeTexture = rateMapDecodeTexture
        self.depthPixelFormat = depthPixelFormat
        self.depthTexture = depthTexture
        self.commandQueue = commandQueue
        self.renderPipelineState = renderPipelineState
        self.depthStencilState = depthStencilState
    }
}

public struct RenderingSystemEncoderComponent: Component {
    public var renderers: [any RenderingSystemRenderer]
    public init(renderers: [any RenderingSystemRenderer]) {
        self.renderers = renderers
    }
}

public protocol RenderingSystemRenderer: AnyObject {
    func encode(entities: [Entity], encoder: any MTLRenderCommandEncoder, in: any MTLCommandBuffer, cameraProjections: [simd_float4x4], viewMatrices: [simd_float4x4])
}
extension RenderingSystemRenderer {
    func encode(entities: [Entity], encoder: any MTLRenderCommandEncoder, in: any MTLCommandBuffer, cameraProjections: [simd_float4x4], viewMatrices: [simd_float4x4]) {
//        var cameraProjections = cameraProjections
//        var viewMatrices = viewMatrices
//        encoder.setVertexBytes(&cameraProjections, length: MemoryLayout<simd_float4x4>.stride * cameraProjections.count, index: 0)
//        encoder.setVertexBytes(&viewMatrices, length: MemoryLayout<simd_float4x4>.stride * cameraProjections.count, index: 1)
//        entities.forEach { entity in            
//            var worldFromModel = entity.transformMatrix(relativeTo: nil)
//            encoder.setVertexBytes(&worldFromModel, length: MemoryLayout<simd_float4x4>.stride, index: 2)
//            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 36, instanceCount: cameraProjections.count)
//        }
    }
}

public struct RenderingSystem: System {
    static let query = EntityQuery(where: .has(CameraProjectionBillBoardComponent.self) && .has(RenderingTargetComponent.self))
    static let rendererQuery = EntityQuery(where: .has(RenderingSystemEncoderComponent.self))
    public static var dependencies: [SystemDependency] {[.after(CameraProjectionBillBoardSystem.self)]}

    public init(scene: Scene) {}
    public func update(context: SceneUpdateContext) {
        context.entities(matching: Self.query, updatingSystemWhen: .rendering).forEach { e in
            var c = e.components[RenderingTargetComponent.self]!
            let renderer = c.renderer
            let cameraMatrices = e.components[CameraProjectionBillBoardComponent.self]!.cameraMatrices
            guard !cameraMatrices.isEmpty else { return }
            let cameraProjections = cameraMatrices.map(\.projection)
            let viewMatrices = cameraMatrices.map(\.transform.inverse)
            defer {e.components.set(c)}

            let device = MTLCreateSystemDefaultDevice()!
            guard let commandQueue = c.commandQueue else {
                c.commandQueue = device.makeCommandQueue()
                c.commandQueue?.label = "RenderingSystem"
                return
            }
            guard let renderPipelineState = c.renderPipelineState else {
                let d = MTLRenderPipelineDescriptor()
                d.inputPrimitiveTopology = .triangle
                d.vertexFunction = c.vertexFunction
                d.fragmentFunction = c.fragmentFunction
                d.colorAttachments[0].pixelFormat = c.llTexture.descriptor.pixelFormat
                switch c.blending {
                case .over:
                    d.colorAttachments[0].isBlendingEnabled = true
                    d.colorAttachments[0].rgbBlendOperation = .add
                    d.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                    d.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                    d.colorAttachments[0].alphaBlendOperation = .add
                    d.colorAttachments[0].sourceAlphaBlendFactor = .one
                    d.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
                case .preMultiplied:
                    d.colorAttachments[0].isBlendingEnabled = true
                    d.colorAttachments[0].rgbBlendOperation = .add
                    d.colorAttachments[0].sourceRGBBlendFactor = .one
                    d.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                    d.colorAttachments[0].alphaBlendOperation = .add
                    d.colorAttachments[0].sourceAlphaBlendFactor = .one
                    d.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
#if !targetEnvironment(simulator)
                case .preMultipliedFrontToBack:
                    // Simulator: Error Domain=CompilerError Code=2 "reading from a rendertarget is not supported
                    // related to the [[color(0)]] arg at the fragment shader
                    d.colorAttachments[0].isBlendingEnabled = true
                    d.colorAttachments[0].rgbBlendOperation = .add
                    d.colorAttachments[0].sourceRGBBlendFactor = .oneMinusDestinationAlpha
                    d.colorAttachments[0].destinationRGBBlendFactor = .one
                    d.colorAttachments[0].alphaBlendOperation = .add
                    d.colorAttachments[0].sourceAlphaBlendFactor = .oneMinusDestinationAlpha
                    d.colorAttachments[0].destinationAlphaBlendFactor = .one
#endif
                case .none: break
                }
                // -
                d.depthAttachmentPixelFormat = c.depthPixelFormat ?? .invalid
                // d.maxVertexAmplificationCount = device.supportsVertexAmplificationCount(2) ? 2 : 1
                c.renderPipelineState = try! device.makeRenderPipelineState(descriptor: d)
                return
            }
            if let depthPixelFormat = c.depthPixelFormat, depthPixelFormat != .invalid {
                guard c.depthStencilState != nil else {
                    let d = MTLDepthStencilDescriptor()
                    d.depthCompareFunction = .greater
                    d.isDepthWriteEnabled = true
                    c.depthStencilState = device.makeDepthStencilState(descriptor: d)
                    return
                }

                guard let depthTexture = c.depthTexture,
                      depthTexture.width == c.llTexture.descriptor.width,
                      depthTexture.height == c.llTexture.descriptor.height else {
                    let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: depthPixelFormat, width: c.llTexture.descriptor.width, height: c.llTexture.descriptor.height, mipmapped: false)
                    d.textureType = c.llTexture.descriptor.textureType
                    d.arrayLength = c.llTexture.descriptor.arrayLength
                    d.usage = [.renderTarget]
                    d.storageMode = .private
                    c.depthTexture = device.makeTexture(descriptor: d)
                    return
                }
            }

            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            defer {commandBuffer.commit()}

            c.rateMapDecodeTexture?.drawIfNeeded(in: commandBuffer)

            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.renderTargetArrayLength = cameraMatrices.count
            renderPassDescriptor.rasterizationRateMap = c.rateMap.underlyingMap
            if let colorAttachment = renderPassDescriptor.colorAttachments[0] {
                colorAttachment.texture = c.llTexture.replace(using: commandBuffer)
                colorAttachment.clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
                colorAttachment.loadAction = .clear
                colorAttachment.storeAction = .store
            }
            if let depthTexture = c.depthTexture, let depthAttachment = renderPassDescriptor.depthAttachment {
                depthAttachment.texture = depthTexture
                depthAttachment.clearDepth = 0
                depthAttachment.loadAction = .clear
                depthAttachment.storeAction = .dontCare
            }

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
            defer {encoder.endEncoding()}

            encoder.setRenderPipelineState(renderPipelineState)
            if let depthStencilState = c.depthStencilState {
                encoder.setDepthStencilState(depthStencilState)
            }

            // group by renderer (to reduce redundant vertex/fragment buffer set), and encode entities
            let entities = context.entities(matching: Self.rendererQuery, updatingSystemWhen: .rendering)
                .filter(\.isEnabledInHierarchy)
                .filter {$0.components[RenderingSystemEncoderComponent.self]!.renderers.map {ObjectIdentifier($0)}.contains(ObjectIdentifier(renderer))}
            renderer.encode(entities: entities, encoder: encoder, in: commandBuffer, cameraProjections: cameraProjections, viewMatrices: viewMatrices)
        }
    }
}
