# MetalRenderTarget
Metal rendered billboard co-exist with RealityKit scene, without using CompositorService

## Specs
- Requires ImmersiveSpace for DeviceAnchor
- Provides RealityKit billboard entity for a rendered texture (supports only rectangle shape)
- Calculates camera projection matrices, and view matrices (camera transform inverses)
- Provides simple render pipeline
- Supports stereoscopic in physical devivce, providing each camera positions using API
- Provides fixed variable rasterization rate map and decoding (no foveation map)

## More Context
- https://x.com/banjun/status/2101699151050485809
- https://www.youtube.com/watch?v=M0sNC0SrQTQ
