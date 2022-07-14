// http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html
fn pk_linear_to_gamma(color: vec3<f32>) -> vec3<f32> {
    return color * (color * (color * 0.305306011 + 0.682171111) + 0.012522878);
};

fn pk_transform_2d(
    vertex_position: vec2<f32>,
    translation: vec2<f32>,
    scale: vec2<f32>,
    rotation: f32,
) -> vec2<f32> {
    let cos_r: f32 = cos(rotation);
    let sin_r: f32 = sin(rotation);
    let c_x: f32 = vertex_position.x * scale.x + scale.x;
    let c_y: f32 = vertex_position.y * scale.y - scale.y;
    let r_x: f32 = (c_x * cos_r - c_y * sin_r);
    let r_y: f32 = (c_y * cos_r + c_x * sin_r);

    return vec2<f32>(
        r_x - scale.x + translation.x,
        r_y + scale.y + translation.y,
    );
};

struct RenderState {
    window_to_device: mat4x4<f32>,
};

struct CanvasState {
    color: vec4<f32>,
};

var<push_constant> pk_canvas_state: CanvasState;

@group(0) @binding(0) var<uniform> pk_render_state: RenderState;
