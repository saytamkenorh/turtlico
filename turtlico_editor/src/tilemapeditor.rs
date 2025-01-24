use std::thread::panicking;

use turtlicoscript::tokens::Token;
use turtlicoscript_gui::{tilemap::Tilemap, world::BLOCK_SIZE_PX};

use crate::{
    app::EditorDragData,
    cmdpalette::{self, CmdPaletteState},
    dialogs::{show_dialog, DialogResult, DialogSizeMode},
    dndctl::{self, DnDCtl},
    project::{Command, CommandRange, Project},
    widgets::MARGIN_SMALL,
};

pub struct TilemapEditorState {
    tilemap: Tilemap,
    pub blocks: turtlicoscript_gui::world::BlockTextures,
    cmdpalette_state: Box<CmdPaletteState>,
    dndctl: DnDCtl<EditorDragData>,
}

impl TilemapEditorState {
    pub fn new(project: &Project, ctx: &egui::Context, tilemap: Tilemap) -> Self {
        let mut palette_state = CmdPaletteState::new(project, ctx);
        palette_state.active_plugin = Some("default_blocks");
        Self {
            tilemap: tilemap,
            blocks: turtlicoscript_gui::world::World::default_blocks(ctx),
            cmdpalette_state: Box::new(palette_state),
            dndctl: DnDCtl::new(),
        }
    }

    pub fn drag_insert(&mut self, relpos: emath::Pos2, data: EditorDragData) {
        let (row, col) = self.relpos_to_col_row(relpos);
        if row >= self.tilemap.get_width() || col >= self.tilemap.get_height() {
            return;
        }
        if data.commands.len() < 1 || data.commands[0].len() < 1 {
            return;
        }
        match &data.commands[0][0] {
            Command::Token(token) => match token {
                turtlicoscript::tokens::Token::Image(img) => {
                    self.tilemap.set_block(row, col, Some(img.to_owned()));
                }
                _ => {}
            },
            _ => {}
        }
    }

    pub fn relpos_to_col_row(&self, relpos: emath::Pos2) -> (usize, usize) {
        (
            (relpos.x / BLOCK_SIZE_PX).floor() as usize,
            (relpos.y / BLOCK_SIZE_PX).floor() as usize,
        )
    }

    pub fn get_cmd_at_pointer(
        &mut self,
        ui: &mut egui::Ui,
        rect: egui::Rect,
    ) -> Option<(crate::project::Command, usize, usize)> {
        let mut result = None;
        ui.input(|i| {
            if let Some(ptrpos) = i.pointer.interact_pos() {
                let relpos = (ptrpos - rect.min).to_pos2();
                let (col, row) = self.relpos_to_col_row(relpos);
                if let Some(tile) = self.tilemap.get_block(col, row) {
                    result = Some((Command::Token(Token::Image(tile)), col, row));
                }
            }
        });
        result
    }
}

fn tilemapeditor_view_ui(
    ui: &mut egui::Ui,
    state: &mut TilemapEditorState,
    project: std::rc::Rc<std::cell::RefCell<Project>>,
) -> egui::Response {
    let available_space = ui.available_size();
    let desired_size = egui::vec2(
        available_space.x - ui.style().spacing.item_spacing.x,
        available_space.y - 16.0,
    );
    let bg_color = egui::Color32::GRAY;
    ui.add_sized(desired_size, |ui: &mut egui::Ui| {
        egui::Frame::group(ui.style())
            .fill(bg_color)
            .show(ui, |ui: &mut egui::Ui| {
                ui.set_min_size(desired_size);
                egui::ScrollArea::both().show(ui, |ui| {
                    let (rect, response) = ui.allocate_at_least(
                        egui::Vec2::new(
                            f32::max(
                                ui.available_width(),
                                state.tilemap.get_width() as f32 * BLOCK_SIZE_PX as f32,
                            ),
                            f32::max(
                                ui.available_height(),
                                state.tilemap.get_height() as f32 * BLOCK_SIZE_PX as f32,
                            ),
                        ),
                        egui::Sense::click_and_drag(),
                    );

                    if ui.is_enabled() {
                        if let Some((droppos, data)) = state.dndctl.drag_receive(rect) {
                            state.drag_insert((droppos - rect.min).to_pos2(), data);
                        }
                        if response.drag_started() {
                            if response.drag_delta().length_sq() > 3.0 {
                                if let Some((cmd, col, row)) = state.get_cmd_at_pointer(ui, rect) {
                                    state.tilemap.set_block(col, row, None);
                                    state.dndctl.drag_start(
                                        ui,
                                        EditorDragData {
                                            action: dndctl::DragAction::MOVE,
                                            commands: vec![vec![cmd]],
                                            commands_range: None,
                                            project: project.clone(),
                                        },
                                    );
                                }
                            }
                        }
                    }

                    if ui.is_rect_visible(rect) {
                        let visuals = ui.style().noninteractive();
                        let rect = rect.expand(visuals.expansion);
                        let painter = ui.painter().with_clip_rect(rect);

                        painter.rect_filled(rect, 0.0, bg_color);
                        painter.rect_filled(
                            egui::Rect::from_min_size(
                                rect.min,
                                egui::vec2(
                                    state.tilemap.get_width() as f32 * BLOCK_SIZE_PX as f32,
                                    state.tilemap.get_height() as f32 * BLOCK_SIZE_PX as f32,
                                ),
                            ),
                            0.0,
                            egui::Color32::WHITE,
                        );

                        for y in 0..state.tilemap.get_height() {
                            for x in 0..state.tilemap.get_width() {
                                if let Some(block) =
                                    state.tilemap.tiles.get((x, y)).unwrap_or(&None)
                                {
                                    let block = state.blocks.get(block).unwrap();
                                    let mut mesh = egui::Mesh::with_texture(block.id);
                                    let block_rect = egui::Rect::from_min_size(
                                        egui::Pos2 {
                                            x: x as f32 * BLOCK_SIZE_PX,
                                            y: y as f32 * BLOCK_SIZE_PX,
                                        },
                                        egui::Vec2 {
                                            x: BLOCK_SIZE_PX,
                                            y: BLOCK_SIZE_PX,
                                        },
                                    )
                                    .translate(egui::vec2(
                                        painter.clip_rect().left(),
                                        painter.clip_rect().top(),
                                    ));
                                    mesh.add_rect_with_uv(
                                        block_rect,
                                        egui::Rect::from_min_max(
                                            egui::pos2(0.0, 0.0),
                                            egui::pos2(1.0, 1.0),
                                        ),
                                        egui::Color32::WHITE,
                                    );
                                    painter.add(egui::Shape::mesh(mesh));
                                }
                            }
                        }
                    }
                });
            })
            .response
    })
}

pub fn tilemapeditor_view<'a>(
    state: &'a mut TilemapEditorState,
    project: std::rc::Rc<std::cell::RefCell<Project>>,
) -> impl egui::Widget + 'a {
    move |ui: &mut egui::Ui| tilemapeditor_view_ui(ui, state, project)
}

pub fn tilemapeditor_dialog(
    ui: &mut egui::Ui,
    edited_tilemap: &mut (String, String, TilemapEditorState),
    project: std::rc::Rc<std::cell::RefCell<Project>>,
) -> bool {
    let mut new_name = edited_tilemap.1.to_string();
    match show_dialog(
        ui,
        "Edit tilemap",
        DialogSizeMode::Fullscreen,
        |ui: &mut egui::Ui| {
            let resp = ui
                .with_layout(
                    egui::Layout::top_down(egui::Align::Min),
                    |ui: &mut egui::Ui| {
                        ui.add(
                            egui::TextEdit::singleline(&mut new_name)
                                .horizontal_align(egui::Align::Min),
                        );

                        ui.with_layout(egui::Layout::left_to_right(egui::Align::TOP), |ui| {
                            ui.add_space(MARGIN_SMALL);
                            ui.add(cmdpalette::cmdpalette(
                                &mut edited_tilemap.2.cmdpalette_state,
                                project.clone(),
                                &mut edited_tilemap.2.dndctl,
                                0.0,
                                false,
                                true,
                                false,
                                false,
                                false,
                            ));
                            ui.add(tilemapeditor_view(&mut edited_tilemap.2, project.clone()));
                        })
                    },
                )
                .response;
            edited_tilemap.2.dndctl.ui(ui);
            resp
        },
    ) {
        DialogResult::Apply => {
            {
                // Rename
                let mut project = project.borrow_mut();
                project.tilemaps.remove(&edited_tilemap.0).unwrap();
                project
                    .tilemaps
                    .insert(new_name.clone(), edited_tilemap.2.tilemap.clone());
            }
            false
        }
        DialogResult::Cancel => false,
        _ => {
            edited_tilemap.1 = new_name;
            true
        }
    }
}
