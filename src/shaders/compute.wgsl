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
    instance_count: f32,
    _padding: f32,
}

@group(0) @binding(0) var<storage, read> input_positions: array<GrassInstance>;
@group(0) @binding(1) var<storage, read_write> output_positions: array<GrassInstance>;
@group(0) @binding(2) var<uniform> wind: WindUniforms;

fn hash(p: vec3<f32>) -> f32 {
    let p3 = fract(p * 0.1031);
    let dot_p = dot(p3, vec3<f32>(p3.y + 33.33, p3.z + 33.33, p3.x + 33.33));
    return fract((p3.x + p3.y + p3.z) * dot_p);
}

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let index = global_id.x;
    
    if (f32(index) >= wind.instance_count) {
        return;
    }

    let base_pos = input_positions[index].position;
    
    // Generate unique random values for this blade
    let blade_hash = hash(base_pos);
    let hash2 = hash(base_pos + vec3<f32>(1.0, 2.0, 3.0));
    let hash3 = hash(base_pos + vec3<f32>(4.0, 5.0, 6.0));
    
    // Create wind wave pattern using sine waves
    let wave1 = sin(wind.time * 2.0 + base_pos.x * 0.3 + base_pos.z * 0.3);
    let wave2 = cos(wind.time * 1.5 + base_pos.z * 0.5);
    let combined_wave = wave1 * 0.7 + wave2 * 0.3;
    
    let wind_amount = combined_wave * wind.wind_strength * (0.8 + blade_hash * 0.4);
    
    // Update grass properties
    var grass = input_positions[index];
    grass.position = base_pos;
    grass.wind_sway = wind_amount;
    grass.height = 0.8 + hash2 * 0.4;
    grass.width = 0.9 + hash3 * 0.2;
    grass.bend = 0.5 + blade_hash * 0.5;
    grass.tilt = (hash2 - 0.5) * 0.3;
    
    // Random facing direction
    let facing_angle = blade_hash * 6.28318;
    grass.facing = vec2<f32>(cos(facing_angle), sin(facing_angle));
    
    grass.blade_hash = blade_hash;
    
    output_positions[index] = grass;
}