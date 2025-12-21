mod camera;
mod grass;
mod renderer;
mod config;

use winit::{
    event::*,
    event_loop::{EventLoop, ControlFlow},
    application::ApplicationHandler,
    dpi::LogicalSize,
};

struct App {
    renderer: Option<renderer::Renderer>,
    window: Option<&'static winit::window::Window>,
}

impl ApplicationHandler for App {
    fn resumed(&mut self, event_loop: &winit::event_loop::ActiveEventLoop) {
        if self.window.is_none() {
            let window_attributes = winit::window::Window::default_attributes()
                .with_title("Procedural Grass")
                .with_inner_size(LogicalSize::new(1280, 720));
            
            let window = event_loop.create_window(window_attributes).unwrap();
            let window = Box::leak(Box::new(window));
            
            let renderer = pollster::block_on(renderer::Renderer::new(window));
            
            self.window = Some(window);
            self.renderer = Some(renderer);
        }
    }

    fn window_event(
        &mut self,
        event_loop: &winit::event_loop::ActiveEventLoop,
        _window_id: winit::window::WindowId,
        event: WindowEvent,
    ) {
        let Some(renderer) = self.renderer.as_mut() else { return };
        let Some(window) = self.window else { return };

        match event {
            WindowEvent::CloseRequested => event_loop.exit(),
            WindowEvent::Resized(new_size) => renderer.resize(new_size),
            WindowEvent::MouseInput { button, state, .. } => {
                renderer.camera_controller_mut().process_mouse_button(button, state);
            }
            WindowEvent::CursorMoved { position, .. } => {
                renderer.camera_controller_mut().process_mouse_move(position);
            }
            WindowEvent::MouseWheel { delta, .. } => {
                renderer.camera_controller_mut().process_scroll(delta);
            }
            WindowEvent::RedrawRequested => {
                renderer.render();
                window.request_redraw();
            }
            _ => {}
        }
    }

    fn about_to_wait(&mut self, _event_loop: &winit::event_loop::ActiveEventLoop) {
        if let Some(window) = self.window {
            window.request_redraw();
        }
    }
}

fn main() {
    env_logger::init();
    
    let event_loop = EventLoop::new().unwrap();
    event_loop.set_control_flow(ControlFlow::Poll);
    
    let mut app = App {
        renderer: None,
        window: None,
    };
    
    event_loop.run_app(&mut app).unwrap();
}