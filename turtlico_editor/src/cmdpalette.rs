use turtlicoscript::tokens::Token;

use crate::{project::{Project, Command}, cmdrenderer::{CMD_SIZE, CMD_SIZE_VEC}, dndctl::{DnDCtl, DragAction}, app::EditorDragData};

pub struct CmdPaletteState {
    pub active_plugin: Option<&'static str>,
    icon_default_blocks: egui::load::SizedTexture,
}

impl CmdPaletteState {
    pub fn new(project: &Project, ctx: &egui::Context) -> Self {
        Self {
            active_plugin: project.plugins.first().map(|p| p.name),
            icon_default_blocks: crate::project::plugin_icon!("../icons/default_blocks.svg", ctx),
        }
    }
}

fn cmdpalette_ui(ui: &mut egui::Ui, state: &mut CmdPaletteState, project: std::rc::Rc<std::cell::RefCell<Project>>, dndctl: &mut DnDCtl<EditorDragData>) -> egui::Response {
    ui.with_layout(egui::Layout::left_to_right(egui::Align::Min), |ui| {
        ui.vertical(|ui| {
            for plugin in project.borrow().plugins.iter() {
                let btn = ui.add(egui::ImageButton::new(plugin.icon));
                if btn.clicked() {
                    state.active_plugin = Some(plugin.name);
                }
            }
            // Default blocks
            let btn = ui.add(egui::ImageButton::new(state.icon_default_blocks));
            if btn.clicked() {
                state.active_plugin = Some("default_blocks");
            }
        });
        let available_space = ui.available_size();
        let desired_size = egui::vec2((CMD_SIZE as f32 + ui.style().spacing.item_spacing.x * 2.0) * 4.0, available_space.y - ui.style().spacing.item_spacing.y);
        ui.add_sized(desired_size, |ui: &mut egui::Ui| {
            let resp = ui.group(|ui| {
                ui.set_min_height(ui.available_height());
                ui.push_id(ui.id().with("scrollview"), |ui| {
                    egui::ScrollArea::vertical().show(ui, |ui| {
                        ui.with_layout(egui::Layout::left_to_right(emath::Align::Min).with_main_wrap(true), |ui| {
                                if let Some(active_plugin) = state.active_plugin {
                                    if let Some(active_plugin) = project.borrow().get_plugin(active_plugin) {
                                        for cmd in active_plugin.commands.iter() {
                                            ui.add(cmdiconsource(vec![cmd], 0, project.clone(), dndctl));
                                        }
                                    } else if active_plugin == "default_blocks" {
                                        for (name, _) in project.borrow().default_blocks.iter() {
                                            ui.add(cmdiconsource(vec![
                                                &Command::Token(Token::Function("place_block".to_owned())),
                                                &Command::Token(Token::Image(name.to_owned()))
                                            ], 1, project.clone(), dndctl));
                                        }
                                    } else {
                                        state.active_plugin = None;
                                    }
                                }
                            }
                        ).response
                    })
                }).response
            }).response;
            dndctl.drag_receive(resp.rect);
            resp
        });
    }).response
}

pub fn cmdpalette<'a>(state: &'a mut CmdPaletteState, project: std::rc::Rc<std::cell::RefCell<Project>>, dndctl: &'a mut DnDCtl<EditorDragData>) -> impl egui::Widget + 'a {
    move |ui: &mut egui::Ui| cmdpalette_ui(ui, state, project, dndctl)
}

fn cmdiconsource_ui(ui: &mut egui::Ui, cmd: Vec<&Command>, preview_index: usize, project: std::rc::Rc<std::cell::RefCell<Project>>, dndctl: &mut DnDCtl<EditorDragData>) -> egui::Response {
    let (rect, response) = ui.allocate_exact_size(CMD_SIZE_VEC, egui::Sense::drag());

    project.borrow().renderer.as_ref().unwrap().render_icon(&cmd[preview_index], &project.borrow(), &ui.painter().with_clip_rect(rect), rect.min, true);
    if response.drag_started() {
        dndctl.drag_start(ui, EditorDragData {
            commands: vec![cmd.into_iter().map(|cmd| cmd.clone()).collect::<Vec<Command>>()],
            commands_range: None,
            project: project.clone(),
            action: DragAction::COPY
        });
    }

    response
}

pub fn cmdiconsource<'a>(cmd: Vec<&'a Command>, preview_index: usize, project: std::rc::Rc<std::cell::RefCell<Project>>, dndctl: &'a mut DnDCtl<EditorDragData>) -> impl egui::Widget + 'a {
    move |ui: &mut egui::Ui| cmdiconsource_ui(ui, cmd, preview_index, project, dndctl)
}