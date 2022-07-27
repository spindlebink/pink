struct Vertex {
    @location(0) pos: vec2<f32>,
};

struct Inst {
    @location(1) trans: vec2<f32>,
    @location(2) scale: vec2<f32>,
    @location(3) rot: f32,
    @location(4) origin: vec2<f32>,
    @location(5) color: vec4<f32>,
};

struct VertexOut {
    @builtin(position) pos: vec4<f32>,
    @location(0) color: vec4<f32>,
};

@vertex
fn vertex(vertex: Vertex, inst: Inst) -> VertexOut {
    var out: VertexOut;
    
    let xformed = transform2d(
        vertex.pos,
        inst.trans,
        inst.scale,
        inst.rot,
        inst.origin,
    );

    out.pos = vec4<f32>(xformed, 1.0, 1.0) * canvas_state.window_to_device;
    out.color = inst.color;

    return out;
}

@fragment
fn fragment(vertex: VertexOut) -> @location(0) vec4<f32> {
    return vec4<f32>(linear_to_gamma(vertex.color.rgb), vertex.color.a);
}
