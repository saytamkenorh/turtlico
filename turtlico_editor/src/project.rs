use egui::load::SizedTexture;
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, HashMap};

use turtlicoscript::tokens::Token;
use turtlicoscript_gui::{
    tilemap::Tilemap,
    world::{SCREEN_HEIGHT, SCREEN_WIDTH},
};

use crate::cmdrenderer::CommandRenderer;

macro_rules! get_is_token {
    ($cmd:expr, $token:ident) => {
        if let Command::Token(token) = &$cmd {
            match token {
                turtlicoscript::tokens::Token::$token => true,
                _ => false,
            }
        } else {
            false
        }
    };
}

macro_rules! plugin_icon {
    ( $file:expr, $ctx:expr ) => {
        turtlicoscript_gui::world::load_texture_from_bytes(
            $ctx,
            include_bytes!($file),
            std::path::Path::new($file)
                .extension()
                .unwrap()
                .to_str()
                .unwrap(),
            egui::load::SizeHint::Size(
                crate::widgets::BTN_ICON_SIZE,
                crate::widgets::BTN_ICON_SIZE,
            ),
        )
        .unwrap()
    };
}

pub(crate) use plugin_icon;

#[derive(Serialize, Deserialize)]
pub struct Project {
    #[serde(skip, default = "chrono::Local::now")]
    pub modify_timestamp: chrono::DateTime<chrono::Local>,
    pub program: Vec<Vec<Command>>,

    /// Project emmbeded files (images etc.)
    pub files: HashMap<String, Vec<u8>>,
    /// Project emmbeded tilemaps
    #[serde(default)]
    pub tilemaps: HashMap<String, Tilemap>,
    #[serde(skip)]
    pub blocks: HashMap<String, SizedTexture>,
    #[serde(skip)]
    pub default_blocks: BTreeMap<String, SizedTexture>,

    #[serde(skip)]
    pub renderer: Option<CommandRenderer>,
    #[serde(skip)]
    pub plugins: Vec<Plugin>,
}

pub struct Plugin {
    pub name: &'static str,
    pub icon: egui::load::SizedTexture,
    pub commands: Vec<Command>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub enum Command {
    Comment(String),
    Token(Token),
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub struct CommandRange {
    pub start: (usize, usize),
    pub end: (usize, usize),
}

impl Project {
    pub fn empty(ctx: &egui::Context) -> Self {
        Self {
            modify_timestamp: chrono::Local::now(),
            program: Vec::new(),
            files: HashMap::new(),
            blocks: HashMap::new(),
            tilemaps: HashMap::new(),
            default_blocks: BTreeMap::from_iter(
                turtlicoscript_gui::world::World::default_blocks(ctx),
            ),
            renderer: Some(CommandRenderer::new(ctx)),
            plugins: get_cmd_plugins(ctx),
        }
    }

    pub fn from_str(data: &str, ctx: &egui::Context) -> Result<Self, serde_json::Error> {
        let mut proj: Project = serde_json::from_str(data)?;

        proj.plugins = get_cmd_plugins(ctx);
        proj.default_blocks =
            BTreeMap::from_iter(turtlicoscript_gui::world::World::default_blocks(ctx));
        proj.renderer = Some(CommandRenderer::new(ctx));

        Ok(proj)
    }

    pub fn get_plugin(&self, name: &str) -> Option<&Plugin> {
        self.plugins.iter().find(|&plugin| plugin.name == name)
    }

    pub fn save(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(self)
    }

    fn insert_single(&mut self, cmd: Command, mut col: usize, mut row: usize, extra_insert: bool) {
        if row >= self.program.len() {
            self.program.push(vec![Command::Token(Token::Newline)]);
            if get_is_token!(cmd, Newline) {
                return;
            }
            row = self.program.len() - 1;
        }
        if let Command::Token(token) = &cmd {
            if token == &Token::Newline {
                // Split lines
                let row_len = self.program[row].len();
                if col >= row_len {
                    self.program
                        .insert(row + 1, vec![Command::Token(Token::Newline)]);
                } else {
                    let mut following_newline: Vec<_> =
                        self.program[row].drain(col..row_len).collect();
                    if let Some(cmd) = self.program[row].last() {
                        if get_is_token!(cmd, LeftCurly)
                            && !matches!(
                                following_newline.first(),
                                Some(Command::Token(Token::RightCurly))
                            )
                        {
                            following_newline.insert(0, Command::Token(Token::Space));
                        }
                    }
                    for cmd in self.program[row].iter() {
                        if !get_is_token!(cmd, Space) {
                            break;
                        }
                        following_newline.insert(0, Command::Token(Token::Space));
                    }
                    self.program[row].push(Command::Token(Token::Newline));
                    self.program.insert(row + 1, following_newline);
                }
                return;
            }
        }
        let row_len = self.program[row].len();
        if col >= row_len
            && row_len > 0
            && get_is_token!(self.program[row].last().unwrap(), Newline)
        {
            col = row_len - 1;
        }
        if extra_insert {
            if get_is_token!(cmd, LeftCurly) {
                self.program[row]
                    .insert(usize::min(row_len, col), Command::Token(Token::RightCurly));
            }
            if get_is_token!(cmd, LeftParent) {
                self.program[row]
                    .insert(usize::min(row_len, col), Command::Token(Token::RightParent));
            }
            if get_is_token!(cmd, LeftSquare) {
                self.program[row]
                    .insert(usize::min(row_len, col), Command::Token(Token::RightSquare));
            }
        }
        self.program[row].insert(usize::min(row_len, col), cmd);
    }

    pub fn insert(&mut self, block: Vec<Vec<Command>>, col: usize, row: usize) {
        let extra_insert = block.len() == 1 && block[0].len() == 1;
        for line in block.iter().rev() {
            for cmd in line.iter().rev() {
                self.insert_single(cmd.clone(), col, row, extra_insert);
            }
        }
        self.modify_timestamp = chrono::Local::now();
    }

    fn delete_single(&mut self, col: usize, row: usize) {
        if get_is_token!(self.program[row][col], Newline) {
            self.program[row].remove(col);
            if row < self.program.len() - 1 {
                let next_line = self.program.remove(row + 1);
                self.program[row].extend(next_line);
            }
        } else {
            self.program[row].remove(col);
        }
        if self.program[row].is_empty() {
            self.program.remove(row);
        } else if !get_is_token!(self.program[row].last().unwrap(), Newline) {
            self.program[row].push(Command::Token(Token::Newline));
        }
    }

    pub fn delete(&mut self, range: CommandRange) {
        for y in (range.start.1..=range.end.1).rev() {
            let start = if y == range.start.1 { range.start.0 } else { 0 };
            let end = if y == range.end.1 { range.end.0 } else { 0 };
            for x in (start..=end).rev() {
                self.delete_single(x, y);
            }
        }
        self.modify_timestamp = chrono::Local::now();
    }

    pub fn new_tilemap(&mut self) -> String {
        let tilemap = Tilemap::new(SCREEN_WIDTH, SCREEN_HEIGHT);
        let mut id = 0;
        while self.tilemaps.contains_key(&format!("Tile map {}", id)) {
            id += 1;
        }
        let name = format!("Tile map {}", id);
        self.tilemaps.insert(name.clone(), tilemap);
        name
    }

    pub fn remove_tilemap(&mut self, name: &str) {
        for y in (0..self.program.len()).rev() {
            for x in (0..self.program[y].len()).rev() {
                if let Command::Token(Token::Tilemap(val)) = &self.program[y][x] {
                    if val == name {
                        self.program[y].remove(x);
                    }
                }
            }
        }
        self.tilemaps.remove(name);
    }
}

impl CommandRange {
    pub fn single_icon(col: usize, row: usize) -> Self {
        Self {
            start: (col, row),
            end: (col, row),
        }
    }
}

fn get_cmd_plugins(ctx: &egui::Context) -> Vec<Plugin> {
    let mut pv = Vec::new();

    // Turtle
    pv.push(Plugin {
        name: "turtle",
        icon: plugin_icon!("../icons/turtlico.svg", ctx),
        commands: vec![
            Command::Token(Token::Newline),
            Command::Token(Token::Space),
            Command::Token(Token::Function("place_block".to_owned())),
            Command::Token(Token::Function("destroy_block".to_owned())),
            Command::Token(Token::Function("go".to_owned())),
            Command::Token(Token::Function("left".to_owned())),
            Command::Token(Token::Function("right".to_owned())),
            Command::Token(Token::Function("wait".to_owned())),
            Command::Token(Token::Function("set_xy".to_owned())),
            Command::Token(Token::Function("set_xy_px".to_owned())),
            Command::Token(Token::Function("set_target_xy".to_owned())),
            Command::Token(Token::Function("set_target_xy_px".to_owned())),
            Command::Token(Token::Variable("block_xy".to_owned())),
            Command::Token(Token::Function("set_rot".to_owned())),
            Command::Token(Token::Function("speed".to_owned())),
            Command::Token(Token::Function("skin".to_owned())),
            Command::Token(Token::Function("new_turtle".to_owned())),
            Command::Token(Token::Function("update_events".to_owned())),
            Command::Token(Token::Key("A".to_owned())),
            Command::Token(Token::Function("key_pressed".to_owned())),
            Command::Token(Token::Function("key_down".to_owned())),
        ],
    });
    // Control commands
    pv.push(Plugin {
        name: "control",
        icon: plugin_icon!("../icons/plugin_control.svg", ctx),
        commands: vec![
            Command::Token(Token::Loop),
            Command::Token(Token::For),
            Command::Token(Token::While),
            Command::Token(Token::Break),
            Command::Token(Token::If),
            Command::Token(Token::Else),
            Command::Token(Token::FnDef),
            Command::Token(Token::Return),
            Command::Token(Token::Variable("x".to_owned())),
            Command::Token(Token::Function("".to_owned())),
            Command::Token(Token::Assignment),
            Command::Token(Token::Dot),
            Command::Token(Token::String("str".to_owned())),
            Command::Token(Token::Integer(0)),
            Command::Token(Token::Float("0.0".to_owned())),
            Command::Token(Token::Colon),
            Command::Token(Token::LeftCurly),
            Command::Token(Token::RightCurly),
            Command::Token(Token::LeftSquare),
            Command::Token(Token::RightSquare),
            Command::Token(Token::Plus),
            Command::Token(Token::Minus),
            Command::Token(Token::Star),
            Command::Token(Token::Slash),
            Command::Token(Token::Lt),
            Command::Token(Token::Gt),
            Command::Token(Token::Lte),
            Command::Token(Token::Gte),
            Command::Token(Token::LeftParent),
            Command::Token(Token::RightParent),
            Command::Token(Token::Eq),
            Command::Token(Token::Neq),
            Command::Token(Token::Comma),
            Command::Comment("".to_owned()),
        ],
    });

    pv
}
