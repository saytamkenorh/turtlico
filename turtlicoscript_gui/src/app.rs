use std::{
    sync::{Arc, Mutex},
    thread::JoinHandle,
};

use egui::Color32;
use std::sync::{atomic::AtomicBool, mpsc::channel};
use turtlicoscript::ast::{Expression, Spanned};
use turtlicoscript::interpreter::CancellationToken;
use crate::world::WorldCreationData;

use crate::world::World;

pub trait SubApp {
    // Return true to continue
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) -> bool;

    fn save(&mut self, _storage: &mut dyn eframe::Storage) {}
    fn load(&mut self, _storage: &dyn eframe::Storage) {}
}

pub struct RootApp {
    subapps: Vec<Box<dyn SubApp>>,
}

impl RootApp {
    pub fn new(cc: &eframe::CreationContext<'_>, mut subapps: Vec<Box<dyn SubApp>>) -> Self {
        cc.egui_ctx.set_visuals(egui::Visuals::light());
        if let Some(storage) = cc.storage {
            for app in subapps.iter_mut() {
                app.load(storage);
            }
        }

        Self { subapps: subapps }
    }

    // When compiling natively:
    #[cfg(not(target_arch = "wasm32"))]
    pub fn run<F>(subapps_creator: F)
    where
        F: FnOnce(&egui::Context) -> Vec<Box<dyn SubApp>> + 'static,
    {
        // Log to stdout (if you run with `RUST_LOG=debug`).
        tracing_subscriber::fmt::init();

        let native_options = eframe::NativeOptions {
            viewport: egui::ViewportBuilder::default()
                .with_app_id("io.gitlab.Turtlico")
                .with_decorations(true)
                .with_min_inner_size(egui::vec2(300.0, 220.0)),
            ..Default::default()
        };
        eframe::run_native(
            "Turtlico",
            native_options,
            Box::new(|cc| Ok(Box::new(Self::new(cc, subapps_creator(&cc.egui_ctx))))),
        )
        .expect("failed to start eframe");
    }

    // when compiling to web using trunk.
    #[cfg(target_arch = "wasm32")]
    pub fn run<F>(subapps_creator: F)
    where
        F: FnOnce(&egui::Context) -> Vec<Box<dyn SubApp>> + 'static,
    {
        // Redirect `log` message to `console.log` and friends:
        eframe::WebLogger::init(log::LevelFilter::Debug).ok();

        let web_options = eframe::WebOptions::default();

        wasm_bindgen_futures::spawn_local(async {
            use wasm_bindgen::JsCast;
            let document = web_sys::window()
                .expect("No window")
                .document()
                .expect("No document");

            let canvas = document
                .get_element_by_id("turtlico")
                .expect("Failed to find turtlico canvas")
                .dyn_into::<web_sys::HtmlCanvasElement>()
                .expect("turtlico was not a HtmlCanvasElement");

            eframe::WebRunner::new()
                .start(
                    canvas,
                    web_options,
                    Box::new(|cc| Ok(Box::new(Self::new(cc, subapps_creator(&cc.egui_ctx))))),
                )
                .await
                .expect("failed to start eframe");
        });
    }

    #[cfg(not(target_arch = "wasm32"))]
    fn close(&mut self, _frame: &mut eframe::Frame) {
        self.subapps.clear();
        //frame.close();
    }

    #[cfg(target_arch = "wasm32")]
    fn close(&mut self, _frame: &mut eframe::Frame) {
        self.subapps.clear();
    }
}

impl eframe::App for RootApp {
    fn update(&mut self, ctx: &egui::Context, frame: &mut eframe::Frame) {
        let mut stopped_apps = vec![];
        for (i, subapp) in self.subapps.iter_mut().enumerate() {
            if !subapp.update(ctx, frame) {
                stopped_apps.push(i);
            }
        }
        stopped_apps.reverse();
        for i in stopped_apps {
            self.subapps.remove(i);
        }
        if self.subapps.len() == 0 {
            self.close(frame);
        }
    }

    fn save(&mut self, storage: &mut dyn eframe::Storage) {
        for app in self.subapps.iter_mut() {
            app.save(storage);
        }
    }

    #[cfg(not(target_arch = "wasm32"))]
    fn auto_save_interval(&self) -> std::time::Duration {
        std::time::Duration::from_secs(60 * 10)
    }
}

#[derive(Debug)]
pub enum ScriptState {
    Running,
    Finished,
    Error(Spanned<turtlicoscript::error::Error>),
}

pub struct ScriptApp {
    world: Arc<Mutex<World>>,
    windowed: bool,
    pub pool: Option<web_sys::Worker>,
    pub thread: Option<JoinHandle<()>>,
    pub cancellable: Option<CancellationToken>,
    pub program_state: Arc<Mutex<ScriptState>>,
}

impl ScriptApp {
    pub fn new(world: Arc<Mutex<World>>, windowed: bool) -> Self {
        Self {
            world: world,
            windowed,
            pool: None,
            thread: None,
            cancellable: None,
            program_state: Arc::new(Mutex::new(ScriptState::Running)),
        }
    }

    #[cfg(not(target_arch = "wasm32"))]
    pub fn spawn(
        ast: Spanned<Expression>,
        data: WorldCreationData,
        windowed: bool,
    ) -> ScriptApp {
        let (tx, rx) = channel();
        let world = crate::world::World::new_arc_mutex(tx, data);
        let cancellable = Arc::new(AtomicBool::new(false));

        let mut app = ScriptApp::new(world.clone(), windowed);
        let state = app.program_state.clone();
        app.cancellable = Some(cancellable.clone());

        let handle = std::thread::spawn(move || {
            let mut ctx = turtlicoscript::interpreter::Context::new_parent(Some(cancellable));
            ctx.import_library(crate::init_library(world, rx), false);
            match ctx.eval_root(&ast) {
                Ok(_) => {
                    let mut _state = state.lock().unwrap();
                    *_state = ScriptState::Finished;
                }
                Err(err) => {
                    let mut _state = state.lock().unwrap();
                    *_state = ScriptState::Error(err);
                }
            }
        });

        app.thread = Some(handle);
        app
    }
    #[cfg(target_arch = "wasm32")]
    pub fn spawn(
        ast: Spanned<Expression>,
        data: WorldCreationData,
        windowed: bool,
    ) -> ScriptApp {
        use web_sys::console;
        let (tx, rx) = channel();
        let world = crate::world::World::new_arc_mutex(tx, data);
        let world_clone = world.clone();
        let cancellable = Arc::new(AtomicBool::new(false));

        let mut app = crate::app::ScriptApp::new(world, windowed);
        let state = app.program_state.clone();
        app.cancellable = Some(cancellable.clone());

        console::log_1(&"[worker] Starting sub program".into());
        let worker = crate::worker::spawn(move || {
            console::log_1(&"[worker] Hello from sub program".into());
            let mut ctx = turtlicoscript::interpreter::Context::new_parent(Some(cancellable));
            ctx.import_library(crate::init_library(world_clone, rx), false);
            match ctx.eval_root(&ast) {
                Ok(_result) => {
                    let mut _state = state.lock().unwrap();
                    *_state = ScriptState::Finished;
                }
                Err(err) => {
                    let mut _state = state.lock().unwrap();
                    *_state = ScriptState::Error(err);
                }
            }
        })
        .unwrap();

        app.pool = Some(worker);
        app
    }


    #[cfg(not(target_arch = "wasm32"))]
    fn ui(&mut self, ui: &mut egui::Ui) {
        ui.ctx().request_repaint();
        let mut world = self.world.lock().unwrap();
        world.ui(ui, &self.cancellable);
    }

    #[cfg(target_arch = "wasm32")]
    fn ui(&mut self, ui: &mut egui::Ui) {
        ui.ctx().request_repaint();
        // Yes, this is horrible and it should be done better
        loop {
            if let Ok(mut world) = self.world.try_lock() {
                world.ui(ui, &self.cancellable);
                break;
            }
        }
    }
}

impl SubApp for ScriptApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) -> bool {
        let mut win_open = true;
        if !self.windowed {
            egui::CentralPanel::default()
                .frame(egui::Frame {
                    inner_margin: 0.0.into(),
                    fill: Color32::BLACK,
                    ..Default::default()
                })
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
        if !win_open {
            if let Some(cancellable) = &self.cancellable {
                cancellable.store(true, std::sync::atomic::Ordering::Relaxed);
            }
        }

        let _state = self.program_state.lock().unwrap();
        let script_stopped = !matches!(&*_state, ScriptState::Running);

        return !(script_stopped);
    }
}
