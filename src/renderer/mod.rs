pub mod pipeline;
pub mod compute;
pub mod depth;

use crate::grass::Grass;
use crate::grass::mesh::GrassMesh;
use crate::camera::Camera;
use crate::camera::controller::CameraController;
use crate::config::{
    GRASS_COUNT, WIND_STRENGTH, SKY_COLOR,
    CAMERA_INITIAL_DISTANCE
};
use wgpu::util::DeviceExt;
use std::time::Instant;

pub struct Renderer {
    surface: wgpu::Surface<'static>,
    device: wgpu::Device,
    queue: wgpu::Queue,
    config: wgpu::SurfaceConfiguration,
    size: winit::dpi::PhysicalSize<u32>,
    
    // Rendering resources
    pipeline: pipeline::Pipeline,
    grass: Grass,
    grass_mesh: GrassMesh,
    depth: depth::DepthTexture,
    
    // Camera
    camera: Camera,
    camera_buffer: wgpu::Buffer,
    camera_controller: CameraController,
    
    // Compute
    compute: compute::ComputeResources,
    
    // Uniforms
    render_bind_group: wgpu::BindGroup,
    wind_uniform_buffer: wgpu::Buffer,
    start_time: Instant,
}

impl Renderer {
    pub async fn new(window: &'static winit::window::Window) -> Self {
        let size = window.inner_size();
        
        // Initialize WGPU
        let (_instance, surface, adapter) = Self::init_wgpu(window).await;
        Self::log_adapter_info(&adapter);
        
        let (device, queue) = adapter
            .request_device(&Default::default())
            .await
            .unwrap();
        
        // Configure surface
        let config = Self::create_surface_config(&surface, &adapter, size);
        surface.configure(&device, &config);

        // Create camera
        let aspect = size.width as f32 / size.height as f32;
        let camera = Camera::new(
            glam::Vec3::new(0.0, 10.0, CAMERA_INITIAL_DISTANCE),
            glam::Vec3::new(0.0, 0.0, 0.0),
            aspect,
        );
        let camera_controller = CameraController::new(CAMERA_INITIAL_DISTANCE, glam::Vec3::ZERO);
        let camera_buffer = Self::create_camera_buffer(&device, &camera);

        // Create uniforms
        let wind_uniform_buffer = Self::create_wind_buffer(&device);

        // Create bind groups
        let render_bind_group_layout = Self::create_render_bind_group_layout(&device);
        let render_bind_group = Self::create_render_bind_group(
            &device,
            &render_bind_group_layout,
            &camera_buffer,
            &wind_uniform_buffer,
        );

        // Create pipeline and grass
        let pipeline = pipeline::Pipeline::new(&device, config.format, &render_bind_group_layout);
        let grass = Grass::new(&device, GRASS_COUNT);
        let grass_mesh = GrassMesh::new(&device);

        // Create compute resources
        let compute = compute::ComputeResources::new(
            &device,
            grass.get_positions(),
            grass.get_instance_buffer(),
            &wind_uniform_buffer,
        );

        // Create depth texture
        let depth = depth::DepthTexture::new(&device, config.width, config.height);

        Self {
            surface,
            device,
            queue,
            config,
            size,
            pipeline,
            grass,
            grass_mesh,
            depth,
            camera,
            camera_buffer,
            camera_controller,
            compute,
            render_bind_group,
            wind_uniform_buffer,
            start_time: Instant::now(),
        }
    }

    async fn init_wgpu(
        window: &'static winit::window::Window,
    ) -> (wgpu::Instance, wgpu::Surface<'static>, wgpu::Adapter) {
        let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor {
            backends: wgpu::Backends::all(),
            ..Default::default()
        });
        
        let surface = instance.create_surface(window).unwrap();
        
        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                compatible_surface: Some(&surface),
                ..Default::default()
            })
            .await
            .unwrap();

        (instance, surface, adapter)
    }

    fn log_adapter_info(adapter: &wgpu::Adapter) {
        let info = adapter.get_info();
        println!("Graphics Backend: {:?}", info.backend);
        println!("Adapter Name: {}", info.name);
        println!("Adapter Type: {:?}", info.device_type);
        println!("Driver: {}", info.driver);
        println!("Driver Info: {}", info.driver_info);
    }

    fn create_surface_config(
        surface: &wgpu::Surface,
        adapter: &wgpu::Adapter,
        size: winit::dpi::PhysicalSize<u32>,
    ) -> wgpu::SurfaceConfiguration {
        let surface_caps = surface.get_capabilities(adapter);
        let surface_format = surface_caps
            .formats
            .iter()
            .copied()
            .find(|f| f.is_srgb())
            .unwrap_or(surface_caps.formats[0]);
        
        wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format: surface_format,
            width: size.width.max(1),
            height: size.height.max(1),
            present_mode: wgpu::PresentMode::Fifo,
            alpha_mode: surface_caps.alpha_modes[0],
            view_formats: vec![],
            desired_maximum_frame_latency: 2,
        }
    }

    fn create_camera_buffer(device: &wgpu::Device, camera: &Camera) -> wgpu::Buffer {
        device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Camera Buffer"),
            contents: bytemuck::cast_slice(camera.build_view_projection_matrix().as_ref()),
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        })
    }

    fn create_wind_buffer(device: &wgpu::Device) -> wgpu::Buffer {
        device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Wind Uniform Buffer"),
            contents: bytemuck::cast_slice(&[WIND_STRENGTH, 0.0_f32, GRASS_COUNT as f32, 0.0_f32]),
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        })
    }

    fn create_render_bind_group_layout(device: &wgpu::Device) -> wgpu::BindGroupLayout {
        device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("Render Bind Group Layout"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::VERTEX,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::VERTEX,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
            ],
        })
    }

    fn create_render_bind_group(
        device: &wgpu::Device,
        layout: &wgpu::BindGroupLayout,
        camera_buffer: &wgpu::Buffer,
        wind_buffer: &wgpu::Buffer,
    ) -> wgpu::BindGroup {
        device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("Render Bind Group"),
            layout,
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: camera_buffer.as_entire_binding(),
                },
                wgpu::BindGroupEntry {
                    binding: 1,
                    resource: wind_buffer.as_entire_binding(),
                },
            ],
        })
    }
    
    pub fn resize(&mut self, new_size: winit::dpi::PhysicalSize<u32>) {
        if new_size.width > 0 && new_size.height > 0 {
            self.size = new_size;
            self.config.width = new_size.width;
            self.config.height = new_size.height;
            self.surface.configure(&self.device, &self.config);
            self.camera.aspect = new_size.width as f32 / new_size.height as f32;
            
            // Recreate depth texture
            self.depth = depth::DepthTexture::new(&self.device, new_size.width, new_size.height);
        }
    }
    
    pub fn camera_controller_mut(&mut self) -> &mut CameraController {
        &mut self.camera_controller
    }

    pub fn render(&mut self) {
        self.update_camera();
        self.update_wind_uniforms();

        let output = self.surface.get_current_texture().unwrap();
        let view = output.texture.create_view(&wgpu::TextureViewDescriptor::default());
        
        let mut encoder = self.device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
            label: Some("Render Encoder"),
        });
        
        self.run_compute_pass(&mut encoder);
        self.run_render_pass(&mut encoder, &view);
        
        self.queue.submit(std::iter::once(encoder.finish()));
        output.present();
    }

    fn update_camera(&mut self) {
        let camera_pos = self.camera_controller.calculate_position();
        self.camera.update_position(camera_pos, self.camera_controller.target);
        
        let camera_matrix = self.camera.build_view_projection_matrix();
        self.queue.write_buffer(
            &self.camera_buffer,
            0,
            bytemuck::cast_slice(camera_matrix.as_ref()),
        );
    }

    fn update_wind_uniforms(&mut self) {
        let elapsed = self.start_time.elapsed().as_secs_f32();
        let wind_data = [
            WIND_STRENGTH,
            elapsed,
            self.grass.instance_count() as f32,
            0.0_f32,
        ];
        self.queue.write_buffer(
            &self.wind_uniform_buffer,
            0,
            bytemuck::cast_slice(&wind_data),
        );
    }

    fn run_compute_pass(&self, encoder: &mut wgpu::CommandEncoder) {
        let mut compute_pass = encoder.begin_compute_pass(&wgpu::ComputePassDescriptor {
            label: Some("Compute Pass"),
            timestamp_writes: None,
        });
        
        compute_pass.set_pipeline(&self.compute.pipeline);
        compute_pass.set_bind_group(0, &self.compute.bind_group, &[]);
        
        let workgroup_count = ((self.grass.instance_count() + 63) / 64) as u32;
        compute_pass.dispatch_workgroups(workgroup_count, 1, 1);
    }

    fn run_render_pass(&self, encoder: &mut wgpu::CommandEncoder, view: &wgpu::TextureView) {
        let mut render_pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
            label: Some("Render Pass"),
            color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                view,
                resolve_target: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Clear(SKY_COLOR),
                    store: wgpu::StoreOp::Store,
                },
                depth_slice: None,
            })],
            depth_stencil_attachment: Some(wgpu::RenderPassDepthStencilAttachment {
                view: &self.depth.view,
                depth_ops: Some(wgpu::Operations {
                    load: wgpu::LoadOp::Clear(1.0),
                    store: wgpu::StoreOp::Store,
                }),
                stencil_ops: None,
            }),
            timestamp_writes: None,
            occlusion_query_set: None,
        });

        render_pass.set_pipeline(&self.pipeline.render_pipeline);
        render_pass.set_bind_group(0, &self.render_bind_group, &[]);
        render_pass.set_vertex_buffer(0, self.grass_mesh.vertex_buffer().slice(..));
        render_pass.set_vertex_buffer(1, self.grass.get_instance_buffer().slice(..));
        render_pass.set_index_buffer(
            self.grass_mesh.index_buffer().slice(..),
            wgpu::IndexFormat::Uint32,
        );
        render_pass.draw_indexed(
            0..self.grass_mesh.num_indices(),
            0,
            0..self.grass.instance_count(),
        );
    }
}