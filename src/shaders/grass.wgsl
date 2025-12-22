// Uniforms
@group(0) @binding(0)
var<uniform> view_proj: mat4x4<f32>;

@group(0) @binding(1)
var<uniform> wind_data: vec4<f32>; // (wind_strength, time, wind_angle, instance_count)

struct VertexInput {
    @location(0) position: vec3<f32>,
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

// Todo:
// calculate new normal with bezier gradient
// add add view-space thickening to make the grass feel a bit thicker from som angles
// tweek parameters for bend and sway to get a more natural look 

fn bezier(p0: vec3<f32>, p1: vec3<f32>, p2: vec3<f32>, p3: vec3<f32>, t: f32) -> vec3<f32> {
    let one_minus_t = 1.0 - t;
    let one_minus_t_sq = one_minus_t * one_minus_t;
    let t_sq = t * t;
    
    return one_minus_t_sq * one_minus_t * p0 + 
           3.0 * one_minus_t_sq * t * p1 + 
           3.0 * one_minus_t * t_sq * p2 + 
           t_sq * t * p3;
}

fn rotate_y(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(c, 0.0, s),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-s, 0.0, c)
    );
}

fn rotate_axis(axis: vec3<f32>, angle: f32) -> mat3x3<f32> {
    let s = sin(angle);
    let c = cos(angle);
    let oc = 1.0 - c;
    
    return mat3x3<f32>(
        vec3<f32>(
            oc * axis.x * axis.x + c,
            oc * axis.x * axis.y + axis.z * s,
            oc * axis.z * axis.x - axis.y * s
        ),
        vec3<f32>(
            oc * axis.x * axis.y - axis.z * s,
            oc * axis.y * axis.y + c,
            oc * axis.y * axis.z + axis.x * s
        ),
        vec3<f32>(
            oc * axis.z * axis.x + axis.y * s,
            oc * axis.y * axis.z - axis.x * s,
            oc * axis.z * axis.z + c
        )
    );
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    
    var scaled_pos = in.position;
    scaled_pos.y *= in.height;
    scaled_pos.x *= in.width;
    
    let height_factor = in.position.y;
    
    let wind_angle = wind_data.z;
    let wind_axis = vec3<f32>(cos(wind_angle + 1.5708), 0.0, sin(wind_angle + 1.5708)); 

    let lean_factor = in.wind_sway;
    let wind_lean_angle = lean_factor * 1.5 * height_factor * in.bend;
    
    let p0 = vec3<f32>(0.0, 0.0, 0.0);
    let p1 = vec3<f32>(0.0, 0.33, 0.0);
    let p2 = vec3<f32>(0.0, 0.66, 0.0);
    let p3 = vec3<f32>(0.0, cos(lean_factor), sin(lean_factor));
    
    let curve = bezier(p0, p1, p2, p3, height_factor);
    
    scaled_pos.y = curve.y * in.height;
    scaled_pos.z = curve.z * in.height;
    
    scaled_pos.x += in.tilt * scaled_pos.y;
    
    let facing_angle = atan2(in.facing.y, in.facing.x);
    let grass_mat = rotate_axis(wind_axis, wind_lean_angle) * rotate_y(facing_angle);
    let grass_local_pos = grass_mat * scaled_pos;
    
    let world_pos = grass_local_pos + in.instance_pos;
    out.clip_position = view_proj * vec4<f32>(world_pos, 1.0);
    
    out.height_factor = height_factor;
    out.blade_hash = in.blade_hash;
    
    return out;
}

// need to fix shading 
@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let color_variation = in.blade_hash * 0.1;
    let brightness = in.height_factor * 0.4 + 0.6;
    
    let base_color = vec3<f32>(
        0.2 + color_variation,
        0.7 - color_variation * 0.5,
        0.3 + color_variation * 0.3
    );
    
    let final_color = base_color * brightness;

    return vec4<f32>(final_color, 1.0);
}