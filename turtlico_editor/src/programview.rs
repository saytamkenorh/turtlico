

use emath::{Vec2, Pos2, Rect};

use crate::{project::{Project, CommandRange, Command}, dndctl::{DnDCtl, DragAction}, app::EditorDragData, cmdrenderer::{CMD_SIZE_VEC, CMD_ICON_SIZE_VEC}, programviewdialogs};

pub struct ProgramViewState {
    pub project: std::rc::Rc<std::cell::RefCell<Project>>,
    size: Rect,
    drag_started: Option<DragAction>,
    project_modify_timestamp: chrono::DateTime<chrono::Local>,
    layout: Vec<Vec<f32>>,
    pub(crate) edited_cmd: Option<(usize, usize, Command)>,
}

impl ProgramViewState {
    pub fn new() -> Self {
        let this = Self {
            project: std::rc::Rc::new(Project::empty().into()),
            size: Rect::from_min_size(Pos2::new(0.0, 0.0), Vec2::new(0.0, 0.0)),
            drag_started: None,
            project_modify_timestamp: chrono::Local::now(),
            layout: vec![],
            edited_cmd: None,
        };
        this
    }

    fn recalc_layout(&mut self, ui: &mut egui::Ui) {
        (self.size, self.layout) = self.project.borrow().renderer.layout_block(
            &self.project.borrow().program, &self.project.borrow(), ui.painter(), Pos2::new(0.0, 0.0));
    }

    pub fn load_project(&mut self, ui: &mut egui::Ui, project: std::rc::Rc<std::cell::RefCell<Project>>) {
        self.project = project;
        self.recalc_layout(ui);
    }

    pub fn insert(&mut self, relpos: Pos2, data: EditorDragData) {
        {
            let (col, row) = self.xy_to_col_row(relpos);
            let mut project = self.project.borrow_mut();
            let col_max = if row < project.program.len() { project.program[row].len() - 1 } else { 0 };
            let row_max = project.program.len();
            project.insert(data.commands, usize::min(col, col_max), usize::min(row, row_max));
        }
    }

    pub fn get_cmd_at_pointer(&mut self, ui: &mut egui::Ui, rect: Rect) -> Option<(crate::project::Command, CommandRange)>{
        let mut result = None;
        ui.input(|i| {
            if let Some(ptrpos) = i.pointer.interact_pos() {
                let relpos = (ptrpos - rect.min).to_pos2();
                let (col, row) = self.xy_to_col_row(relpos);
                let project = self.project.borrow();
                if row < project.program.len() && col < project.program[row].len() {
                    result = Some((project.program[row][col].clone(), CommandRange::single_icon(col, row)));
                }
            }
        });
        result
    }

    fn xy_to_col_row(&mut self, relpos: Pos2) -> (usize, usize) {
        let row = f32::floor(relpos.y / CMD_SIZE_VEC.y) as usize;
        let col = if row < self.layout.len() {
            let line_layout = &self.layout[row];
            let mut col = 0;
            let mut x = 0.0;
            while col < line_layout.len() && relpos.x > (x + line_layout[col]) {
                x += line_layout[col];
                col += 1;
            }
            col
        } else {
            f32::floor(relpos.x / CMD_SIZE_VEC.x) as usize
        };
        (col, row)
    }
}

fn programview_ui(ui: &mut egui::Ui, state: &mut ProgramViewState, dndctl: &mut DnDCtl<EditorDragData>) -> egui::Response {  
    // Layout updates
    let project_modify_timestamp = state.project.borrow().modify_timestamp;
    if project_modify_timestamp != state.project_modify_timestamp {
        state.recalc_layout(ui);
        state.project_modify_timestamp = project_modify_timestamp;
    }

    let available_space = ui.available_size();
    let desired_size = egui::vec2(available_space.x - ui.style().spacing.item_spacing.x, available_space.y - ui.style().spacing.item_spacing.y);
    let bg_color = ui.style().visuals.extreme_bg_color;
    let fg_color = ui.style().visuals.text_color();
    
    ui.add_sized(desired_size, |ui: &mut egui::Ui| {
        egui::Frame::group(ui.style()).fill(bg_color).show(ui, |ui: &mut egui::Ui| {
            ui.set_min_size(ui.available_size());
            egui::ScrollArea::both().show(ui, |ui| {
                let (rect, response) = ui.allocate_at_least(
                    Vec2::new(f32::max(ui.available_width(), state.size.width() + CMD_ICON_SIZE_VEC.x * 3.0), f32::max(ui.available_height(), state.size.height() + CMD_ICON_SIZE_VEC.y * 3.0)),
                    egui::Sense::click_and_drag());
                
                // User input
                ui.set_enabled(state.edited_cmd.is_none());
                if ui.is_enabled() {
                    if let Some((droppos, data)) = dndctl.drag_receive(rect) {
                        state.insert((droppos - rect.min).to_pos2(), data);
                    }

                    if response.drag_started() {
                        state.drag_started = Some(if response.drag_started_by(egui::PointerButton::Secondary) { DragAction::COPY } else { DragAction::MOVE });
                    }
                    if let Some(start_button) = state.drag_started {
                        if response.drag_delta().length_sq() > 3.0 {
                            if let Some((cmd, range)) = state.get_cmd_at_pointer(ui, rect) {
                                dndctl.drag_start(ui, EditorDragData {
                                    action: start_button,
                                    commands: vec![vec![cmd]],
                                    commands_range: Some(range),
                                    project: state.project.clone(),
                                });
                            }
                            state.drag_started = None;
                        }
                    }
                    if !response.dragged() {
                        state.drag_started = None;
                    }

                    if response.secondary_clicked() {
                        if let Some((cmd, range)) = state.get_cmd_at_pointer(ui, rect) {
                            state.edited_cmd = Some((range.start.0, range.start.1, cmd.clone()));
                        }
                    }
                }

                programviewdialogs::dialog(ui, state);

                if ui.is_rect_visible(rect) {
                    let visuals = ui.style().noninteractive();
                    let rect = rect.expand(visuals.expansion);
                    let painter = ui.painter().with_clip_rect(rect);
            
                    {
                        let mut project = state.project.borrow_mut();
                        project.renderer.color_program_bg = bg_color;
                        project.renderer.color_program_fg = fg_color;
                    }
                    let project = state.project.borrow();
                    project.renderer.render_block(&project.program, &project, &painter, rect.min, None);
                }
            });
        }).response
    }).interact(egui::Sense::drag())
}

pub fn programview<'a>(state: &'a mut ProgramViewState, dndctl: &'a mut DnDCtl<EditorDragData>) -> impl egui::Widget + 'a {
    move |ui: &mut egui::Ui| programview_ui(ui, state, dndctl)
}
