struct Vert {
    @location(0) position: vec2<f32>,
    @location(1) color: vec3<f32>,
}

struct VertOut {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec3<f32>,
}

@vertex
fn vertex(vert: Vert) -> VertOut {
    var out: VertOut;
    
    out.position = vec4<f32>(vert.position, 1.0, 1.0);
    out.color = vert.color;
    
    return out;
}

@fragment
fn fragment(in: VertOut) -> @location(0) vec4<f32> {
    return vec4<f32>(in.color, 1.0);
}
