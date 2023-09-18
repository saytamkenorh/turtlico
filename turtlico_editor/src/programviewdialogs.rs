use turtlicoscript::tokens::Token;

use crate::{project::Command, programview::ProgramViewState};


pub enum DialogResult {
    Running,
    Apply,
    Cancel
}

pub fn dialog(ui: &mut egui::Ui, state: &mut ProgramViewState) {
    if let Some(edited_cmd) = &mut state.edited_cmd {
        match &edited_cmd.2 {
            Command::Comment(val) => {
                let mut new_value = val.to_string();
                match show_dialog(ui, "Enter a comment", |ui: &mut egui::Ui| {
                    ui.add(egui::TextEdit::singleline(&mut new_value))
                }) {
                    DialogResult::Apply => {
                        state.project.borrow_mut().program[edited_cmd.1][edited_cmd.0] = Command::Comment(new_value);
                        state.edited_cmd = None;
                    },
                    DialogResult::Cancel => {
                        state.edited_cmd = None;
                    },
                    _ => {
                        edited_cmd.2 = Command::Comment(new_value);
                    }
                }
            },
            Command::Token(token) => {
                match token {
                    Token::String(val) => {
                        let mut new_value = val.to_string();
                        match show_dialog(ui, "Enter a string", |ui: &mut egui::Ui| {
                            ui.add(egui::TextEdit::singleline(&mut new_value))
                        }) {
                            DialogResult::Apply => {
                                state.project.borrow_mut().program[edited_cmd.1][edited_cmd.0] = Command::Token(Token::String(new_value));
                                state.edited_cmd = None;
                            },
                            DialogResult::Cancel => {
                                state.edited_cmd = None;
                            },
                            _ => {
                                edited_cmd.2 = Command::Token(Token::String(new_value));
                            }
                        }
                    },
                    Token::Integer(mut val) => {
                        match show_dialog(ui, "Enter an integer", |ui: &mut egui::Ui| {
                            ui.add(egui::DragValue::new(&mut val))
                        }) {
                            DialogResult::Apply => {
                                state.project.borrow_mut().program[edited_cmd.1][edited_cmd.0] = Command::Token(Token::Integer(val));
                                state.edited_cmd = None;
                            },
                            DialogResult::Cancel => {
                                state.edited_cmd = None;
                            },
                            _ => {
                                edited_cmd.2 = Command::Token(Token::Integer(val));
                            }
                        }
                    },
                    Token::Float(val) => {
                        let mut new_val: f32 = val.parse().unwrap_or(0.0);
                        match show_dialog(ui, "Enter a float", |ui: &mut egui::Ui| {
                            ui.add(egui::DragValue::new(&mut new_val).speed(0.1))
                        }) {
                            DialogResult::Apply => {
                                state.project.borrow_mut().program[edited_cmd.1][edited_cmd.0] = Command::Token(Token::Float(new_val.to_string()));
                                state.edited_cmd = None;
                            },
                            DialogResult::Cancel => {
                                state.edited_cmd = None;
                            },
                            _ => {
                                edited_cmd.2 = Command::Token(Token::Float(new_val.to_string()));
                            }
                        }
                    },
                    Token::Variable(val) => {
                        let mut new_value = val.to_string();
                        match show_dialog(ui, "Enter a variable name", |ui: &mut egui::Ui| {
                            ui.add(egui::TextEdit::singleline(&mut new_value))
                        }) {
                            DialogResult::Apply => {
                                state.project.borrow_mut().program[edited_cmd.1][edited_cmd.0] = Command::Token(Token::Variable(new_value));
                                state.edited_cmd = None;
                            },
                            DialogResult::Cancel => {
                                state.edited_cmd = None;
                            },
                            _ => {
                                edited_cmd.2 = Command::Token(Token::Variable(new_value));
                            }
                        }    
                    },
                    Token::Function(val) => {
                        let mut new_value = val.to_string();
                        match show_dialog(ui, "Enter a function name", |ui: &mut egui::Ui| {
                            ui.add(egui::TextEdit::singleline(&mut new_value))
                        }) {
                            DialogResult::Apply => {
                                state.project.borrow_mut().program[edited_cmd.1][edited_cmd.0] = Command::Token(Token::Function(new_value));
                                state.edited_cmd = None;
                            },
                            DialogResult::Cancel => {
                                state.edited_cmd = None;
                            },
                            _ => {
                                edited_cmd.2 = Command::Token(Token::Function(new_value));
                            }
                        }    
                    },
                    _ => {
                        state.edited_cmd = None;
                    }
                }
            }
        }
    }
}

fn show_dialog<F: FnOnce(&mut egui::Ui) -> egui::Response>(ui: &mut egui::Ui, title: &str, add_input: F) -> DialogResult {
    let rect = egui::Rect::from_center_size(ui.ctx().screen_rect().center(), egui::vec2(200.0, 50.0));
    let win = egui::Window::new(title).collapsible(false).fixed_rect(rect);
    let mut result = DialogResult::Running;
    win.show(ui.ctx(), |ui: &mut egui::Ui| {
        ui.style_mut().drag_value_text_style = egui::TextStyle::Heading;
        ui.add_sized(ui.available_size(), add_input);
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