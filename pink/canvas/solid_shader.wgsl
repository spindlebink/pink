// http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html
fn linear_to_gamma(color: vec3<f32>) -> vec3<f32> {
    return color * (color * (color * 0.305306011 + 0.682171111) + 0.012522878);
};

fn transform2d(
    vertex_position: vec2<f32>,
    translation: vec2<f32>,
    scale: vec2<f32>,
    rotation: f32,
    origin: vec2<f32>,
) -> vec2<f32> {
    let cos_r: f32 = cos(rotation);
    let sin_r: f32 = sin(rotation);
    let c_x: f32 = vertex_position.x * scale.x + scale.x * origin.x;
    let c_y: f32 = vertex_position.y * scale.y - scale.y * origin.y;
    let r_x: f32 = (c_x * cos_r - c_y * sin_r);
    let r_y: f32 = (c_y * cos_r + c_x * sin_r);

    return vec2<f32>(
        r_x - scale.x + translation.x,
        r_y + scale.y + translation.y,
    );
};

struct CanvasState {
    window_to_device: mat4x4<f32>,
};

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

@group(0) @binding(0) var<uniform> canvas_state: CanvasState;

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
