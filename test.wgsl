struct Vert {
    @location(0) position: vec2<f32>,
    @location(1) color: vec3<f32>,
}

struct VertOut {
    @location(0) modulate: vec4<f32>,
}

@vertex
fn vertex(vert: Vert) -> VertOut {
    var out: VertOut;
    
    out.modulate = vec4<f32>(vert.color, 1.0);
    
    return out;
}

@fragment
fn fragment(in: VertOut) -> @location(0) vec4<f32> {
    return vec4<f32>(1.0, 1.0, 1.0, 1.0);
}
