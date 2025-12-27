struct GrassInstance {
    position: vec3<f32>,
    wind_sway: f32,
    height: f32,
    width: f32,
    bend: f32,
    tilt: f32,
    facing: vec2<f32>,
    blade_hash: f32,
}

struct WindUniforms {
    wind_strength: f32,
    time: f32,
    wind_angle: f32,
    instance_count: f32,
}

@group(0) @binding(0) var<storage, read> input_positions: array<GrassInstance>;
@group(0) @binding(1) var<storage, read_write> output_positions: array<GrassInstance>;
@group(0) @binding(2) var<uniform> wind: WindUniforms;

fn hash(p: vec3<f32>) -> f32 {
    let p3 = fract(p * 0.1031);
    let dot_p = dot(p3, vec3<f32>(p3.y + 33.33, p3.z + 33.33, p3.x + 33.33));
    return fract((p3.x + p3.y + p3.z) * dot_p);
}

fn hash3(p: vec3<f32>) -> vec3<f32> {
    let p3 = vec3<f32>(
        dot(p, vec3<f32>(127.1, 311.7, 74.7)),
        dot(p, vec3<f32>(269.5, 183.3, 246.1)),
        dot(p, vec3<f32>(113.5, 271.9, 124.6))
    );
    return -1.0 + 2.0 * fract(sin(p3) * 43758.5453123);
}

// 3D Perlin-style noise
fn noise(p: vec3<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    
    let u = f * f * (3.0 - 2.0 * f);
    
    return mix(
        mix(
            mix(
                dot(hash3(i + vec3<f32>(0.0, 0.0, 0.0)), f - vec3<f32>(0.0, 0.0, 0.0)),
                dot(hash3(i + vec3<f32>(1.0, 0.0, 0.0)), f - vec3<f32>(1.0, 0.0, 0.0)),
                u.x
            ),
            mix(
                dot(hash3(i + vec3<f32>(0.0, 1.0, 0.0)), f - vec3<f32>(0.0, 1.0, 0.0)),
                dot(hash3(i + vec3<f32>(1.0, 1.0, 0.0)), f - vec3<f32>(1.0, 1.0, 0.0)),
                u.x
            ),
            u.y
        ),
        mix(
            mix(
                dot(hash3(i + vec3<f32>(0.0, 0.0, 1.0)), f - vec3<f32>(0.0, 0.0, 1.0)),
                dot(hash3(i + vec3<f32>(1.0, 0.0, 1.0)), f - vec3<f32>(1.0, 0.0, 1.0)),
                u.x
            ),
            mix(
                dot(hash3(i + vec3<f32>(0.0, 1.0, 1.0)), f - vec3<f32>(0.0, 1.0, 1.0)),
                dot(hash3(i + vec3<f32>(1.0, 1.0, 1.0)), f - vec3<f32>(1.0, 1.0, 1.0)),
                u.x
            ),
            u.y
        ),
        u.z
    );
}

fn remap(value: f32, in_min: f32, in_max: f32, out_min: f32, out_max: f32) -> f32 {
    return out_min + (value - in_min) * (out_max - out_min) / (in_max - in_min);
}

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let index = global_id.x;
    
    if (f32(index) >= wind.instance_count) {
        return;
    }

    let base_pos = input_positions[index].position;
    
    let blade_hash = hash(base_pos);
    let hash2 = hash(base_pos + vec3<f32>(1.0, 2.0, 3.0));
    let hash3 = hash(base_pos + vec3<f32>(4.0, 5.0, 6.0));
    
    let wind_dir = normalize(vec3<f32>(cos(wind.wind_angle), 0.0, sin(wind.wind_angle)));
    
    // Large-scale wave pattern moving along wind direction
    let wind_sample_pos = vec3<f32>(
        base_pos.x * 0.05 + wind.time * wind_dir.x * 1.0,
        0.0,
        base_pos.z * 0.05 + wind.time * wind_dir.z * 1.0
    );
    let wind_strength = noise(wind_sample_pos)*0.8;
    
    // Add secondary wave
    let wave2_pos = vec3<f32>(
        base_pos.x * 0.08 - wind.time * wind_dir.x * 0.8,
        0.0,
        base_pos.z * 0.08 - wind.time * wind_dir.z * 0.8
    );
    let wave2 = noise(wave2_pos) * 0.5;
    
    // Combine waves
    let combined_wind = wind_strength * 1.0;// + wave2;
    
    // Faster turbulence
    let animation_sample_pos = vec3<f32>(base_pos.x, base_pos.z, wind.time * 2.5);
    let random_lean_animation = noise(animation_sample_pos) * (wind_strength * 0.6 + 0.125);
    
    let base_lean = remap(hash2, -0.0, 1.0, -0.2, 0.2);
    
    // Combine all factors for wavy motion
    let lean_factor = combined_wind + random_lean_animation;// + base_lean;
    let wind_amount = lean_factor * wind.wind_strength;
    
    var grass = input_positions[index];
    grass.position = base_pos;
    grass.wind_sway = wind_amount;
    grass.height = 0.8 + hash2 * 0.4;
    grass.width = 0.9 + hash3 * 0.2;
    grass.bend = 1.2 + blade_hash * 0.5;
    grass.tilt = base_lean;
    
    let facing_angle = blade_hash * 6.28318;
    grass.facing = vec2<f32>(cos(facing_angle), sin(facing_angle));
    
    grass.blade_hash = blade_hash;
    
    output_positions[index] = grass;
}