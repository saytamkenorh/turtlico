use std::{collections::HashMap, sync::Arc};
use emath::{Rect, Vec2, Pos2};
use turtlicoscript::tokens::Token;

use crate::project::Command;

pub const CMD_SIZE: u32 = 36;
pub const CMD_SIZE_VEC: Vec2 = Vec2::new(CMD_SIZE as f32, CMD_SIZE as f32);
pub const CMD_ICON_SIZE: u32 = 32;
pub const CMD_ICON_SIZE_VEC: Vec2 = Vec2::new(CMD_ICON_SIZE as f32, CMD_ICON_SIZE as f32);

pub struct CommandRenderer {
    cmd_icons: HashMap<String, egui_extras::RetainedImage>,
    color_bg: egui::Color32,
    color_border: egui::Color32,
    pub color_program_bg: egui::Color32,
    pub color_program_fg: egui::Color32,
    color_text: egui::Color32,
}

impl CommandRenderer {
    pub fn new() -> Self {
        Self {
            cmd_icons: load_cmd_icons(),
            color_bg: egui::Color32::from_rgb(255, 179, 0),
            color_border: egui::Color32::from_rgb(20, 20, 0),
            color_program_bg: egui::Color32::from_rgb(255, 255, 255),
            color_program_fg: egui::Color32::from_rgb(0, 0, 0),
            color_text: egui::Color32::from_rgb(255, 255, 255),
        }
    }
    pub fn render_icon(&self, cmd: &Command, painter: &egui::Painter, pos: Pos2, do_paint: bool) -> Rect {
        let mut background = self.color_bg;
        let mut icon: Option<&egui_extras::RetainedImage> = None;

        let mut text: Option<&str> = None;
        let mut text_layout: Option<Arc<egui::Galley>> = None;
        let mut color_text = self.color_text;

        match cmd {
            Command::Comment(value) => {
                text = Some(value);
                background = egui::Color32::from_rgb(50, 50, 50);
            },
            Command::Token(token) => {
                match token {
                    Token::Space => {
                        background = self.color_program_bg;
                        text = Some("·");
                        color_text = self.color_program_fg;
                    },
                    Token::Newline => {
                        background = self.color_program_bg;
                        text = Some("↲");
                        color_text = self.color_program_fg;
                    },
                    Token::Function(name) => {
                        match self.cmd_icons.get(name) {
                            Some(image) => {
                                icon = Some(image);
                            },
                            None => {
                                text = Some(name);
                            }
                        }
                    },
                    token => {
                    }
                }
            }
        }
    
        // Calculate sizes
        let rect = if let Some(text) = text {
            let layout = painter.layout(text.to_owned(), egui::FontId::new(12.0, egui::FontFamily::Monospace), color_text, f32::MAX);
            let icon_width = f32::ceil((layout.size().x + 10.0) / CMD_SIZE_VEC.x) * CMD_SIZE_VEC.x;
            text_layout = Some(layout);
            Rect::from_min_size(pos, Vec2 { x: f32::max(CMD_SIZE as f32, icon_width), y: CMD_SIZE as f32 })
        } else {
            Rect::from_min_size(pos, CMD_SIZE_VEC)
        };
        let icon_rect = Rect::from_center_size(rect.center(), CMD_ICON_SIZE_VEC);
        
        // Actual painting
        if do_paint {
            // Background
            if background != self.color_program_bg {
                painter.rect_filled(rect, 0.0, self.color_border);
                painter.rect_filled(rect.shrink(1.0), 0.0, background);
            }  else {
                painter.rect_filled(rect, 0.0, background);
            }
            // Icon
            if let Some(icon) = icon {
                let mut mesh = egui::Mesh::with_texture(icon.texture_id(painter.ctx()));
                mesh.add_rect_with_uv(
                    icon_rect,
                    Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
                    egui::Color32::WHITE);
                painter.add(egui::Shape::mesh(mesh));
            }
            // Text
            if let Some(text_layout) = text_layout {
                painter.galley(Pos2 {
                    x: pos.x + rect.width() / 2.0 - text_layout.size().x / 2.0,
                    y: pos.y + rect.height() / 2.0 - text_layout.size().y / 2.0 }, text_layout);
            }
        }

        rect
    }
    pub fn render_block(&self, block: &[Vec<Command>], painter: &egui::Painter, pos: Pos2, range: Option<std::ops::Range<usize>>) {
        for (y, line) in block.iter().enumerate() {
            if let Some(range) = &range {
                if !range.contains(&y) {
                    continue;
                }
            }
            let mut px = 0.0;
            for cmd in line.iter() {
                let cmdpos = Pos2::new(px , y as f32 * CMD_SIZE_VEC.y) + pos.to_vec2();
                let rendered_size = self.render_icon(cmd, painter, cmdpos, true);
                px += rendered_size.width();
            }
        }
    }

    pub fn layout_block(&self, block: &[Vec<Command>], painter: &egui::Painter, pos: Pos2) -> (Rect, Vec<Vec<f32>>) {
        let mut max = pos;
        let mut layout = vec![];
        for (y, line) in block.iter().enumerate() {
            let mut line_layout = vec![];
            let mut px = 0.0;
            for cmd in line.iter() {
                let rendered_size = self.render_icon(cmd, painter, Pos2::new(px , y as f32 * CMD_SIZE_VEC.y), false);
                px += rendered_size.width();
                line_layout.push(rendered_size.width());
            }
            max.x = f32::max(max.x, px);
            max.y = (y + 1) as f32 * CMD_SIZE_VEC.y;
            layout.push(line_layout);
        }
        (Rect::from_min_max(pos, max), layout)
    }
}

macro_rules! insert_cmd_icon_emmbeded {
    ( $map:expr, $name:expr, $file:expr ) => {
        $map.insert($name.to_owned(),
        egui_extras::RetainedImage::from_svg_bytes_with_size(
                $name, include_bytes!($file),
                egui_extras::image::FitTo::Size(CMD_ICON_SIZE, CMD_ICON_SIZE)).unwrap()
            .with_options(egui::TextureOptions::NEAREST));
    };
}

fn load_cmd_icons() -> HashMap<String, egui_extras::RetainedImage> {
    let mut map = HashMap::new();
    insert_cmd_icon_emmbeded!(map, "go", "../icons/go.svg");
    map
}