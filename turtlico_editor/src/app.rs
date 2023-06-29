use std::collections::HashMap;

use egui_extras::{RetainedImage, image::FitTo};
use emath::Vec2;
use turtlicoscript::parser;
use turtlicoscript_gui::app::SubApp;

const BTN_ICON_SIZE: u32 = 22;
const MARGIN_SMALL: f32 = 4.0;

pub struct EditorApp {
    icons: HashMap<String, RetainedImage>,
    codeview_text: String,
    code_subapp: Option<Box<dyn SubApp>>,
}

impl EditorApp {
    pub fn new() -> Self {
        Self {
            icons: load_icons(),
            codeview_text: String::new(),
            code_subapp: None
        }
    }

    fn ui(&mut self, ui: &mut egui::Ui) {
        let style = ui.style_mut();
        style.spacing.button_padding = Vec2::new(4.0, 4.0);
        style.spacing.item_spacing = Vec2::new(8.0, 8.0);

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
            ui.with_layout(egui::Layout::right_to_left(egui::Align::TOP), |ui| {
                ui.add_space(MARGIN_SMALL);
                egui::ScrollArea::both().show(ui, |ui| {
                    ui.add(
                        egui::TextEdit::multiline(&mut self.codeview_text)
                            .font(egui::TextStyle::Monospace) // for cursor height
                            .code_editor()
                            .desired_rows(10)
                            .lock_focus(true)
                            .desired_width(f32::INFINITY)
                    );
                });
            });
        });
    }


    fn run(&mut self) {
        if self.code_subapp.is_some() {
            return;
        }
        let src = self.codeview_text.to_owned();
        match parser::parse(&src) {
            Ok(ast) => {
                let subapp = turtlicoscript_gui::app::ScriptApp::spawn(ast, true);
                self.code_subapp = Some(subapp);
            },
            Err(errors) => {
                eprintln!("File parse error (s):\n{}", errors.into_iter().map(|err| err.build_message(&src)).collect::<Vec<String>>().join("\n"));
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
        match self.code_subapp.as_mut() {
            Some(code_subapp) => {
                let app_continues = code_subapp.update(ctx, frame);
                if !app_continues {
                    self.code_subapp = None;
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
    map
}