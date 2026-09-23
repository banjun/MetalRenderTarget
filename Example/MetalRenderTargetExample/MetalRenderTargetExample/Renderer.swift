import MetalRenderTarget
import RealityKit
import Metal
import simd

final class Renderer: RenderingSystemRenderer {
    let vertexFunction: any MTLFunction
    let fragmentFunction: any MTLFunction
    
    init() {
        let lib = MTLCreateSystemDefaultDevice()!.makeDefaultLibrary()!
        vertexFunction = lib.makeFunction(name: "vertex1")!
        fragmentFunction = lib.makeFunction(name: "fragment1")!
    }

    func encode(entities: [Entity], encoder: any MTLRenderCommandEncoder, in: any MTLCommandBuffer, cameraProjections: [simd_float4x4], viewMatrices: [simd_float4x4]) {
        var cameraProjections = cameraProjections
        var viewMatrices = viewMatrices
        encoder.setVertexBytes(&cameraProjections, length: MemoryLayout<simd_float4x4>.stride * cameraProjections.count, index: 1)
        encoder.setVertexBytes(&viewMatrices, length: MemoryLayout<simd_float4x4>.stride * cameraProjections.count, index: 2)
        for entity in entities {
            var worldFromModel = entity.transformMatrix(relativeTo: nil)
            encoder.setVertexBytes(&worldFromModel, length: MemoryLayout.stride(ofValue: worldFromModel), index: 3)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: cameraProjections.count)
        }
    }
}
