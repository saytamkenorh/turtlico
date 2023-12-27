use std::collections::HashMap;

use egui_extras::{RetainedImage, image::FitTo};
use emath::{Vec2, Pos2};
use turtlicoscript::{parser, ast::Spanned, tokens::Token};
use turtlicoscript_gui::app::{SubApp, ScriptApp, ScriptState};

use crate::{programview, cmdpalette, dndctl::{DnDCtl, DragData, DragAction}, project::{Command, Project, CommandRange}, cmdrenderer::CMD_SIZE_VEC, nativedialogs, widgets::{self, MARGIN_SMALL, MARGIN_MEDIUM, BTN_ICON_SIZE_VEC, BTN_ICON_SIZE}};

pub struct EditorApp {
    icons: HashMap<String, RetainedImage>,
    dndctl:  DnDCtl<EditorDragData>,

    programview_state: programview::ProgramViewState,
    cmdpalette_state: cmdpalette::CmdPaletteState,

    script_subapp: Option<ScriptApp>,
    script_errors: Option<Vec<Spanned<turtlicoscript::error::Error>>>,

    project_autosave_time: chrono::DateTime<chrono::Local>,
    project_path: Option<std::path::PathBuf>,
    app_errors: Vec<String>,

    save_file_receiver: Option<std::sync::mpsc::Receiver<nativedialogs::SaveFileMsg>>,
    open_file_dialog: Option<Box<dyn nativedialogs::OpenFileDialog>>,
}

pub struct EditorDragData {
    pub commands: Vec<Vec<Command>>,
    pub commands_range: Option<CommandRange>,
    pub project: std::rc::Rc<std::cell::RefCell<Project>>,
    pub action: DragAction

}
impl DragData for EditorDragData {
    fn get_size(&mut self, painter: &egui::Painter) -> (Vec2, Vec2) {
        (
            self.project.borrow().renderer.layout_block(&self.commands, &self.project.borrow(), painter, Pos2::new(0.0, 0.0)).0.size(),
            CMD_SIZE_VEC * -0.5
        )
    }
    fn render(&mut self, painter: &egui::Painter, pos: Pos2) {
        self.project.borrow().renderer.render_block(&self.commands, &self.project.borrow(), painter, pos, None);
    }
    fn drag_finish(&mut self) {
        if self.action == DragAction::MOVE {
            if let Some(range) = self.commands_range {
                self.project.borrow_mut().delete(range);
            }
        }
    }
    fn get_action(&mut self) -> DragAction {
        self.action
    }
}

impl EditorApp {
    pub fn new() -> Self {
        let programview_state = programview::ProgramViewState::new();
        let cmdpalette_state = cmdpalette::CmdPaletteState::new(&programview_state.project.borrow());
        let app = Self {
            icons: HashMap::new(),
            dndctl: DnDCtl::new(),
            programview_state: programview_state,
            cmdpalette_state: cmdpalette_state,
            script_subapp: None,
            script_errors: None,
            project_autosave_time: chrono::DateTime::<chrono::Local>::MIN_UTC.into(),
            project_path: None,
            app_errors: vec![],
            save_file_receiver: None,
            open_file_dialog: None,
        };
        crate::t_log("EditorApp initialized");
        app
    }

    fn ui(&mut self, ui: &mut egui::Ui, frame: &mut eframe::Frame) {
        if self.icons.len() == 0 {
            self.icons = load_icons(ui.ctx());
        }
        let style = ui.style_mut();
        style.spacing.button_padding = Vec2::new(MARGIN_SMALL, MARGIN_SMALL);
        style.spacing.item_spacing = Vec2::new(MARGIN_MEDIUM, MARGIN_MEDIUM);

        ui.vertical(|ui| {
            ui.add_space(MARGIN_SMALL);
            ui.horizontal(|ui| {
                ui.add_space(MARGIN_SMALL);
                // Run
                let run_img = self.icons.get("run").unwrap();
                let run_btn = ui.add(
                    egui::ImageButton::new(run_img.texture_id(ui.ctx()), BTN_ICON_SIZE_VEC));
                if run_btn.clicked() {
                    self.run();
                }
                // Save
                let save_img = self.icons.get("save").unwrap();
                let save_btn = ui.add(
                    egui::ImageButton::new(save_img.texture_id(ui.ctx()), BTN_ICON_SIZE_VEC));
                if save_btn.clicked() {
                    self.local_save();
                }
                if let Some(receiver) = &self.save_file_receiver {
                    if let Ok(result) = receiver.try_recv() {
                        match result {
                            nativedialogs::SaveFileMsg::Saved(path) => {
                                self.project_path = path
                            },
                            nativedialogs::SaveFileMsg::Canceled => {},
                            nativedialogs::SaveFileMsg::Err(err) => {
                                self.app_errors.push(err.to_string());
                            },
                        }
                        self.save_file_receiver = None;
                    }
                }
                // Load
                let load_img = self.icons.get("load").unwrap();
                let load_btn = ui.add(
                    egui::ImageButton::new(load_img.texture_id(ui.ctx()), BTN_ICON_SIZE_VEC));
                if load_btn.clicked() {
                    self.local_open();
                }
                if let Some(dialog) = &self.open_file_dialog {
                    if let Ok(result) = dialog.get_receiver().try_recv() {
                        self.app_errors.clear();
                        match result {
                            nativedialogs::OpenFileMsg::Openend(data) => {
                                match String::from_utf8(data) {
                                    Ok(data) => {
                                        match self.load_project_string(&data) {
                                            Ok(_) => {},
                                            Err(err) => {
                                                self.app_errors.push(format!("Failed to load the file: {}", err));
                                            }
                                        }
                                    },
                                    Err(err) => {
                                        self.app_errors.push(format!("Failed to load the file: {}", err));
                                    }
                                }
                            },
                            nativedialogs::OpenFileMsg::Canceled => {},
                            nativedialogs::OpenFileMsg::Err(err) => {
                                self.app_errors.push(err.to_string());
                            },
                        }
                        self.open_file_dialog = None;
                    }
                }
            });
            ui.with_layout(egui::Layout::left_to_right(egui::Align::TOP), |ui| {
                ui.add_space(MARGIN_SMALL);
                ui.add(
                    cmdpalette::cmdpalette(&mut self.cmdpalette_state, self.programview_state.project.clone(), &mut self.dndctl)
                );
                ui.vertical(|ui| {
                    if let Some(errors) = self.script_errors.clone() {
                        let errors = errors.into_iter().map(|i| i.item.to_string()).collect::<Vec<String>>().join("\n");
                        widgets::error_frame(ui, &errors, || { self.script_errors = None; }, self.icons.get("close").unwrap());
                    }
                    for (i, err) in self.app_errors.clone().iter().enumerate() {
                        widgets::error_frame(ui, err, || { self.app_errors.remove(i); }, self.icons.get("close").unwrap());
                    }
                    ui.add(
                        programview::programview(&mut self.programview_state, &mut self.dndctl)
                    );
                });
            });
        });

        self.dndctl.ui(ui);

        // Auto save
        let modify_time = self.programview_state.project.borrow().modify_timestamp;
        if modify_time > self.project_autosave_time && (modify_time + chrono::Duration::seconds(3) < chrono::Local::now()) {
            self.project_autosave_time = chrono::Local::now();
            if let Some(storage) = frame.storage_mut() {
                self.autosave(storage);
            }
        }
    }

    fn autosave(&self, storage: &mut dyn eframe::Storage) {
        match self.programview_state.project.borrow().save() {
            Ok(str) => {
                crate::t_log("Autosaving...");
                storage.set_string("project_autosave", str);
            },
            Err(_err) => {

            }
        }
    }

    pub fn autosave_load(&mut self, storage: &dyn eframe::Storage) {
        if let Some(program) = storage.get_string("project_autosave") {
            match self.load_project_string(&program) {
                Ok(_) => {},
                Err(err) => {
                    self.app_errors.push(format!("Autosave load failed: {}", err));
                }
            }
        }
    }

    fn load_project_string(&mut self, input: &str) -> Result<(), serde_json::Error> {
        match self.programview_state.load_project(input) {
            Ok(_) => {
                crate::t_log("Program loaded");
                Ok(())
            },
            Err(err) => {
                Err(err)
            }
        }
    }

    fn run(&mut self) {
        if self.script_subapp.is_some() {
            return;
        }
        self.script_errors = None;
        let tokens = self.programview_state.project.borrow().program.clone().into_iter().flatten().filter_map(|item| {
            match item {
                Command::Token(token) => Some(token),
                _ => None
            }
        }).collect::<Vec<Token>>();
        match parser::parse_tokens(tokens) {
            Ok(ast) => {
                let subapp = turtlicoscript_gui::app::ScriptApp::spawn(ast, None, true);
                self.script_subapp = Some(subapp);
            },
            Err(errors) => {
                self.script_errors = Some(errors);
            }
        }
    }

    fn local_save(&mut self) {
        if self.save_file_receiver.is_some() {
            return;
        }
        match self.programview_state.project.borrow().save() {
            Ok(str) => {
                self.save_file_receiver = Some(crate::nativedialogs::save_file(str.into_bytes(), self.project_path.to_owned()));
            },
            Err(err) => {
                self.app_errors.push(format!("File serialization failed: {}", err.to_string()));
            }
        }
    }

    #[cfg(not(target_arch = "wasm32"))]
    fn local_open(&mut self) {
        if self.open_file_dialog.is_some() {
            return;
        }
        self.open_file_dialog = Some(crate::nativedialogs::open_file());
    }
    #[cfg(target_arch = "wasm32")]
    fn local_open(&mut self) {
        self.open_file_dialog = Some(crate::nativedialogs::open_file());
    }
}

impl SubApp for EditorApp {
    fn update(&mut self, ctx: &egui::Context, frame: &mut eframe::Frame) -> bool {
        egui::CentralPanel::default()
            .frame(egui::Frame { inner_margin: 0.0.into(), fill: ctx.style().visuals.panel_fill, ..Default::default()})
            .show(ctx, |ui| {
                self.ui(ui, frame);
            });
        match self.script_subapp.as_mut() {
            Some(code_subapp) => {
                let app_continues = code_subapp.update(ctx, frame);
                if !app_continues {
                    match &*code_subapp.program_state.lock().unwrap() {
                        ScriptState::Error(err) => {
                            match err.item {
                                turtlicoscript::error::Error::Interrupted => {},
                                _ => {
                                    self.script_errors = Some(vec![err.clone()]);
                                }
                            }
                        },
                        _ => {}
                    }
                    self.script_subapp = None;
                }
            }
            _ => (),
        }
        return true;
    }

    fn save(&mut self, storage: &mut dyn eframe::Storage) {
        self.autosave(storage);
    }

    fn load(&mut self, storage: &dyn eframe::Storage) {
        self.autosave_load(storage);
    }
}

fn get_btn_icon_size(ctx: &egui::Context) -> FitTo {
    FitTo::Size(
        (BTN_ICON_SIZE as f32 * ctx.pixels_per_point()) as u32,
        (BTN_ICON_SIZE as f32 * ctx.pixels_per_point()) as u32
    )
}

fn load_icons(ctx: &egui::Context) -> HashMap<String, RetainedImage> {
    let mut map = HashMap::new();
    map.insert("close".to_owned(),
        RetainedImage::from_svg_bytes_with_size("close", include_bytes!("../icons/close.svg"), get_btn_icon_size(ctx)).unwrap());
    map.insert("run".to_owned(),
        RetainedImage::from_svg_bytes_with_size("run", include_bytes!("../icons/run.svg"), get_btn_icon_size(ctx)).unwrap());
    map.insert("save".to_owned(),
        RetainedImage::from_svg_bytes_with_size("run", include_bytes!("../icons/save.svg"), get_btn_icon_size(ctx)).unwrap());
    map.insert("load".to_owned(),
        RetainedImage::from_svg_bytes_with_size("run", include_bytes!("../icons/load.svg"), get_btn_icon_size(ctx)).unwrap());
    map
}