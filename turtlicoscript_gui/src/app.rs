use std::{sync::{Arc, Mutex}, thread::JoinHandle};

use crate::world::World;

pub trait SubApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) -> bool;
}

pub struct RootApp {
    subapps: Vec<Box<dyn SubApp>>
}

impl RootApp {
    pub fn new(cc: &eframe::CreationContext<'_>, subapps: Vec<Box<dyn SubApp>>) -> Self {
        cc.egui_ctx.set_visuals(egui::Visuals::light());

        Self {
            subapps: subapps
        }
    }

    // When compiling natively:
    #[cfg(not(target_arch = "wasm32"))]
    pub fn run(subapps: Vec<Box<dyn SubApp>>) {
        // Log to stdout (if you run with `RUST_LOG=debug`).
        tracing_subscriber::fmt::init();

        let mut native_options = eframe::NativeOptions::default();
        native_options.decorated = true;
        native_options.app_id = Some("io.gitlab.Turtlico".to_owned());
        eframe::run_native(
            "Turtlico",
            native_options,
            Box::new(|cc| Box::new(Self::new(cc, subapps))),
        ).expect("failed to start eframe");
    }

    // when compiling to web using trunk.
    #[cfg(target_arch = "wasm32")]
    pub fn run(subapps: Vec<Box<dyn SubApp>>) {
        // Redirect `log` message to `console.log` and friends:
        eframe::WebLogger::init(log::LevelFilter::Debug).ok();

        let web_options = eframe::WebOptions::default();

        wasm_bindgen_futures::spawn_local(async {
            eframe::WebRunner::new()
                .start(
                    "turtlico",
                    web_options,
                    Box::new(|cc| Box::new(Self::new(cc, subapps))),
                )
                .await
                .expect("failed to start eframe");
        });
    }
}

impl eframe::App for RootApp {
    fn update(&mut self, ctx: &egui::Context, frame: &mut eframe::Frame) {
        for subapp in self.subapps.iter_mut() {
            subapp.update(ctx, frame);
        }
    }
}

pub struct ScriptApp {
    world: Arc<Mutex<World>>,
    windowed: bool,
    pub pool: Option<web_sys::Worker>,
}

impl ScriptApp{
    pub fn new(world: Arc<Mutex<World>>, windowed: bool) -> Self {
        Self {
            world: world,
            windowed,
            pool: None
        }
    }

    fn ui(&mut self, ui: &mut egui::Ui) {
        let mut world = self.world.lock().unwrap();
        world.ui(ui);
    }
}

impl SubApp for ScriptApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) -> bool {
        let mut win_open = true;
        if !self.windowed {
            egui::CentralPanel::default()
                .frame(egui::Frame { inner_margin: 0.0.into(), fill: ctx.style().visuals.panel_fill, ..Default::default()})
                .show(ctx, |ui| {
                    self.ui(ui);
                });
        } else {
            egui::Window::new("Turtlico program")
                .collapsible(false)
                .open(&mut win_open)
                .show(ctx, |ui| {
                    self.ui(ui);
                });
        }
        let program_stopped;
        {
            let world = self.world.lock().unwrap();
            program_stopped = world.update_tx_closed;
        }

        return !(program_stopped && !win_open);
    }
}