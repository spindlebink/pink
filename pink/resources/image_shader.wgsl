struct Vertex {
    @location(0) position: vec2<f32>,
};

struct Instance {
    @location(1) translation: vec2<f32>,
    @location(2) scale: vec2<f32>,
    @location(3) rotation: f32,
    @location(4) modulation: vec4<f32>,
};

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) modulation: vec4<f32>,
    @location(1) uv: vec2<f32>,
};

struct FragmentOutput {
    @location(0) color: vec4<f32>,
};

@group(1) @binding(0) var image_texture: texture_2d<f32>;
@group(1) @binding(1) var image_sampler: sampler;

@stage(vertex)
fn vertex_main(
    vertex: Vertex,
    instance: Instance,
) -> VertexOutput {
    var out: VertexOutput;
    out.modulation = vec4<f32>(pk_linear_to_gamma(instance.modulation.rgb) * instance.modulation.a, instance.modulation.a);
    
    out.position = vec4<f32>(
        pk_transform_2d(
            vertex.position,
            instance.translation,
            instance.scale,
            instance.rotation,
        ),
        1.0, 1.0,
    ) * pk_data.window_to_device;
    out.uv = vec2<f32>(1.0, 1.0) - (vertex.position + vec2<f32>(1.0, 1.0)) / 2.0;

    return out;
}

@stage(fragment)
fn fragment_main(
    in: VertexOutput
) -> FragmentOutput {
    var out: FragmentOutput;

    out.color = in.modulation * textureSample(image_texture, image_sampler, in.uv);

    return out;
}
