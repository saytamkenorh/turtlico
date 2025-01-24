use std::collections::HashMap;

use egui::ImageSource;
use emath::{Pos2, Vec2};
use turtlicoscript::{ast::Spanned, parser, tokens::Token};
use turtlicoscript_gui::{app::{ScriptApp, ScriptState, SubApp}, t_log};

use crate::{
    cmdpalette, cmdrenderer::CMD_SIZE_VEC, dndctl::{DnDCtl, DragAction, DragData}, nativedialogs, programview, project::{Command, CommandRange, Project}, widgets::{self, BTN_ICON_SIZE, BTN_ICON_SIZE_VEC, MARGIN_MEDIUM, MARGIN_SMALL}
};

const MODIFIERS_CTRL: egui::Modifiers = egui::Modifiers {
    alt: false,
    ctrl: true,
    shift: false,
    mac_cmd: false,
    command: false,
};
const MODIFIERS_CTRL_SHIFT: egui::Modifiers = egui::Modifiers {
    alt: false,
    ctrl: true,
    shift: true,
    mac_cmd: false,
    command: false,
};

pub struct EditorApp {
    ctx: egui::Context,

    icons: HashMap<String, egui::ImageSource<'static>>,
    dndctl: DnDCtl<EditorDragData>,

    programview_state: programview::ProgramViewState,
    cmdpalette_state: cmdpalette::CmdPaletteState,

    script_subapp: Option<ScriptApp>,
    script_errors: Option<Vec<Spanned<turtlicoscript::error::Error>>>,

    project_autosave_time: chrono::DateTime<chrono::Local>,
    project_path: Option<std::path::PathBuf>,
    project_save_time: chrono::DateTime<chrono::Local>,
    app_errors: Vec<String>,

    save_file_receiver: Option<std::sync::mpsc::Receiver<nativedialogs::SaveFileMsg>>,
    open_file_dialog: Option<Box<dyn nativedialogs::OpenFileDialog>>,
}

pub struct EditorDragData {
    pub commands: Vec<Vec<Command>>,
    pub commands_range: Option<CommandRange>,
    pub project: std::rc::Rc<std::cell::RefCell<Project>>,
    pub action: DragAction,
}
impl DragData for EditorDragData {
    fn get_size(&mut self, painter: &egui::Painter) -> (Vec2, Vec2) {
        (
            self.project
                .borrow()
                .renderer
                .as_ref()
                .unwrap()
                .layout_block(
                    &self.commands,
                    &self.project.borrow(),
                    painter,
                    Pos2::new(0.0, 0.0),
                )
                .0
                .size(),
            CMD_SIZE_VEC * -0.5,
        )
    }
    fn render(&mut self, painter: &egui::Painter, pos: Pos2) {
        self.project
            .borrow()
            .renderer
            .as_ref()
            .unwrap()
            .render_block(&self.commands, &self.project.borrow(), painter, pos, None);
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
    pub fn new(ctx: &egui::Context) -> Self {
        let programview_state = programview::ProgramViewState::new(ctx);
        let cmdpalette_state =
            cmdpalette::CmdPaletteState::new(&programview_state.project.borrow(), ctx);
        let app = Self {
            ctx: ctx.clone(),
            icons: HashMap::new(),
            dndctl: DnDCtl::new(),
            programview_state: programview_state,
            cmdpalette_state: cmdpalette_state,
            script_subapp: None,
            script_errors: None,
            project_autosave_time: chrono::DateTime::<chrono::Local>::MIN_UTC.into(),
            project_path: None,
            project_save_time: chrono::DateTime::<chrono::Local>::MIN_UTC.into(),
            app_errors: vec![],
            save_file_receiver: None,
            open_file_dialog: None,
        };
        turtlicoscript_gui::t_log("EditorApp initialized");
        app
    }

    fn ui(&mut self, ui: &mut egui::Ui, frame: &mut eframe::Frame) {
        if self.icons.len() == 0 {
            self.icons = load_icons();
        }
        let style = ui.style_mut();
        style.spacing.button_padding = Vec2::new(MARGIN_SMALL, MARGIN_SMALL);
        style.spacing.item_spacing = Vec2::new(MARGIN_MEDIUM, MARGIN_MEDIUM);

        ui.vertical(|ui| {
            ui.add_space(MARGIN_SMALL);
            ui.horizontal(|ui| {
                ui.add_space(MARGIN_SMALL);
                ui.set_height(BTN_ICON_SIZE as f32 + MARGIN_SMALL * 2.0);
                // Run
                let run_img = self.icons.get("run").unwrap();
                let run_btn = ui.add(egui::ImageButton::new(run_img.clone()));
                if run_btn.clicked() {
                    self.run();
                }
                // Save
                #[cfg(not(target_arch = "wasm32"))]
                {
                    let save_img = self.icons.get("save").unwrap();
                    let save_btn = ui.add_enabled(
                        self.get_project_modified(),
                        egui::ImageButton::new(save_img.clone()),
                    );
                    if save_btn.clicked()
                        || ui.ctx().input_mut(|i| {
                            i.consume_shortcut(&egui::KeyboardShortcut::new(
                                MODIFIERS_CTRL,
                                egui::Key::S,
                            ))
                        })
                    {
                        self.local_save(false);
                    }
                }
                // Save as
                let save_as_img = self.icons.get("save_as").unwrap();
                let save_as_btn = ui.add(egui::ImageButton::new(save_as_img.clone()));
                if save_as_btn.clicked()
                    || ui.ctx().input_mut(|i| {
                        i.consume_shortcut(&egui::KeyboardShortcut::new(
                            MODIFIERS_CTRL_SHIFT,
                            egui::Key::S,
                        ))
                    })
                {
                    println!("save as");
                    self.local_save(true);
                }

                if let Some(receiver) = &self.save_file_receiver {
                    if let Ok(result) = receiver.try_recv() {
                        match result {
                            nativedialogs::SaveFileMsg::Saved(path) => self.project_path = path,
                            nativedialogs::SaveFileMsg::Canceled => {}
                            nativedialogs::SaveFileMsg::Err(err) => {
                                self.app_errors.push(err.to_string());
                            }
                        }
                        self.save_file_receiver = None;
                    }
                }
                // Load
                let load_img = self.icons.get("load").unwrap();
                let load_btn = ui.add(egui::ImageButton::new(load_img.clone()));
                if load_btn.clicked()
                    || ui.ctx().input_mut(|i| {
                        i.consume_shortcut(&egui::KeyboardShortcut::new(
                            MODIFIERS_CTRL,
                            egui::Key::O,
                        ))
                    })
                {
                    self.local_open();
                }
                if let Some(dialog) = &self.open_file_dialog {
                    if let Ok(result) = dialog.get_receiver().try_recv() {
                        self.app_errors.clear();
                        match result {
                            nativedialogs::OpenFileMsg::Openend(data, path) => {
                                match String::from_utf8(data) {
                                    Ok(data) => match self.load_project_string(&data) {
                                        Ok(_) => {
                                            self.project_path = path;
                                            self.set_project_unmodified();
                                        }
                                        Err(err) => {
                                            self.app_errors
                                                .push(format!("Failed to load the file: {}", err));
                                        }
                                    },
                                    Err(err) => {
                                        self.app_errors
                                            .push(format!("Failed to load the file: {}", err));
                                    }
                                }
                            }
                            nativedialogs::OpenFileMsg::Canceled => {}
                            nativedialogs::OpenFileMsg::Err(err) => {
                                self.app_errors.push(err.to_string());
                            }
                        }
                        self.open_file_dialog = None;
                    }
                }

                ui.with_layout(
                    egui::Layout::centered_and_justified(egui::Direction::RightToLeft),
                    |ui| {
                        ui.add(egui::Label::new(self.project_path.as_ref().map_or(
                            "".to_owned(),
                            |path| {
                                path.file_name().map_or(
                                    "<invalid filename>".to_owned(),
                                    |filename| {
                                        (if self.get_project_modified() { "*" } else { "" })
                                            .to_owned()
                                            + filename.to_str().unwrap_or("<invalid filename>")
                                    },
                                )
                            },
                        )));
                    },
                );
            });
            ui.with_layout(egui::Layout::left_to_right(egui::Align::TOP), |ui| {
                ui.add_space(MARGIN_SMALL);
                ui.add(cmdpalette::cmdpalette(
                    &mut self.cmdpalette_state,
                    self.programview_state.project.clone(),
                    &mut self.dndctl,
                    0.0,
                    true,
                    true,
                    true,
                    true,
                    true,
                ));
                ui.vertical(|ui| {
                    if let Some(errors) = self.script_errors.clone() {
                        let errors = errors
                            .into_iter()
                            .map(|i| i.item.to_string())
                            .collect::<Vec<String>>()
                            .join("\n");
                        widgets::error_frame(
                            ui,
                            &errors,
                            || {
                                self.script_errors = None;
                            },
                            self.icons.get("close").unwrap(),
                        );
                    }
                    for (i, err) in self.app_errors.clone().iter().enumerate() {
                        widgets::error_frame(
                            ui,
                            err,
                            || {
                                self.app_errors.remove(i);
                            },
                            self.icons.get("close").unwrap(),
                        );
                    }
                    ui.add(programview::programview(
                        &mut self.programview_state,
                        &mut self.dndctl,
                        self.cmdpalette_state.edited_tilemap.is_none()
                    ));
                });
            });
        });

        self.dndctl.ui(ui);

        // Auto save
        let modify_time = self.programview_state.project.borrow().modify_timestamp;
        if modify_time > self.project_autosave_time
            && (modify_time + chrono::Duration::seconds(3) < chrono::Local::now())
        {
            self.project_autosave_time = chrono::Local::now();
            if let Some(storage) = frame.storage_mut() {
                self.autosave(storage);
            }
        }
    }

    fn autosave(&self, storage: &mut dyn eframe::Storage) {
        match self.programview_state.project.borrow().save() {
            Ok(str) => {
                t_log("Autosaving...");
                storage.set_string("project_autosave", str);
            }
            Err(_err) => {}
        }
    }

    pub fn autosave_load(&mut self, storage: &dyn eframe::Storage) {
        if let Some(program) = storage.get_string("project_autosave") {
            match self.load_project_string(&program) {
                Ok(_) => {}
                Err(err) => {
                    self.app_errors
                        .push(format!("Autosave load failed: {}", err));
                }
            }
        }
    }

    fn load_project_string(&mut self, input: &str) -> Result<(), serde_json::Error> {
        match self.programview_state.load_project(input, &self.ctx) {
            Ok(_) => {
                t_log("Program loaded");
                Ok(())
            }
            Err(err) => Err(err),
        }
    }

    fn run(&mut self) {
        if self.script_subapp.is_some() {
            return;
        }
        self.script_errors = None;
        let tokens = self
            .programview_state
            .project
            .borrow()
            .program
            .clone()
            .into_iter()
            .flatten()
            .filter_map(|item| match item {
                Command::Token(token) => Some(token),
                _ => None,
            })
            .collect::<Vec<Token>>();
        match parser::parse_tokens(tokens) {
            Ok(ast) => {
                println!("AST: {:?}", ast);
                let subapp = turtlicoscript_gui::app::ScriptApp::spawn(ast, None, true);
                self.script_subapp = Some(subapp);
            }
            Err(errors) => {
                self.script_errors = Some(errors);
            }
        }
    }

    fn local_save(&mut self, save_as: bool) {
        if self.save_file_receiver.is_some() {
            return;
        }
        let save_ok = match self.programview_state.project.borrow().save() {
            Ok(str) => {
                let path = if save_as {
                    None
                } else {
                    self.project_path.to_owned()
                };
                self.save_file_receiver =
                    Some(crate::nativedialogs::save_file(str.into_bytes(), path));
                true
            }
            Err(err) => {
                self.app_errors
                    .push(format!("File serialization failed: {}", err.to_string()));
                false
            }
        };
        if save_ok {
            self.set_project_unmodified();
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

    fn get_project_modified(&self) -> bool {
        if self.project_path.is_none() {
            true
        } else {
            self.programview_state.project.borrow().modify_timestamp != self.project_save_time
        }
    }

    fn set_project_unmodified(&mut self) {
        self.project_save_time = self.programview_state.project.borrow().modify_timestamp;
    }
}

impl SubApp for EditorApp {
    fn update(&mut self, ctx: &egui::Context, frame: &mut eframe::Frame) -> bool {
        egui::CentralPanel::default()
            .frame(egui::Frame {
                inner_margin: 0.0.into(),
                fill: ctx.style().visuals.panel_fill,
                ..Default::default()
            })
            .show(ctx, |ui| {
                self.ui(ui, frame);
            });
        match self.script_subapp.as_mut() {
            Some(code_subapp) => {
                let app_continues = code_subapp.update(ctx, frame);
                if !app_continues {
                    match &*code_subapp.program_state.lock().unwrap() {
                        ScriptState::Error(err) => match err.item {
                            turtlicoscript::error::Error::Interrupted => {}
                            _ => {
                                self.script_errors = Some(vec![err.clone()]);
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

/*fn get_btn_icon_size(ctx: &egui::Context) -> FitTo {
    FitTo::Size(
        (BTN_ICON_SIZE as f32 * ctx.pixels_per_point()) as u32,
        (BTN_ICON_SIZE as f32 * ctx.pixels_per_point()) as u32
    )
}*/

fn load_icons() -> HashMap<String, ImageSource<'static>> {
    let mut map = HashMap::new();
    map.insert(
        "close".to_owned(),
        egui::include_image!("../icons/close.svg"),
    );
    map.insert("run".to_owned(), egui::include_image!("../icons/run.svg"));
    map.insert("save".to_owned(), egui::include_image!("../icons/save.svg"));
    map.insert(
        "save_as".to_owned(),
        egui::include_image!("../icons/save_as.svg"),
    );
    map.insert("load".to_owned(), egui::include_image!("../icons/load.svg"));
    map
}
