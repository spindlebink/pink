// http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html
fn linear_to_gamma(color: vec3<f32>) -> vec3<f32> {
    return color * (color * (color * 0.305306011 + 0.682171111) + 0.012522878);
};

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
    out.modulation = vec4<f32>(linear_to_gamma(instance.modulation.rgb), instance.modulation.a);

    let translation_scale: mat3x3<f32> = mat3x3<f32>(
        instance.scale.x, 0.0, instance.translation.x,
        0.0, instance.scale.y, instance.translation.y,
        0.0, 0.0, 1.0,
    );
    
    out.position = vec4<f32>(
        vec3<f32>(vertex.position, 1.0) * translation_scale,
        1.0
    );

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

@stage(vertex)
fn img_vertex_main(
    vertex: VertexInput,
    instance: InstanceInput,
) -> ImgVertexOutput {
    var out: ImgVertexOutput;
    out.modulation = vec4<f32>(linear_to_gamma(instance.modulation.rgb), instance.modulation.a);
    
    let translation_scale: mat3x3<f32> = mat3x3<f32>(
        instance.scale.x, 0.0, instance.translation.x,
        0.0, instance.scale.y, instance.translation.y,
        0.0, 0.0, 1.0,
    );
    
    out.position = vec4<f32>(
        vec3<f32>(vertex.position, 1.0) * translation_scale,
        1.0
    );
    out.uv = vec2<f32>(1.0, 1.0) - (vertex.position + vec2<f32>(1.0, 1.0)) / 2.0;
    return out;
}

@group(0) @binding(0) var img_texture: texture_2d<f32>;
@group(0) @binding(1) var img_sampler: sampler;

@stage(fragment)
fn img_fragment_main(
    in: ImgVertexOutput
) -> @location(0) vec4<f32> {
    return in.modulation * textureSample(img_texture, img_sampler, in.uv);
}
