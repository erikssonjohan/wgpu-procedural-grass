pub mod mesh;
pub mod instance;

use wgpu::util::DeviceExt;

pub struct Grass {
    instances: Vec<instance::GrassInstance>,
    instance_buffer: wgpu::Buffer,
}

impl Grass {
    pub fn new(device: &wgpu::Device, count: usize) -> Self {
        let instances = (0..count)
            .map(|_| instance::GrassInstance::new())
            .collect::<Vec<_>>();

        let instance_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Instance Buffer"),
            contents: bytemuck::cast_slice(&instances),
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
        });

        Grass {
            instances,
            instance_buffer,
        }
    }

    pub fn get_instance_buffer(&self) -> &wgpu::Buffer {
        &self.instance_buffer
    }
    
    pub fn instance_count(&self) -> u32 {
        self.instances.len() as u32
    }

    pub fn get_positions(&self) -> &[instance::GrassInstance] {
        &self.instances
    }
}