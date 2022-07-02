struct VertexInput {
    @location(0) position: vec2<f32>,
};

struct InstanceInput {
    @location(1) translation: vec2<f32>,
    @location(2) scale: vec2<f32>,
    @location(3) rotation: f32,
    @location(4) modulation: vec4<f32>,
};

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) modulation: vec4<f32>,
};

// http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html
fn linear_to_gamma(color: vec3<f32>) -> vec3<f32> {
    return color * (color * (color * 0.305306011 + 0.682171111) + 0.012522878);
};

@stage(vertex)
fn vertex_main(
    vertex: VertexInput,
    instance: InstanceInput,
) -> VertexOutput {
    var out: VertexOutput;
    out.modulation = vec4<f32>(linear_to_gamma(instance.modulation.rgb), instance.modulation.a);
    out.position = vec4<f32>(
        (vertex.position * instance.scale) + instance.translation,
        1.0,
        1.0
    );
    return out;
}

@stage(fragment)
fn fragment_main(
    in: VertexOutput
) -> @location(0) vec4<f32> {
    return in.modulation;
}
