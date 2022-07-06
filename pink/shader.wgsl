// http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html
fn linear_to_gamma(color: vec3<f32>) -> vec3<f32> {
    return color * (color * (color * 0.305306011 + 0.682171111) + 0.012522878);
};

fn xform_2d(
    vpos: vec2<f32>,
    trans: vec2<f32>,
    scale: vec2<f32>,
    rot: f32,
) -> vec2<f32> {
    let cos_r: f32 = cos(rot);
    let sin_r: f32 = sin(rot);
    let c_x: f32 = vpos.x * scale.x + scale.x;
    let c_y: f32 = vpos.y * scale.y - scale.y;
    let r_x: f32 = (c_x * cos_r - c_y * sin_r);
    let r_y: f32 = (c_y * cos_r + c_x * sin_r);

    return vec2<f32>(
        r_x - scale.x + trans.x,
        r_y + scale.y + trans.y,
    );
};

struct CameraUniform {
    // Matrix transforming window (0-size) dimensions to normalized device
    // coordinates
    window_to_device: mat4x4<f32>,
};

@group(0) @binding(0) var<uniform> camera: CameraUniform;

//
// Primitive pipeline shaders
//

struct VertexInput {
    @location(0) position: vec2<f32>,
};

struct InstanceInput {
    @location(1) translation: vec2<f32>,
    @location(2) scale: vec2<f32>,
    @location(3) rotation: f32,
    @location(4) modulation: vec4<f32>,
};

struct PrimVertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) modulation: vec4<f32>,
};

@stage(vertex)
fn prim_vertex_main(
    vertex: VertexInput,
    instance: InstanceInput,
) -> PrimVertexOutput {
    var out: PrimVertexOutput;
    out.modulation = vec4<f32>(
        linear_to_gamma(instance.modulation.rgb),
        instance.modulation.a,
    );
    
    out.position = vec4<f32>(
        xform_2d(
            vertex.position,
            instance.translation,
            instance.scale,
            instance.rotation,
        ),
        1.0,
        1.0,
    ) * camera.window_to_device;

    return out;
}

@stage(fragment)
fn prim_fragment_main(
    in: PrimVertexOutput
) -> @location(0) vec4<f32> {
    return in.modulation;
}

//
// Image pipeline shaders
//

struct ImgVertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) modulation: vec4<f32>,
    @location(1) uv: vec2<f32>,
};

@group(1) @binding(0) var img_texture: texture_2d<f32>;
@group(1) @binding(1) var img_sampler: sampler;

@stage(vertex)
fn img_vertex_main(
    vertex: VertexInput,
    instance: InstanceInput,
) -> ImgVertexOutput {
    var out: ImgVertexOutput;
    out.modulation = vec4<f32>(linear_to_gamma(instance.modulation.rgb) * instance.modulation.a, instance.modulation.a);
    
    out.position = vec4<f32>(
        xform_2d(
            vertex.position,
            instance.translation,
            instance.scale,
            instance.rotation,
        ),
        1.0,
        1.0,
    ) * camera.window_to_device;
    out.uv = vec2<f32>(1.0, 1.0) - (vertex.position + vec2<f32>(1.0, 1.0)) / 2.0;

    return out;
}

@stage(fragment)
fn img_fragment_main(
    in: ImgVertexOutput
) -> @location(0) vec4<f32> {
    return in.modulation * textureSample(img_texture, img_sampler, in.uv);
}
