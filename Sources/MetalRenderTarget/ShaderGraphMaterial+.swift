import RealityKit

extension ShaderGraphMaterial {
    static func unlit(texture2DArray: TextureResource, rateMapDecodeTexture: RateMapDecodeTexture?) async throws -> ShaderGraphMaterial {
        try await .init(program: .init(descriptor: .unlit(texture2DArray: texture2DArray, rateMapDecodeTexture: rateMapDecodeTexture)))
    }
}

extension ShaderGraphMaterial.Program.Descriptor {
    static func unlit(texture2DArray: TextureResource, rateMapDecodeTexture: RateMapDecodeTexture?) throws -> sending ShaderGraphMaterial.Program.Descriptor {
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
        let a = try graph.addNode( lib.makeNode(from: lib.definition(named: "ND_swizzle_color4_float")!))
        try graph.connect(image, to: a, inputPort: "in")
        try graph.connect(graph.addConstant(.string("a")), to: a, inputPort: "channels")

        let safeA = try graph.addNode( lib.makeNode(from: lib.definition(named: "ND_max_float")!))
        try graph.connect(a, to: safeA, inputPort: "in1")
        try graph.connect(graph.addConstant(.float(0.0001)), to: safeA, inputPort: "in2")

        let straightRGB = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_divide_color3FA")!))
        try graph.connect(rgb, to: straightRGB, inputPort: "in1")
        try graph.connect(safeA, to: straightRGB, inputPort: "in2")

        let gammaRGB = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_power_color3FA")!))
        try graph.connect(straightRGB, to: gammaRGB, inputPort: "in1")
        try graph.connect(graph.addConstant(.float(2.2)), to: gammaRGB, inputPort: "in2")

        let unlit = try graph.addNode(lib.makeNode(from: lib.definition(named: "ND_realitykit_unlit_surfaceshader")!))
        try graph.connect(gammaRGB, to: unlit, inputPort: "color")
        try graph.connect(a, to: unlit, inputPort: "opacity")
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
