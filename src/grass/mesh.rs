use wgpu::util::DeviceExt;
use crate::config::{BLADE_SEGMENTS, BLADE_WIDTH};

pub struct GrassMesh {
    vertex_buffer: wgpu::Buffer,
    index_buffer: wgpu::Buffer,
    num_indices: u32,
}

impl GrassMesh {
    pub fn new(device: &wgpu::Device) -> Self {
        // create normalized mesh from 0 to 1
        // the height is applied in the shader
        let segment_height = 1.0 / BLADE_SEGMENTS as f32;
        
        let mut vertices = Vec::new();
        let mut indices = Vec::new();
        
        for i in 0..=BLADE_SEGMENTS {
            let y = i as f32 * segment_height;  // 0.0 to 1.0
            let t = i as f32 / BLADE_SEGMENTS as f32;
            let taper = 1.0 - t * 0.7;
            
            vertices.push(-BLADE_WIDTH * taper);
            vertices.push(y);
            vertices.push(0.0);
            
            vertices.push(BLADE_WIDTH * taper);
            vertices.push(y);
            vertices.push(0.0);
        }
        
        for i in 0..BLADE_SEGMENTS {
            let base = (i * 2) as u32;
            
            indices.push(base);
            indices.push(base + 2);
            indices.push(base + 1);
            
            indices.push(base + 1);
            indices.push(base + 2);
            indices.push(base + 3);
        }

        let vertex_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Grass Vertex Buffer"),
            contents: bytemuck::cast_slice(&vertices),
            usage: wgpu::BufferUsages::VERTEX,
        });

        let index_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Grass Index Buffer"),
            contents: bytemuck::cast_slice(&indices),
            usage: wgpu::BufferUsages::INDEX,
        });

        Self {
            vertex_buffer,
            index_buffer,
            num_indices: indices.len() as u32,
        }
    }

    pub fn vertex_buffer(&self) -> &wgpu::Buffer {
        &self.vertex_buffer
    }

    pub fn index_buffer(&self) -> &wgpu::Buffer {
        &self.index_buffer
    }

    pub fn num_indices(&self) -> u32 {
        self.num_indices
    }
}