// Uniforms
@group(0) @binding(0)
var<uniform> view_proj: mat4x4<f32>;

@group(0) @binding(1)
var<uniform> wind_data: vec4<f32>;

// Vertex input from mesh and instance data
struct VertexInput {
    // Mesh vertex data
    @location(0) position: vec3<f32>,
    
    // Instance data
    @location(1) instance_pos: vec3<f32>,
    @location(2) wind_sway: f32,
    @location(3) height: f32,
    @location(4) width: f32,
    @location(5) bend: f32,
    @location(6) tilt: f32,
    @location(7) facing: vec2<f32>,
    @location(8) blade_hash: f32,
}

struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) height_factor: f32,
    @location(1) blade_hash: f32,
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    
    var scaled_pos = in.position;
    scaled_pos.y *= in.height;
    scaled_pos.x *= in.width;
    
    // Height factor (0.0 - 1.0)
    let height_factor = in.position.y;
    
    // Rotate blade to face random direction
    let facing_angle = atan2(in.facing.y, in.facing.x);
    let cos_facing = cos(facing_angle);
    let sin_facing = sin(facing_angle);
    let rotated_x = scaled_pos.x * cos_facing - scaled_pos.z * sin_facing;
    let rotated_z = scaled_pos.x * sin_facing + scaled_pos.z * cos_facing;
    scaled_pos.x = rotated_x;
    scaled_pos.z = rotated_z;
    
    // Apply wind bend
    let bend_amount = height_factor * height_factor;
    scaled_pos.x += in.wind_sway * in.bend * bend_amount;
    
    // Apply "static" tilt
    scaled_pos.x += in.tilt * scaled_pos.y;
    
    // Transform to world space
    let world_pos = scaled_pos + in.instance_pos;
    out.clip_position = view_proj * vec4<f32>(world_pos, 1.0);
    
    out.height_factor = height_factor;
    out.blade_hash = in.blade_hash;
    
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let color_variation = in.blade_hash * 0.1;
    
    // Gradiente 
    let brightness = in.height_factor * 0.4 + 0.6;
    
    let base_color = vec3<f32>(
        0.2 + color_variation,
        0.7 - color_variation * 0.5,
        0.3 + color_variation * 0.3
    );
    
    let final_color = base_color * brightness;

    return vec4<f32>(final_color, 1.0);
}