#[repr(C)]
#[derive(Copy, Clone, Debug, bytemuck::Pod, bytemuck::Zeroable)]
pub struct GrassInstance {
    pub position: [f32; 3],
    pub wind_sway: f32,
    pub height: f32,
    pub width: f32,
    pub bend: f32,
    pub tilt: f32,
    pub facing: [f32; 2],
    pub blade_hash: f32,
    pub _padding: f32,  
}

impl GrassInstance {
    pub fn new() -> Self {
        Self {
            // should maybe be done on the GPU
            position: [
                rand::random::<f32>() * 50.0 - 25.0,
                0.0,
                rand::random::<f32>() * 50.0 - 25.0,
            ],
            wind_sway: 0.0,  
            height: 1.0,     
            width: 1.0,      
            bend: 1.0,       
            tilt: 0.0,       
            facing: [0.0, 0.0], 
            blade_hash: 0.0, 
            _padding: 0.0,
        }
    }

    pub fn vertex_buffer_layout() -> wgpu::VertexBufferLayout<'static> {
        wgpu::VertexBufferLayout {
            array_stride: std::mem::size_of::<GrassInstance>() as wgpu::BufferAddress,
            step_mode: wgpu::VertexStepMode::Instance,
            attributes: &[
                wgpu::VertexAttribute {
                    offset: 0,
                    shader_location: 1,
                    format: wgpu::VertexFormat::Float32x3,
                },
                wgpu::VertexAttribute {
                    offset: 12,
                    shader_location: 2,
                    format: wgpu::VertexFormat::Float32,
                },
                wgpu::VertexAttribute {
                    offset: 16,
                    shader_location: 3,
                    format: wgpu::VertexFormat::Float32,
                },
                wgpu::VertexAttribute {
                    offset: 20,
                    shader_location: 4,
                    format: wgpu::VertexFormat::Float32,
                },
                wgpu::VertexAttribute {
                    offset: 24,
                    shader_location: 5,
                    format: wgpu::VertexFormat::Float32,
                },
                wgpu::VertexAttribute {
                    offset: 28,
                    shader_location: 6,
                    format: wgpu::VertexFormat::Float32,
                },
                wgpu::VertexAttribute {
                    offset: 32,
                    shader_location: 7,
                    format: wgpu::VertexFormat::Float32x2,
                },
                wgpu::VertexAttribute {
                    offset: 40,
                    shader_location: 8,
                    format: wgpu::VertexFormat::Float32,
                },
            ],
        }
    }
}