import RealityKit

public extension ShaderGraphMaterial {
    static func unlit(texture2DArray: TextureResource, premultipliedAlpha: Bool = false, rgbGamma: Float = 1, edgeFalloff: Float = 0, rateMapDecodeTexture: RateMapDecodeTexture? = nil) async throws -> ShaderGraphMaterial {
        try await .init(program: .init(descriptor: .unlit(texture2DArray: texture2DArray, premultipliedAlpha: premultipliedAlpha, rgbGamma: rgbGamma, edgeFalloff: edgeFalloff, rateMapDecodeTexture: rateMapDecodeTexture)))
    }
}

public extension ShaderGraphMaterial.Program.Descriptor {
    static func unlit(texture2DArray: TextureResource, premultipliedAlpha: Bool = false, rgbGamma: Float = 1, edgeFalloff: Float = 0, rateMapDecodeTexture: RateMapDecodeTexture? = nil) throws -> sending ShaderGraphMaterial.Program.Descriptor {
        let lib = ShaderGraph.NodeLibrary(version: .default)
        let inputTexture = ShaderGraph.NodeDefinition.Input(name: "texture", type: .texture)
        let inputRateMapDecodeTexture = rateMapDecodeTexture.map {_ in ShaderGraph.NodeDefinition.Input(name: "rateMap", type: .texture)}
        let graph = try ShaderGraph(named: "g", inputs: [inputTexture, inputRateMapDecodeTexture].compactMap(\.self), outputs: [.init(name: "out", type: .surfaceShader)], nodeLibrary: lib)

        let cameraIndex = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_realitykit_geometry_switch_cameraindex_integer")!))
        try graph.connect(graph.addConstant(.int(0)), to: cameraIndex, inputPort: "mono")
        try graph.connect(graph.addConstant(.int(0)), to: cameraIndex, inputPort: "left")
        try graph.connect(graph.addConstant(.int(1)), to: cameraIndex, inputPort: "right")

        let image = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_RealityKitTexture2DArray_color4")!))
        try graph.connect(graph.arguments.name, outputPort: inputTexture.name, to: image, inputPort: "file")
        try graph.connect(cameraIndex, to: image, inputPort: "index")

        if let inputRateMapDecodeTexture {
            let lut = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_RealityKitTexture2DArray_vector4")!))
            try graph.connect(graph.arguments.name, outputPort: inputRateMapDecodeTexture.name, to: lut, inputPort: "file")
            try graph.connect(cameraIndex, to: lut, inputPort: "index")
            try graph.connect(graph.addConstant(.bool(true)), to: lut, inputPort: "no_flip_v")

            let uv = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_swizzle_vector4_vector2")!))
            try graph.connect(lut, to: uv, inputPort: "in")
            try graph.connect(graph.addConstant(.string("xy")), to: uv, inputPort: "channels")

            try graph.connect(uv, to: image, inputPort: "texcoord")
        } else {
            try graph.connect(graph.addConstant(.bool(true)), to: image, inputPort: "no_flip_v")
        }

        let rgb = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_swizzle_color4_color3")!))
        try graph.connect(image, to: rgb, inputPort: "in")
        try graph.connect(graph.addConstant(.string("rgb")), to: rgb, inputPort: "channels")
        let a = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_swizzle_color4_float")!))
        try graph.connect(image, to: a, inputPort: "in")
        try graph.connect(graph.addConstant(.string("a")), to: a, inputPort: "channels")

        var straightRGB = rgb
        if premultipliedAlpha {
            let safeA = try graph.addNode( lib.makeNode(from: lib.definition(named: "ND_max_float")!))
            try graph.connect(a, to: safeA, inputPort: "in1")
            try graph.connect(graph.addConstant(.float(0.0001)), to: safeA, inputPort: "in2")

            straightRGB = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_divide_color3FA")!))
            try graph.connect(rgb, to: straightRGB, inputPort: "in1")
            try graph.connect(safeA, to: straightRGB, inputPort: "in2")
        }

        var finalRGB = straightRGB
        if rgbGamma != 1 {
            finalRGB = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_power_color3FA")!))
            try graph.connect(straightRGB, to: finalRGB, inputPort: "in1")
            try graph.connect(graph.addConstant(.float(rgbGamma)), to: finalRGB, inputPort: "in2")
        }

        var finalAlpha = a
        if edgeFalloff > 0 {
            let sigmoidAlpha: Float = 100

            let uv = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_texcoord_vector2")!))
            let uv05 = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_subtract_vector2")!))
            try graph.connect(uv, to: uv05, inputPort: "in1")
            try graph.connect(graph.addConstant(.float2([0.5, 0.5])), to: uv05, inputPort: "in2")

            let uvabs = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_absval_vector2")!))
            try graph.connect(uv05, to: uvabs, inputPort: "in")

            let sigmoidExpX = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_subtract_vector2")!))
            try graph.connect(uvabs, to: sigmoidExpX, inputPort: "in1")
            try graph.connect(graph.addConstant(.float2(.init(repeating: 0.5 - edgeFalloff / 2))), to: sigmoidExpX, inputPort: "in2")

            let sigmoidExpKX = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_multiply_vector2")!))
            try graph.connect(graph.addConstant(.float2(.init(repeating: sigmoidAlpha))), to: sigmoidExpKX, inputPort: "in1")
            try graph.connect(sigmoidExpX, to: sigmoidExpKX, inputPort: "in2")

            let sigmoidExp = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_exp_vector2")!))
            try graph.connect(sigmoidExpKX, to: sigmoidExp, inputPort: "in")

            let sigmoidDenom = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_add_vector2")!))
            try graph.connect(graph.addConstant(.float2([1, 1])), to: sigmoidDenom, inputPort: "in1")
            try graph.connect(sigmoidExp, to: sigmoidDenom, inputPort: "in2")

            let sigmoid = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_divide_vector2")!))
            try graph.connect(graph.addConstant(.float2([1, 1])), to: sigmoid, inputPort: "in1")
            try graph.connect(sigmoidDenom, to: sigmoid, inputPort: "in2")

            let x = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_swizzle_vector2_float")!))
            try graph.connect(sigmoid, to: x, inputPort: "in")
            try graph.connect(graph.addConstant(.string("x")), to: x, inputPort: "channels")
            let y = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_swizzle_vector2_float")!))
            try graph.connect(sigmoid, to: y, inputPort: "in")
            try graph.connect(graph.addConstant(.string("y")), to: y, inputPort: "channels")

            let falloffAlpha = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_min_float")!))
            try graph.connect(x, to: falloffAlpha, inputPort: "in1")
            try graph.connect(y, to: falloffAlpha, inputPort: "in2")

            finalAlpha = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_min_float")!))
            try graph.connect(a, to: finalAlpha, inputPort: "in1")
            try graph.connect(falloffAlpha, to: finalAlpha, inputPort: "in2")
        }

        let unlit = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_realitykit_unlit_surfaceshader")!))
        try graph.connect(finalRGB, to: unlit, inputPort: "color")
        try graph.connect(finalAlpha, to: unlit, inputPort: "opacity")
        try graph.connect(unlit, to: graph.results.name, inputPort: graph.outputs.first!.name)

        var inputValues: [String: MaterialParameters.Value] = [
            inputTexture.name: .textureResource(texture2DArray),
        ]
        if let inputRateMapDecodeTexture, let rateMapDecodeTexture {
            inputValues[inputRateMapDecodeTexture.name] = .textureResource(rateMapDecodeTexture.textureResource)
        }
        return try .init(inferredFrom: graph, inputValues: inputValues)
    }
}
