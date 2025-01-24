use turtlicoscript::tokens::Token;

use crate::{
    cmdpalette::CmdPaletteState,
    programview::ProgramViewState,
    project::{Command, Project},
};

pub enum DialogResult {
    Running,
    Apply,
    Cancel,
}

pub enum DialogSizeMode {
    Sizable,
    RegularSize,
    Fullscreen,
    FixedSize(egui::Vec2),
}

pub fn programview_dialog(ui: &mut egui::Ui, state: &mut ProgramViewState) {
    if let Some(edited_cmd) = &mut state.edited_cmd {
        match &edited_cmd.2 {
            Command::Comment(val) => {
                let mut new_value = val.to_string();
                match show_dialog(ui, "Enter a comment", DialogSizeMode::RegularSize, |ui: &mut egui::Ui| {
                    ui.add(egui::TextEdit::singleline(&mut new_value))
                }) {
                    DialogResult::Apply => {
                        state.project.borrow_mut().program[edited_cmd.1][edited_cmd.0] =
                            Command::Comment(new_value);
                        state.edited_cmd = None;
                    }
                    DialogResult::Cancel => {
                        state.edited_cmd = None;
                    }
                    _ => {
                        edited_cmd.2 = Command::Comment(new_value);
                    }
                }
            }
            Command::Token(token) => match token {
                Token::String(val) => {
                    let mut new_value = val.to_string();
                    match show_dialog(ui, "Enter a string", DialogSizeMode::RegularSize, |ui: &mut egui::Ui| {
                        ui.add(egui::TextEdit::singleline(&mut new_value))
                    }) {
                        DialogResult::Apply => {
                            state.project.borrow_mut().program[edited_cmd.1][edited_cmd.0] =
                                Command::Token(Token::String(new_value));
                            state.edited_cmd = None;
                        }
                        DialogResult::Cancel => {
                            state.edited_cmd = None;
                        }
                        _ => {
                            edited_cmd.2 = Command::Token(Token::String(new_value));
                        }
                    }
                }
                Token::Key(val) => {
                    let mut new_value = val.to_string();
                    match show_dialog(ui, "Press a key", DialogSizeMode::RegularSize, |ui: &mut egui::Ui| {
                        ui.add(crate::widgets::key_selector(&mut new_value))
                    }) {
                        DialogResult::Apply => {
                            state.project.borrow_mut().program[edited_cmd.1][edited_cmd.0] =
                                Command::Token(Token::Key(new_value));
                            state.edited_cmd = None;
                        }
                        DialogResult::Cancel => {
                            state.edited_cmd = None;
                        }
                        _ => {
                            edited_cmd.2 = Command::Token(Token::Key(new_value));
                        }
                    }
                }
                Token::Integer(mut val) => {
                    match show_dialog(ui, "Enter an integer", DialogSizeMode::RegularSize, |ui: &mut egui::Ui| {
                        ui.add(egui::DragValue::new(&mut val))
                    }) {
                        DialogResult::Apply => {
                            state.project.borrow_mut().program[edited_cmd.1][edited_cmd.0] =
                                Command::Token(Token::Integer(val));
                            state.edited_cmd = None;
                        }
                        DialogResult::Cancel => {
                            state.edited_cmd = None;
                        }
                        _ => {
                            edited_cmd.2 = Command::Token(Token::Integer(val));
                        }
                    }
                }
                Token::Float(val) => {
                    let mut new_val: f32 = val.parse().unwrap_or(0.0);
                    match show_dialog(ui, "Enter a float", DialogSizeMode::RegularSize, |ui: &mut egui::Ui| {
                        ui.add(egui::DragValue::new(&mut new_val).speed(0.1))
                    }) {
                        DialogResult::Apply => {
                            state.project.borrow_mut().program[edited_cmd.1][edited_cmd.0] =
                                Command::Token(Token::Float(new_val.to_string()));
                            state.edited_cmd = None;
                        }
                        DialogResult::Cancel => {
                            state.edited_cmd = None;
                        }
                        _ => {
                            edited_cmd.2 = Command::Token(Token::Float(new_val.to_string()));
                        }
                    }
                }
                Token::Variable(val) => {
                    let mut new_value = val.to_string();
                    match show_dialog(ui, "Enter a variable name", DialogSizeMode::RegularSize, |ui: &mut egui::Ui| {
                        ui.add(egui::TextEdit::singleline(&mut new_value))
                    }) {
                        DialogResult::Apply => {
                            state.project.borrow_mut().program[edited_cmd.1][edited_cmd.0] =
                                Command::Token(Token::Variable(new_value));
                            state.edited_cmd = None;
                        }
                        DialogResult::Cancel => {
                            state.edited_cmd = None;
                        }
                        _ => {
                            edited_cmd.2 = Command::Token(Token::Variable(new_value));
                        }
                    }
                }
                Token::Function(val) => {
                    let mut new_value = val.to_string();
                    match show_dialog(ui, "Enter a function name", DialogSizeMode::RegularSize, |ui: &mut egui::Ui| {
                        ui.add(egui::TextEdit::singleline(&mut new_value))
                    }) {
                        DialogResult::Apply => {
                            state.project.borrow_mut().program[edited_cmd.1][edited_cmd.0] =
                                Command::Token(Token::Function(new_value));
                            state.edited_cmd = None;
                        }
                        DialogResult::Cancel => {
                            state.edited_cmd = None;
                        }
                        _ => {
                            edited_cmd.2 = Command::Token(Token::Function(new_value));
                        }
                    }
                }
                _ => {
                    state.edited_cmd = None;
                }
            },
        }
    }
}

pub fn cmdpallete_dialog(
    ui: &mut egui::Ui,
    state: &mut CmdPaletteState,
    project: std::rc::Rc<std::cell::RefCell<Project>>,
) {
    if let Some(edited_tilemap) = &mut state.edited_tilemap {
        if !crate::tilemapeditor::tilemapeditor_dialog(ui, edited_tilemap, project.clone()) {
            state.edited_tilemap = None;
        }
    }
}

pub fn show_dialog<F: FnOnce(&mut egui::Ui) -> egui::Response>(
    ui: &mut egui::Ui,
    title: &str,
    size: DialogSizeMode,
    add_input: F,
) -> DialogResult {
    let rect = egui::Rect::from_center_size(
        ui.ctx().screen_rect().center(),
        match size {
            DialogSizeMode::Fullscreen => egui::vec2(ui.ctx().screen_rect().width() * 0.8, ui.ctx().screen_rect().height() * 0.7),
            DialogSizeMode::FixedSize(size) => size,
            _ => egui::vec2(200.0, 50.0),
        },
    );
    let mut win = egui::Window::new(title).collapsible(false);
    let sizable = matches!(size, DialogSizeMode::Sizable);
    if sizable {
        win = win
            .max_size(egui::Vec2::new(
                ui.ctx().screen_rect().width() * 0.9,
                ui.ctx().screen_rect().height() * 0.9,
            ))
            .pivot(egui::Align2::CENTER_CENTER)
            .fixed_pos(ui.ctx().screen_rect().center());
    } else {
        win = win.fixed_rect(rect);
    }
    let mut result = DialogResult::Running;
    win.show(ui.ctx(), |ui: &mut egui::Ui| {
        ui.style_mut().drag_value_text_style = egui::TextStyle::Heading;
        if sizable {
            ui.add_sized(ui.available_size(), add_input);
        } else {
            ui.add(add_input);
        }
        ui.add_space(8.0);
        ui.horizontal(|ui: &mut egui::Ui| {
            if ui.button("Ok").clicked() {
                result = DialogResult::Apply;
            }
            if ui.button("Cancel").clicked() {
                result = DialogResult::Cancel;
            }
        });
        if ui.input(|i| i.key_down(egui::Key::Enter)) {
            result = DialogResult::Apply;
        }
        if ui.input(|i| i.key_down(egui::Key::Escape)) {
            result = DialogResult::Cancel;
        }
    });

    result
}
