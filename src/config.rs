use std::f32::consts::PI;

/// Number of grass blade instances to render
pub const GRASS_COUNT: usize = 64* 1024;

/// Number of segments per grass blade (more = smoother bending)
pub const BLADE_SEGMENTS: u32 = 6;

/// Base width of grass blades
pub const BLADE_WIDTH: f32 = 0.08;

/// Base height of grass blades
pub const BLADE_HEIGHT: f32 = 1.0;

/// Wind strength multiplier
pub const WIND_STRENGTH: f32 = 0.8;

/// Wind direction in radians
pub const WIND_ANGLE: f32 = 0.0;

/// Camera settings
pub const CAMERA_INITIAL_DISTANCE: f32 = 25.0;
pub const CAMERA_MIN_DISTANCE: f32 = 5.0;
pub const CAMERA_MAX_DISTANCE: f32 = 100.0;
pub const CAMERA_ROTATION_SPEED: f32 = 0.005;
pub const CAMERA_ZOOM_SPEED: f32 = 2.0;

/// Sky color
pub const SKY_COLOR: wgpu::Color = wgpu::Color {
    r: 0.53,
    g: 0.81,
    b: 0.92,
    a: 1.0,
};