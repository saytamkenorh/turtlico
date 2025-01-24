use turtlicoscript::tokens::Token;

use crate::{
    app::EditorDragData,
    cmdrenderer::CMD_SIZE,
    dialogs,
    dndctl::{DnDCtl, DragAction},
    project::{Command, Project},
    tilemapeditor::TilemapEditorState,
};

pub struct CmdPaletteState {
    pub active_plugin: Option<&'static str>,
    icon_default_blocks: egui::load::SizedTexture,
    icon_tilemaps: egui::load::SizedTexture,
    icon_files: egui::load::SizedTexture,
    pub(crate) edited_tilemap: Option<(String, String, TilemapEditorState)>,
}

impl CmdPaletteState {
    pub fn new(project: &Project, ctx: &egui::Context) -> Self {
        Self {
            active_plugin: project.plugins.first().map(|p| p.name),
            icon_default_blocks: crate::project::plugin_icon!("../icons/default_blocks.svg", ctx),
            icon_tilemaps: crate::project::plugin_icon!("../icons/tilemaps.svg", ctx),
            icon_files: crate::project::plugin_icon!("../icons/files.svg", ctx),
            edited_tilemap: None,
        }
    }
}

fn cmdpalette_ui(
    ui: &mut egui::Ui,
    state: &mut CmdPaletteState,
    project: std::rc::Rc<std::cell::RefCell<Project>>,
    dndctl: &mut DnDCtl<EditorDragData>,
    space_after: f32,
    enable_plugins: bool,
    enable_default_blocks: bool,
    enable_tilemaps: bool,
    enable_files: bool,
    place_blocks: bool,
) -> egui::Response {
    ui.with_layout(egui::Layout::left_to_right(egui::Align::Min), |ui| {
        // Categories
        ui.vertical(|ui| {
            // Plugins - commands and blocks
            if enable_plugins {
                for plugin in project.borrow().plugins.iter() {
                    let btn = ui.add(egui::ImageButton::new(plugin.icon));
                    if btn.clicked() {
                        state.active_plugin = Some(plugin.name);
                    }
                }
            }
            // Default blocks
            if enable_default_blocks {
                let btn = ui.add(egui::ImageButton::new(state.icon_default_blocks));
                if btn.clicked() {
                    state.active_plugin = Some("default_blocks");
                }
            }
            // Tilemaps, tilemap editor
            if enable_tilemaps {
                let btn = ui.add(egui::ImageButton::new(state.icon_tilemaps));
                if btn.clicked() {
                    state.active_plugin = Some("tilemaps");
                }
            }
            // Files (images and blocks)
            if enable_files {
                let btn = ui.add(egui::ImageButton::new(state.icon_files));
                if btn.clicked() {
                    state.active_plugin = Some("files");
                }
            }
        });
        // Commands
        let available_space = ui.available_size();
        let desired_size = egui::vec2(
            (CMD_SIZE as f32) * 4.0 + ui.style().spacing.item_spacing.x * 4.0,
            available_space.y - ui.style().spacing.item_spacing.y,
        );
        ui.add_sized(desired_size, |ui: &mut egui::Ui| {
            let resp = ui
                .group(|ui| {
                    ui.set_min_height(ui.available_height() - space_after);
                    ui.push_id(ui.id().with("scrollview"), |ui| {
                        ui.set_width((CMD_SIZE as f32) * 4.0 + ui.style().spacing.item_spacing.x * 3.0);
                        egui::ScrollArea::both().show(ui, |ui| {
                            //ui.set_height(ui.available_height() - space_after);
                            ui.with_layout(
                                egui::Layout::left_to_right(emath::Align::Min).with_main_wrap(true),
                                |ui| {
                                    if let Some(active_plugin) = state.active_plugin {
                                        let show_plugin = {
                                            if let Some(active_plugin) =
                                                project.borrow().get_plugin(active_plugin)
                                            {
                                                for cmd in active_plugin.commands.iter() {
                                                    ui.add(cmdiconsource(
                                                        vec![cmd],
                                                        0,
                                                        project.clone(),
                                                        dndctl,
                                                    ));
                                                }
                                                true
                                            } else {
                                                false
                                            }
                                        };
                                        if show_plugin {
                                        } else if active_plugin == "default_blocks" {
                                            for (name, _) in project.borrow().default_blocks.iter()
                                            {
                                                let cmds = if place_blocks {
                                                    vec![
                                                        Command::Token(Token::Function(
                                                            "place_block".to_owned(),
                                                        )),
                                                        Command::Token(Token::Image(
                                                            name.to_owned(),
                                                        )),
                                                    ]
                                                } else {
                                                    vec![
                                                        Command::Token(Token::Image(
                                                            name.to_owned(),
                                                        ))
                                                    ]
                                                };
                                                ui.add(cmdiconsource(
                                                    cmds.iter().collect(),
                                                    if place_blocks { 1 } else { 0 },
                                                    project.clone(),
                                                    dndctl,
                                                ));
                                            }
                                        } else if active_plugin == "files" {
                                            for (file, _data) in project.borrow().files.iter() {
                                                ui.add(cmdiconsource(
                                                    vec![
                                                        &Command::Token(Token::Function(
                                                            "place_block".to_owned(),
                                                        )),
                                                        &Command::Token(Token::File(
                                                            file.to_owned(),
                                                        )),
                                                    ],
                                                    1,
                                                    project.clone(),
                                                    dndctl,
                                                ));
                                            }
                                        } else if active_plugin == "tilemaps" {
                                            ui.add_sized(
                                                egui::Vec2::new(desired_size.x - 10.0, 10.0),
                                                |ui: &mut egui::Ui| {
                                                    let btn = ui.button("New tilemap");
                                                    if btn.clicked()
                                                        && state.edited_tilemap.is_none()
                                                    {
                                                        {
                                                            let mut project = project.borrow_mut();
                                                            let tilemap_name =
                                                                project.new_tilemap();
                                                            let editor_state =
                                                                TilemapEditorState::new(
                                                                    &project,
                                                                    ui.ctx(),
                                                                    project.tilemaps[&tilemap_name]
                                                                        .clone(),
                                                                );
                                                            state.edited_tilemap = Some((
                                                                tilemap_name.to_owned(),
                                                                tilemap_name.to_owned(),
                                                                editor_state,
                                                            ));
                                                        }
                                                    }
                                                    btn
                                                },
                                            );
                                            for (scene, _data) in project.borrow().tilemaps.iter() {
                                                ui.add(cmdiconsource(
                                                    vec![&Command::Token(Token::Tilemap(
                                                        scene.to_owned(),
                                                    ))],
                                                    0,
                                                    project.clone(),
                                                    dndctl,
                                                ));
                                            }
                                            ui.add_sized(
                                                egui::Vec2::new(desired_size.x - 10.0, 50.0),
                                                |ui: &mut egui::Ui| {
                                                    ui.group(|ui| {
                                                        let resp = ui.add(egui::Label::new(
                                                            "Drag tilemap here to edit",
                                                        ));
                                                        if let Some((_, data)) =
                                                            dndctl.drag_receive(resp.rect)
                                                        {
                                                            if data.commands.len() == 1
                                                                && data.commands[0].len() == 1
                                                            {
                                                                let cmd = &data.commands[0][0];
                                                                let project = project.borrow();
                                                                if let Command::Token(
                                                                    Token::Tilemap(tilemap),
                                                                ) = cmd
                                                                {
                                                                    if project
                                                                        .tilemaps
                                                                        .contains_key(tilemap)
                                                                    {
                                                                        let editor_state =
                                                                            TilemapEditorState::new(
                                                                                &project,
                                                                                ui.ctx(),
                                                                                project.tilemaps
                                                                                    [tilemap]
                                                                                    .clone(),
                                                                            );
                                                                        state.edited_tilemap =
                                                                            Some((
                                                                                tilemap.clone(),
                                                                                tilemap.clone(),
                                                                                editor_state,
                                                                            ));
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    })
                                                    .response
                                                },
                                            );

                                            ui.add_sized(
                                                egui::Vec2::new(desired_size.x - 10.0, 50.0),
                                                |ui: &mut egui::Ui| {
                                                    ui.group(|ui| {
                                                        let resp = ui.add(egui::Label::new(
                                                            "Drag tilemap here to delete",
                                                        ));
                                                        if let Some((_, data)) =
                                                            dndctl.drag_receive(resp.rect)
                                                        {
                                                            if data.commands.len() == 1
                                                                && data.commands[0].len() == 1
                                                            {
                                                                let cmd = &data.commands[0][0];
                                                                if let Command::Token(
                                                                    Token::Tilemap(tilemap),
                                                                ) = cmd
                                                                {
                                                                    project
                                                                        .borrow_mut()
                                                                        .remove_tilemap(tilemap);
                                                                }
                                                            }
                                                        }
                                                    })
                                                    .response
                                                },
                                            );
                                        } else {
                                            state.active_plugin = None;
                                        }
                                    }
                                },
                            )
                            .response
                        })
                    })
                    .response
                })
                .response;
            dndctl.drag_receive(resp.rect);
            resp
        });
        dialogs::cmdpallete_dialog(ui, state, project);
    })
    .response
}

pub fn cmdpalette<'a>(
    state: &'a mut CmdPaletteState,
    project: std::rc::Rc<std::cell::RefCell<Project>>,
    dndctl: &'a mut DnDCtl<EditorDragData>,
    space_after: f32,
    enable_plugins: bool,
    enable_default_blocks: bool,
    enable_tilemaps: bool,
    enable_files: bool,
    place_blocks: bool,
) -> impl egui::Widget + 'a {
    move |ui: &mut egui::Ui| {
        cmdpalette_ui(
            ui,
            state,
            project,
            dndctl,
            space_after,
            enable_plugins,
            enable_default_blocks,
            enable_tilemaps,
            enable_files,
            place_blocks,
        )
    }
}

fn cmdiconsource_ui(
    ui: &mut egui::Ui,
    cmd: Vec<&Command>,
    preview_index: usize,
    project: std::rc::Rc<std::cell::RefCell<Project>>,
    dndctl: &mut DnDCtl<EditorDragData>,
) -> egui::Response {
    let render_rect = project.borrow().renderer.as_ref().unwrap().render_icon(
        cmd[preview_index],
        &project.borrow(),
        ui.painter(),
        egui::pos2(0.0, 0.0),
        false,
    );
    let (rect, response) = ui.allocate_exact_size(render_rect.size(), egui::Sense::drag());

    project.borrow().renderer.as_ref().unwrap().render_icon(
        cmd[preview_index],
        &project.borrow(),
        &ui.painter().with_clip_rect(rect),
        rect.min,
        true,
    );
    if response.drag_started() {
        dndctl.drag_start(
            ui,
            EditorDragData {
                commands: vec![cmd
                    .into_iter().cloned()
                    .collect::<Vec<Command>>()],
                commands_range: None,
                project: project.clone(),
                action: DragAction::COPY,
            },
        );
    }

    response
}

pub fn cmdiconsource<'a>(
    cmd: Vec<&'a Command>,
    preview_index: usize,
    project: std::rc::Rc<std::cell::RefCell<Project>>,
    dndctl: &'a mut DnDCtl<EditorDragData>,
) -> impl egui::Widget + 'a {
    move |ui: &mut egui::Ui| cmdiconsource_ui(ui, cmd, preview_index, project, dndctl)
}
