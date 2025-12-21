use glam::Vec3;
use winit::event::{ElementState, MouseButton, MouseScrollDelta};
use winit::dpi::PhysicalPosition;
use crate::config::{
    CAMERA_MIN_DISTANCE, CAMERA_MAX_DISTANCE, 
    CAMERA_ROTATION_SPEED, CAMERA_ZOOM_SPEED
};

pub struct CameraController {
    is_left_pressed: bool,
    last_mouse_pos: Option<PhysicalPosition<f64>>,

    // orbit controls
    pub distance: f32,
    pub yaw: f32,   // horizontal angle (radians)
    pub pitch: f32,  // vertical angle (radians)
    pub target: Vec3,

    pub rotation_speed: f32,
    pub zoom_speed: f32,
    pub min_distance: f32,
    pub max_distance: f32,
}

impl CameraController {
    pub fn new(distance: f32, target: Vec3) -> Self {
        Self {
            is_left_pressed: false,
            last_mouse_pos: None,
            distance,
            yaw: 0.0,
            pitch: 0.3,
            target,
            rotation_speed: CAMERA_ROTATION_SPEED,
            zoom_speed: CAMERA_ZOOM_SPEED,
            min_distance: CAMERA_MIN_DISTANCE,
            max_distance: CAMERA_MAX_DISTANCE,
        }
    }

    pub fn process_mouse_button(&mut self, button: MouseButton, state: ElementState) {
        if button == MouseButton::Left {
            self.is_left_pressed = state == ElementState::Pressed;
            if !self.is_left_pressed {
                self.last_mouse_pos = None; // reset last position when released
            }
        }
    }

    pub fn process_mouse_move(&mut self, position: PhysicalPosition<f64>) {
        if self.is_left_pressed {
            if let Some(last_pos) = self.last_mouse_pos {
                let delta_x = (position.x - last_pos.x) as f32;
                let delta_y = (position.y - last_pos.y) as f32;

                self.yaw -= delta_x * self.rotation_speed;
                self.pitch += delta_y * self.rotation_speed;
                // to avoid flipping
                let pitch_limit = std::f32::consts::FRAC_PI_2 - 0.1;
                self.pitch = self.pitch.clamp(-pitch_limit, pitch_limit);
            }
            self.last_mouse_pos = Some(position);
        }
    }

    pub fn process_scroll(&mut self, delta: MouseScrollDelta) {
        let scroll_amount = match delta {
            MouseScrollDelta::LineDelta(_, y) => y,
            MouseScrollDelta::PixelDelta(pos) => pos.y as f32,
        };
        self.distance -= scroll_amount * self.zoom_speed;
        self.distance = self.distance.clamp(self.min_distance, self.max_distance);
    }

    pub fn calculate_position(&self) -> Vec3 {
        // Calculate position based on spherical coordinates
        let x = self.distance * self.pitch.cos() * self.yaw.sin();
        let y = self.distance * self.pitch.sin();
        let z = self.distance * self.pitch.cos() * self.yaw.cos();
        
        self.target + Vec3::new(x, y, z)
    }
}