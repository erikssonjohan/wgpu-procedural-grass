// Uniforms
@group(0) @binding(0)
var<uniform> view_proj: mat4x4<f32>;

@group(0) @binding(1)
var<uniform> wind_data: vec4<f32>;

@group(0) @binding(2)
var<uniform> camera_pos: vec3<f32>;

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
    @location(2) normal: vec3<f32>,
    @location(3) world_pos: vec3<f32>,
}

// Todo:
// tweek parameters for bend and sway to get a more natural look 
// add shaping to the grass blades (wider at base, tapering to tip)
// add texture suport

fn bezier(p0: vec3<f32>, p1: vec3<f32>, p2: vec3<f32>, p3: vec3<f32>, t: f32) -> vec3<f32> {
    let one_minus_t = 1.0 - t;
    let one_minus_t_sq = one_minus_t * one_minus_t;
    let t_sq = t * t;
    
    return one_minus_t_sq * one_minus_t * p0 + 
           3.0 * one_minus_t_sq * t * p1 + 
           3.0 * one_minus_t * t_sq * p2 + 
           t_sq * t * p3;
}

fn bezier_grad(p0: vec3<f32>, p1: vec3<f32>, p2: vec3<f32>, p3: vec3<f32>, t: f32) -> vec3<f32> {
    let one_minus_t = 1.0 - t;
    return 3.0 * one_minus_t * one_minus_t * (p1 - p0) +
           6.0 * one_minus_t * t * (p2 - p1) +
           3.0 * t * t * (p3 - p2);
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

fn inverse_lerp(v: f32, min_value: f32, max_value: f32) -> f32 {
    return (v - min_value) / (max_value - min_value);
}

fn remap(v: f32, in_min: f32, in_max: f32, out_min: f32, out_max: f32) -> f32 {
    let t = inverse_lerp(v, in_min, in_max);
    return mix(out_min, out_max, t);
}

fn saturate(x: f32) -> f32 {
    return clamp(x, 0.0, 1.0);
}

fn ease_out(x: f32, t: f32) -> f32 {
    return 1.0 - pow(1.0 - x, t);
}

fn hemi_light(normal: vec3<f32>, ground_colour: vec3<f32>, sky_colour: vec3<f32>) -> vec3<f32> {
    return mix(ground_colour, sky_colour, 0.5 * normal.y + 0.5);
}

fn lambert_light(normal: vec3<f32>, view_dir: vec3<f32>, light_dir: vec3<f32>, light_colour: vec3<f32>) -> vec3<f32> {
    let wrap = 0.8;
    let dot_nl = saturate((dot(normal, light_dir) + wrap) / (wrap + 1.0));
    var lighting = vec3<f32>(dot_nl);
    
    let backlight = saturate((dot(view_dir, light_dir) + wrap) / (wrap + 1.0));
    let scatter = vec3<f32>(pow(backlight, 2.0));
    
    lighting += scatter;
    return lighting * light_colour;
}

fn phong_specular(normal: vec3<f32>, light_dir: vec3<f32>, view_dir: vec3<f32>) -> vec3<f32> {
    let dot_nl = saturate(dot(normal, light_dir));
    let r = normalize(reflect(-light_dir, normal));
    var phong_value = max(0.0, dot(view_dir, r));
    phong_value = pow(phong_value, 32.0);
    
    let specular = dot_nl * vec3<f32>(phong_value);
    return specular;
}

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    
     // Determine which side of blade
    let x_side = sign(in.position.x);
    
    var scaled_pos = in.position;
    scaled_pos.y *= in.height;
    
    let height_factor = in.position.y;
    
    // sa bit of grass blade shaping
    let final_width =ease_out(1.0 - height_factor, 6.0);
    scaled_pos.x *= in.width * final_width;

    
    let wind_angle = wind_data.z;
    let wind_axis = vec3<f32>(cos(wind_angle + 1.5708), 0.0, sin(wind_angle + 1.5708));
    
    let lean_factor = in.wind_sway;
    let wind_lean_angle = lean_factor * 1.5 * height_factor * in.bend;
    
    let p0 = vec3<f32>(0.0, 0.0, 0.0);
    let p1 = vec3<f32>(0.0, 0.33, 0.0);
    let p2 = vec3<f32>(0.0, 0.66, 0.0);
    let p3 = vec3<f32>(0.0, cos(lean_factor), sin(lean_factor));
    
    let curve = bezier(p0, p1, p2, p3, height_factor);
    let curve_grad = bezier_grad(p0, p1, p2, p3, height_factor);
    
    scaled_pos.y = curve.y * in.height;
    scaled_pos.z = curve.z * in.height;
    
    scaled_pos.x += in.tilt * scaled_pos.y;
    
    let facing_angle = atan2(in.facing.y, in.facing.x);
    let grass_mat = rotate_axis(wind_axis, wind_lean_angle) * rotate_y(facing_angle);
    let grass_local_pos = grass_mat * scaled_pos;
    
    let tangent = normalize(grass_mat * (curve_grad * in.height));
    let blade_right = grass_mat * vec3<f32>(1.0, 0.0, 0.0);
    let grass_normal = normalize(cross(tangent, blade_right));
    
    let world_pos = grass_local_pos + in.instance_pos;
    
    // View-space thickening
    let view_dir = normalize(camera_pos - world_pos);
    let grass_face_normal = grass_mat * vec3<f32>(0.0, 0.0, -1.0);
    
    let view_dot_normal = abs(dot(grass_face_normal, view_dir));
    let view_space_thicken_factor = ease_out(1.0 - view_dot_normal, 4.0) * smoothstep(0.0, 0.05, view_dot_normal);
    
    let THICKEN_ENABLED = 1.0;
    let THICKEN_AMOUNT = 0.04;
    
    var thickened_pos = world_pos;
    thickened_pos += blade_right * view_space_thicken_factor * x_side * in.width * final_width * THICKEN_AMOUNT * THICKEN_ENABLED;
    
    out.clip_position = view_proj * vec4<f32>(thickened_pos, 1.0);
    
    out.height_factor = height_factor;
    out.blade_hash = in.blade_hash;
    out.normal = grass_normal;
    out.world_pos = world_pos;
    
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let view_dir = normalize(camera_pos - in.world_pos);
    let light_dir = normalize(vec3<f32>(-1.0, 0.5, 1.0));
    let light_color = vec3<f32>(1.0, 1.0, 0.9);
    
    // Flip normal for back-facing fragments (two-sided lighting)
    var normal = normalize(in.normal);
    if (dot(normal, view_dir) < 0.0) {
        normal = -normal;
    }
    
    let color_variation = in.blade_hash * 0.1;
    //let brightness = in.height_factor * 0.4 + 0.6;

    let c1 = vec3<f32>(1.0, 1.0, 0.5);
    let c2 = vec3<f32>(0.05, 0.05, 0.25);

    let ambient_light = hemi_light(normal, c2, c1);
    let diffuse_light = lambert_light(normal, view_dir, light_dir, light_color);
    let specular = phong_specular(normal, light_dir, view_dir);
    let lighting = ambient_light * 0.6 + diffuse_light * 0.4;
    //let base_color = vec3<f32>(0.1, 0.5, 0.2);
    
    let base_color = vec3<f32>(
        0.3 + color_variation,
        0.8 - color_variation * 0.5,
        0.3 + color_variation * 0.3
    );

    // fake grass AO
    let ao = remap(pow(in.height_factor, 2.0), 0.0, 1.0, 0.25, 1.0);
    
    var final_color = base_color * lighting + specular * 0.125;
    final_color *= ao;

    let normal_color = normalize(in.normal) * 0.5 + 0.5;
    return vec4<f32>(final_color, 1.0);
}