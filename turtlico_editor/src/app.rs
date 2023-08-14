use std::collections::HashMap;

use egui_extras::{RetainedImage, image::FitTo};
use emath::Vec2;
use turtlicoscript::{parser, ast::Spanned};
use turtlicoscript_gui::app::{SubApp, ScriptApp, ScriptState};

const BTN_ICON_SIZE: u32 = 22;
const MARGIN_SMALL: f32 = 4.0;
const MARGIN_MEDIUM: f32 = 8.0;
const COLOR_ERROR: egui::Color32 = egui::Color32::from_rgb(255, 200, 200);

pub struct EditorApp {
    icons: HashMap<String, RetainedImage>,
    codeview_text: String,
    script_subapp: Option<ScriptApp>,
    script_errors: Option<Vec<Spanned<turtlicoscript::error::Error>>>,
}

impl EditorApp {
    pub fn new() -> Self {
        Self {
            icons: load_icons(),
            codeview_text: String::new(),
            script_subapp: None,
            script_errors: None,
        }
    }

    fn ui(&mut self, ui: &mut egui::Ui) {
        let style = ui.style_mut();
        style.spacing.button_padding = Vec2::new(MARGIN_SMALL, MARGIN_SMALL);
        style.spacing.item_spacing = Vec2::new(MARGIN_MEDIUM, MARGIN_MEDIUM);

        ui.vertical(|ui| {
            ui.add_space(MARGIN_SMALL);
            ui.horizontal(|ui| {
                ui.add_space(MARGIN_SMALL);
                let run_img = self.icons.get("run").unwrap();
                let run_btn = ui.add(
                    egui::ImageButton::new(run_img.texture_id(ui.ctx()), Vec2::new(BTN_ICON_SIZE as f32, BTN_ICON_SIZE as f32)));
                if run_btn.clicked() {
                    self.run();
                }
            });
            ui.with_layout(egui::Layout::left_to_right(egui::Align::TOP), |ui| {
                ui.add_space(MARGIN_MEDIUM);
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
                    egui::ScrollArea::both().show(ui, |ui| {
                        ui.add(
                            egui::TextEdit::multiline(&mut self.codeview_text)
                                .font(egui::TextStyle::Monospace) // for cursor height
                                .code_editor()
                                .desired_rows(10)
                                .lock_focus(true)
                                .desired_width(f32::INFINITY)
                        );
                    })
                });
            });
        });
    }


    fn run(&mut self) {
        if self.script_subapp.is_some() {
            return;
        }
        let src = self.codeview_text.to_owned();
        match parser::parse(&src) {
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

fn load_icons() -> HashMap<String, RetainedImage> {
    let mut map = HashMap::new();
    map.insert("run".to_owned(),
        RetainedImage::from_svg_bytes_with_size("run", include_bytes!("../icons/run.svg"), FitTo::Size(BTN_ICON_SIZE, BTN_ICON_SIZE)).unwrap());
    map.insert("close".to_owned(),
        RetainedImage::from_svg_bytes_with_size("close", include_bytes!("../icons/close.svg"), FitTo::Size(BTN_ICON_SIZE, BTN_ICON_SIZE)).unwrap());
    map
}