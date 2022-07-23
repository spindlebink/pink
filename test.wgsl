struct Vert {
    @location(0) position: vec2<f32>,
    @location(1) color: vec3<f32>,
}

struct VertOut {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec3<f32>,
    @location(1) uv: vec2<f32>,
}

@group(0) @binding(0) var image_texture: texture_2d<f32>;
@group(0) @binding(1) var image_sampler: sampler;

@vertex
fn vertex(vert: Vert) -> VertOut {
    var out: VertOut;
    
    out.position = vec4<f32>(vert.position, 1.0, 1.0);
    out.color = vert.color;
    out.uv = vec2<f32>(1.0, 1.0) - (vert.position + vec2<f32>(1.0, 1.0)) / 2.0;

    return out;
}

@fragment
fn fragment(in: VertOut) -> @location(0) vec4<f32> {
    return vec4<f32>(in.color, 1.0) * textureSample(image_texture, image_sampler, in.uv);
}
