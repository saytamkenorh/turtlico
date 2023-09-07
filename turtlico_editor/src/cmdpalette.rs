use crate::{project::{Project, Command}, cmdrenderer::{CMD_SIZE, CMD_SIZE_VEC}, dndctl::{DnDCtl, DragAction}, app::EditorDragData};


pub struct CmdPaletteState {
    pub active_plugin: Option<&'static str>
}

impl CmdPaletteState {
    pub fn new(project: &Project) -> Self {
        Self {
            active_plugin: project.plugins.first().map(|p| p.name)
        }
    }
}

fn cmdpalette_ui(ui: &mut egui::Ui, state: &mut CmdPaletteState, project: std::rc::Rc<std::cell::RefCell<Project>>, dndctl: &mut DnDCtl<EditorDragData>) -> egui::Response {
    ui.with_layout(egui::Layout::left_to_right(egui::Align::Min), |ui| {
        ui.vertical(|ui| {
            for plugin in project.borrow().plugins.iter() {
                ui.add(egui::ImageButton::new(plugin.icon.texture_id(ui.ctx()), crate::app::BTN_ICON_SIZE_VEC));
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
                                            ui.add(cmdiconsource(cmd, project.clone(), dndctl));
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

fn cmdiconsource_ui(ui: &mut egui::Ui, cmd: &Command, project: std::rc::Rc<std::cell::RefCell<Project>>, dndctl: &mut DnDCtl<EditorDragData>) -> egui::Response {
    let (rect, response) = ui.allocate_exact_size(CMD_SIZE_VEC, egui::Sense::drag());

    project.borrow().renderer.render_icon(cmd, &ui.painter().with_clip_rect(rect), rect.min, true);
    if response.drag_started() {
        dndctl.drag_start(ui, EditorDragData {
            commands: vec![vec![cmd.clone()]],
            commands_range: None,
            project: project.clone(),
            action: DragAction::COPY
        });
    }

    response
}

pub fn cmdiconsource<'a>(cmd: &'a Command, project: std::rc::Rc<std::cell::RefCell<Project>>, dndctl: &'a mut DnDCtl<EditorDragData>) -> impl egui::Widget + 'a {
    move |ui: &mut egui::Ui| cmdiconsource_ui(ui, cmd, project, dndctl)
}