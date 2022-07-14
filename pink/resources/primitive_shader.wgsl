struct Vertex {
    @location(0) position: vec2<f32>,
    @location(1) uv_indices: vec2<u32>,
};

struct Instance {
    @location(2) translation: vec2<f32>,
    @location(3) scale: vec2<f32>,
    @location(4) rotation: f32,
    @location(5) color: vec4<f32>,
};

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) modulation: vec4<f32>,
};

struct FragmentOutput {
	@location(0) color: vec4<f32>,
};

@vertex
fn vertex_main(
    vertex: Vertex,
    instance: Instance,
) -> VertexOutput {
    var out: VertexOutput;
    
    out.modulation = vec4<f32>(
        pk_linear_to_gamma(instance.color.rgb),
        instance.color.a,
    );

    out.position = vec4<f32>(
        pk_transform_2d(
            vertex.position,
            instance.translation,
            instance.scale,
            instance.rotation,
        ),
        1.0,
        1.0,
    ) * pk_render_state.window_to_device;

    return out;
}

@fragment
fn fragment_main(
    in: VertexOutput
) -> FragmentOutput {
    var out: FragmentOutput;

    out.color = in.modulation;

    return out;
}