struct Vertex {
    @location(0) pos: vec2<f32>,
    @location(1) uv_indices: vec2<u32>,
};

struct Inst {
    @location(2) trans: vec2<f32>,
    @location(3) scale: vec2<f32>,
    @location(4) rot: f32,
    @location(5) origin: vec2<f32>,
    @location(6) color: vec4<f32>,
    @location(7) uv: vec4<f32>,
    @location(8) texture_flags: u32,
};

struct VertexOut {
    @builtin(position) pos: vec4<f32>,
    @location(0) color: vec4<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) flags: u32,
};

@group(1) @binding(0) var image_texture: texture_2d<f32>;
@group(1) @binding(1) var image_sampler: sampler;

@vertex
fn vertex(vertex: Vertex, inst: Inst, @builtin(vertex_index) index: u32) -> VertexOut {
    var out: VertexOut;
    
    let xformed = transform2d(
        vertex.pos,
        inst.trans,
        inst.scale,
        inst.rot,
        inst.origin,
    );

    out.pos = vec4<f32>(xformed, 1.0, 1.0) * canvas_state.window_to_device;
    out.color = vec4<f32>(linear_to_gamma(inst.color.rgb), inst.color.a);
    out.uv = vec2<f32>(
        inst.uv[vertex.uv_indices.x],
        inst.uv[vertex.uv_indices.y],
    );

    out.flags = inst.texture_flags;
    
    return out;
}

@fragment
fn fragment(in: VertexOut) -> @location(0) vec4<f32> {
    let s: vec4<f32> = textureSample(image_texture, image_sampler, in.uv);
    // right now there's only one flag--for RGBA conversion--so just check 0
    return vec4<f32>(in.color * select(s.rrrr, s.rgba, in.flags == 0u));
}
