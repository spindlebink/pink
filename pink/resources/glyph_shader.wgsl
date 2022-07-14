struct Vertex {
    @location(0) position: vec2<f32>,
    @location(1) uv_indices: vec2<u32>,
};

struct Instance {
    @location(2) translation: vec2<f32>,
    @location(3) scale: vec2<f32>,
    @location(4) rotation: f32,
    @location(5) origin: vec2<f32>,
    @location(6) color: vec4<f32>,
    @location(7) uv_extents: vec4<f32>,
};

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec4<f32>,
    @location(1) uv: vec2<f32>,
};

struct FragmentOutput {
    @location(0) color: vec4<f32>,
};

@group(1) @binding(0) var image_texture: texture_2d<f32>;
@group(1) @binding(1) var image_sampler: sampler;

@vertex
fn vertex_main(
    vertex: Vertex,
    instance: Instance,
) -> VertexOutput {
    var out: VertexOutput;

    out.color = vec4<f32>(
        pk_linear_to_gamma(instance.color.rgb),
        instance.color.a,
    );
    
    out.position = vec4<f32>(
        pk_transform_2d(
            vertex.position,
            instance.translation,
            instance.scale,
            instance.rotation,
            instance.origin,
        ),
        1.0, 1.0,
    ) * pk_render_state.window_to_device;

    out.uv = vec2<f32>(
        instance.uv_extents[vertex.uv_indices[0]],
        instance.uv_extents[vertex.uv_indices[1]],
    );

    return out;
}

@fragment
fn fragment_main(
    in: VertexOutput
) -> FragmentOutput {
    var out: FragmentOutput;

    let samp: vec4<f32> = textureSample(image_texture, image_sampler, in.uv);
    out.color = in.color * samp.r;

    return out;
}
