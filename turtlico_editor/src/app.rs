use std::collections::HashMap;

use egui_extras::{RetainedImage, image::FitTo};
use emath::{Vec2, Pos2};
use turtlicoscript::{parser, ast::Spanned, tokens::Token};
use turtlicoscript_gui::app::{SubApp, ScriptApp, ScriptState};

use crate::{programview, cmdpalette, dndctl::{DnDCtl, DragData, DragAction}, project::{Command, Project, CommandRange}, cmdrenderer::CMD_SIZE_VEC};

pub const BTN_ICON_SIZE: u32 = 22;
pub const BTN_ICON_SIZE_VEC: Vec2 = Vec2::new(BTN_ICON_SIZE as f32, BTN_ICON_SIZE as f32);
pub const MARGIN_SMALL: f32 = 4.0;
pub const MARGIN_MEDIUM: f32 = 8.0;
pub const COLOR_ERROR: egui::Color32 = egui::Color32::from_rgb(255, 200, 200);

pub struct EditorApp {
    icons: HashMap<String, RetainedImage>,
    dndctl:  DnDCtl<EditorDragData>,

    programview_state: programview::ProgramViewState,
    cmdpalette_state: cmdpalette::CmdPaletteState,

    script_subapp: Option<ScriptApp>,
    script_errors: Option<Vec<Spanned<turtlicoscript::error::Error>>>,
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
        };
        crate::t_log("EditorApp initialized");
        app
    }

    fn ui(&mut self, ui: &mut egui::Ui) {
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
                let run_img = self.icons.get("run").unwrap();
                let run_btn = ui.add(
                    egui::ImageButton::new(run_img.texture_id(ui.ctx()), BTN_ICON_SIZE_VEC));
                if run_btn.clicked() {
                    self.run();
                }
            });
            ui.with_layout(egui::Layout::left_to_right(egui::Align::TOP), |ui| {
                ui.add_space(MARGIN_SMALL);
                ui.add(
                    cmdpalette::cmdpalette(&mut self.cmdpalette_state, self.programview_state.project.clone(), &mut self.dndctl)
                );
                ui.vertical(|ui| {
                    if let Some(erros) = self.script_errors.clone() {
                        egui::Frame::group(ui.style())
                            .fill(COLOR_ERROR)
                            .show(ui, |ui| {
                                ui.set_width(ui.available_width() - MARGIN_MEDIUM);
                                ui.with_layout(egui::Layout::right_to_left(emath::Align::Min), |ui| {
                                    let close_img = self.icons.get("close").unwrap();
                                    let btn = ui.add(egui::ImageButton::new(close_img.texture_id(ui.ctx()), Vec2::new(BTN_ICON_SIZE as f32, BTN_ICON_SIZE as f32)));
                                    if btn.clicked() {
                                        self.script_errors = None;
                                    }
                                    ui.with_layout(egui::Layout::top_down(emath::Align::Min), |ui| {
                                        let text = erros.into_iter().map(|err| err.item.to_string()).collect::<Vec<String>>().join("\n");
                                        ui.add(egui::Label::new(text).wrap(true));
                                    });
                                });
                        });
                    }
                    ui.add(
                        programview::programview(&mut self.programview_state, &mut self.dndctl)
                    );
                });
            });
        });

        self.dndctl.ui(ui);
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
}

impl SubApp for EditorApp {
    fn update(&mut self, ctx: &egui::Context, frame: &mut eframe::Frame) -> bool {
        egui::CentralPanel::default()
            .frame(egui::Frame { inner_margin: 0.0.into(), fill: ctx.style().visuals.panel_fill, ..Default::default()})
            .show(ctx, |ui| {
                self.ui(ui);
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
}

fn get_btn_icon_size(ctx: &egui::Context) -> FitTo {
    FitTo::Size(
        (BTN_ICON_SIZE as f32 * ctx.pixels_per_point()) as u32,
        (BTN_ICON_SIZE as f32 * ctx.pixels_per_point()) as u32
    )
}

fn load_icons(ctx: &egui::Context) -> HashMap<String, RetainedImage> {
    let mut map = HashMap::new();
    map.insert("run".to_owned(),
        RetainedImage::from_svg_bytes_with_size("run", include_bytes!("../icons/run.svg"), get_btn_icon_size(ctx)).unwrap());
    map.insert("close".to_owned(),
        RetainedImage::from_svg_bytes_with_size("close", include_bytes!("../icons/close.svg"), get_btn_icon_size(ctx)).unwrap());
    map
}