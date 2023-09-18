use std::{collections::HashMap, sync::Arc};
use emath::{Rect, Vec2, Pos2};
use turtlicoscript::tokens::Token;

use crate::project::{Command, Project};

pub const CMD_SIZE: u32 = 36;
pub const CMD_SIZE_VEC: Vec2 = Vec2::new(CMD_SIZE as f32, CMD_SIZE as f32);
pub const CMD_ICON_SIZE: u32 = 32;
pub const CMD_ICON_SIZE_VEC: Vec2 = Vec2::new(CMD_ICON_SIZE as f32, CMD_ICON_SIZE as f32);

pub struct CommandRenderer {
    funcs_icons: HashMap<String, egui_extras::RetainedImage>,
    var_icons: HashMap<String, egui_extras::RetainedImage>,
    token_icons: HashMap<Token, egui_extras::RetainedImage>,
    token_text_icons: HashMap<Token, &'static str>,
    color_bg: egui::Color32,
    color_border: egui::Color32,
    pub color_program_bg: egui::Color32,
    pub color_program_fg: egui::Color32,
    color_block_bg: egui::Color32,
    color_text: egui::Color32,
    color_text_dark: egui::Color32,
    color_token_text_icon: egui::Color32,
    color_func: egui::Color32,
    color_var: egui::Color32,
    color_int: egui::Color32,
    color_string: egui::Color32,
    color_float: egui::Color32,
}

impl CommandRenderer {
    pub fn new() -> Self {
        Self {
            funcs_icons: load_funcs_icons(),
            var_icons: load_vars_icons(),
            token_icons: load_token_icons(),
            token_text_icons: token_text_icons(),
            color_bg: egui::Color32::from_rgb(255, 179, 0),
            color_border: egui::Color32::from_rgb(20, 20, 0),
            color_program_bg: egui::Color32::from_rgb(255, 255, 255),
            color_program_fg: egui::Color32::from_rgb(0, 0, 0),
            color_block_bg: egui::Color32::from_rgb(127, 127, 127),
            color_text: egui::Color32::from_rgb(255, 255, 255),
            color_text_dark: egui::Color32::from_rgb(0, 0, 0),
            color_token_text_icon: egui::Color32::from_rgb(0, 0, 255),
            color_func: egui::Color32::from_rgb(220, 138, 221),
            color_var: egui::Color32::from_rgb(154, 153, 150),
            color_int: egui::Color32::from_rgb(28, 113, 216),
            color_string: egui::Color32::from_rgb(249, 240, 107),
            color_float: egui::Color32::from_rgb(51, 209, 122),
        }
    }
    pub fn render_icon(&self, cmd: &Command, project: &Project, painter: &egui::Painter, pos: Pos2, do_paint: bool) -> Rect {
        let mut background = self.color_bg;
        let mut icon: Option<&egui_extras::RetainedImage> = None;

        let mut text: Option<&str> = None;
        let mut text_owned: String = String::new();
        let mut text_layout: Option<Arc<egui::Galley>> = None;
        let mut text_size = 12.0;
        let mut color_text = self.color_text;

        match cmd {
            Command::Comment(value) => {
                if value.is_empty() {
                    text = Some("#");
                    text_size = 18.0;
                } else {
                    text = Some(value);
                }
                background = egui::Color32::from_rgb(100, 100, 100);
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
                    Token::Image(name) => {
                        background = self.color_block_bg;
                        if let Some(image) = project.blocks.get(name) {
                            icon = Some(image);
                        } else if let Some(image) = project.default_blocks.get(name) {
                            icon = Some(image);
                        } else if name.starts_with("./") {
                            text = Some(name)
                        } else {
                            text = Some(name)
                        }
                    },
                    Token::Variable(name) => {
                        match self.var_icons.get(name) {
                            Some(image) => {
                                icon = Some(image);
                            } None => {
                                background = self.color_var;
                                text = Some(name);
                            }
                        }
                    },
                    Token::Function(name) => {
                        match self.funcs_icons.get(name) {
                            Some(image) => {
                                icon = Some(image);
                            },
                            None => {
                                background = self.color_func;
                                if name.is_empty() {
                                    icon = Some(self.token_icons.get(&Token::FnDef).unwrap());
                                } else {
                                    text = Some(name);
                                }
                            }
                        }
                    },
                    Token::String(value) => {
                        background = self.color_string;
                        text = Some(value);
                        color_text = self.color_text_dark;
                    },
                    Token::Integer(value) => {
                        background = self.color_int;
                        text_owned = format!("{}", value);
                    },
                    Token::Float(value) => {
                        background = self.color_float;
                        text = Some(value);
                    },
                    token => {
                        if let Some(token_icon) = self.token_icons.get(token) {
                            icon = Some(token_icon);
                        }
                        if let Some(token_text) = self.token_text_icons.get(token) {
                            text = Some(token_text);
                            color_text = self.color_token_text_icon;
                            text_size = 18.0;
                        }
                    }
                }
            }
        }
        if !text_owned.is_empty() {
            text = Some(&text_owned)
        }
        // Calculate sizes
        let rect = if let Some(text) = text {
            let layout = painter.layout(text.to_owned(), egui::FontId::new(text_size, egui::FontFamily::Monospace), color_text, f32::MAX);
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
    pub fn render_block(&self, block: &[Vec<Command>], project: &Project, painter: &egui::Painter, pos: Pos2, range: Option<std::ops::Range<usize>>) {
        for (y, line) in block.iter().enumerate() {
            if let Some(range) = &range {
                if !range.contains(&y) {
                    continue;
                }
            }
            let mut px = 0.0;
            for cmd in line.iter() {
                let cmdpos = Pos2::new(px , y as f32 * CMD_SIZE_VEC.y) + pos.to_vec2();
                let rendered_size = self.render_icon(cmd, project, painter, cmdpos, true);
                px += rendered_size.width();
            }
        }
    }

    pub fn layout_block(&self, block: &[Vec<Command>], project: &Project, painter: &egui::Painter, pos: Pos2) -> (Rect, Vec<Vec<f32>>) {
        let mut max = pos;
        let mut layout = vec![];
        for (y, line) in block.iter().enumerate() {
            let mut line_layout = vec![];
            let mut px = 0.0;
            for cmd in line.iter() {
                let rendered_size = self.render_icon(cmd, project, painter, Pos2::new(px , y as f32 * CMD_SIZE_VEC.y), false);
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

macro_rules! insert_func_icon_emmbeded {
    ( $map:expr, $name:expr, $file:expr ) => {
        $map.insert($name.to_owned(),
        egui_extras::RetainedImage::from_svg_bytes_with_size(
                $name, include_bytes!($file),
                egui_extras::image::FitTo::Size(CMD_ICON_SIZE, CMD_ICON_SIZE)).unwrap()
            .with_options(egui::TextureOptions::NEAREST));
    };
}

macro_rules! insert_token_icon_emmbeded {
    ( $map:expr, $token:expr, $file:expr ) => {
        $map.insert($token,
        egui_extras::RetainedImage::from_svg_bytes_with_size(
                format!("{:?}", $token), include_bytes!($file),
                egui_extras::image::FitTo::Size(CMD_ICON_SIZE, CMD_ICON_SIZE)).unwrap()
            .with_options(egui::TextureOptions::NEAREST));
    };
}

fn load_funcs_icons() -> HashMap<String, egui_extras::RetainedImage> {
    let mut map = HashMap::new();
    insert_func_icon_emmbeded!(map, "destroy_block", "../icons/destroy_block.svg");
    insert_func_icon_emmbeded!(map, "go", "../icons/go.svg");
    insert_func_icon_emmbeded!(map, "left", "../icons/left.svg");
    insert_func_icon_emmbeded!(map, "new_turtle", "../icons/new_turtle.svg");
    insert_func_icon_emmbeded!(map, "place_block", "../icons/place_block.svg");
    insert_func_icon_emmbeded!(map, "right", "../icons/right.svg");
    insert_func_icon_emmbeded!(map, "set_rot", "../icons/set_rot.svg");
    insert_func_icon_emmbeded!(map, "set_target_xy_px", "../icons/set_target_xy_px.svg");
    insert_func_icon_emmbeded!(map, "set_target_xy", "../icons/set_target_xy.svg");
    insert_func_icon_emmbeded!(map, "set_xy_px", "../icons/set_xy_px.svg");
    insert_func_icon_emmbeded!(map, "set_xy", "../icons/set_xy.svg");
    insert_func_icon_emmbeded!(map, "skin", "../icons/skin.svg");
    insert_func_icon_emmbeded!(map, "speed", "../icons/speed.svg");
    insert_func_icon_emmbeded!(map, "wait", "../icons/wait.svg");
    map
}

fn load_vars_icons() -> HashMap<String, egui_extras::RetainedImage> {
    let mut map = HashMap::new();
    insert_func_icon_emmbeded!(map, "block_xy", "../icons/block_xy.svg");
    map
}

fn load_token_icons() -> HashMap<Token, egui_extras::RetainedImage> {
    let mut map = HashMap::new();
    insert_token_icon_emmbeded!(map, Token::Break, "../icons/break.svg");
    insert_token_icon_emmbeded!(map, Token::FnDef, "../icons/fndef.svg");
    insert_token_icon_emmbeded!(map, Token::For, "../icons/for.svg");
    insert_token_icon_emmbeded!(map, Token::If, "../icons/if.svg");
    insert_token_icon_emmbeded!(map, Token::Else, "../icons/else.svg");
    insert_token_icon_emmbeded!(map, Token::Loop, "../icons/loop.svg");
    insert_token_icon_emmbeded!(map, Token::Return, "../icons/return.svg");
    insert_token_icon_emmbeded!(map, Token::While, "../icons/while.svg");
    map
}

fn token_text_icons() -> HashMap<Token, &'static str> {
    let mut map = HashMap::new();
    map.insert(Token::Assignment, "=");
    map.insert(Token::Colon, ":");
    map.insert(Token::Comma, ",");
    map.insert(Token::Dot, ".");
    map.insert(Token::Eq, "==");
    map.insert(Token::Gt, ">");
    map.insert(Token::Gte, ">=");
    map.insert(Token::LeftCurly, "{");
    map.insert(Token::LeftParent, "(");
    map.insert(Token::LeftSquare, "[");
    map.insert(Token::Lt, "<");
    map.insert(Token::Lte, "<=");
    map.insert(Token::Minus, "-");
    map.insert(Token::Neq, "!=");
    map.insert(Token::Plus, "+");
    map.insert(Token::RightCurly, "}");
    map.insert(Token::RightParent, ")");
    map.insert(Token::RightSquare, "]");
    map.insert(Token::Slash, "/");
    map.insert(Token::Star, "*");
    map
}