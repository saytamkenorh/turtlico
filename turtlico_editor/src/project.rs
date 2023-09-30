use std::collections::{HashMap, BTreeMap};
use serde::{Serialize, Deserialize, Serializer};
use serde::ser::SerializeStruct;

use turtlicoscript::tokens::Token;

use crate::cmdrenderer::CommandRenderer;


macro_rules! get_is_token {
    ($cmd:expr, $token:ident) => {
        if let Command::Token(token) = &$cmd  {
            match token {
                turtlicoscript::tokens::Token::$token => {
                    true
                },
                _ => {false}
            }
        } else {false}
    };
}

macro_rules! plugin_icon {
    ( $file:expr ) => {
        egui_extras::RetainedImage::from_svg_bytes_with_size(
                $file, include_bytes!($file),
                egui_extras::image::FitTo::Size(crate::app::BTN_ICON_SIZE, crate::app::BTN_ICON_SIZE)
            )
            .unwrap()
            .with_options(egui::TextureOptions::NEAREST)
    };
}

pub(crate) use plugin_icon;

pub struct Project {
    pub modify_timestamp: chrono::DateTime<chrono::Local>,
    pub program: Vec<Vec<Command>>,
    
    /// File system path of the project (if applicable)
    pub path: Option<String>,
    /// Project emmbeded files (blocks etc.)
    pub files: HashMap<String, Vec<u8>>,
    pub blocks: HashMap<String, egui_extras::RetainedImage>,
    pub default_blocks: BTreeMap<String, egui_extras::RetainedImage>,
    
    pub renderer: CommandRenderer,
    pub plugins: Vec<Plugin>,
}

pub struct Plugin {
    pub name: &'static str,
    pub icon: egui_extras::RetainedImage,
    pub commands: Vec<Command>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub enum Command {
    Comment(String),
    Token(Token)
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub struct CommandRange {
    pub start: (usize, usize),
    pub end: (usize, usize),
}

impl Project {
    pub fn empty() -> Self {
        Self {
            modify_timestamp: chrono::Local::now(),
            program: Vec::new(),
            path: None,
            files: HashMap::new(),
            blocks: HashMap::new(),
            default_blocks: turtlicoscript_gui::world::default_blocks(),
            renderer: CommandRenderer::new(),
            plugins: get_cmd_plugins(),
        }
    }

    pub fn get_plugin(&self, name: &str) -> Option<&Plugin> {
        for plugin in self.plugins.iter() {
            if plugin.name == name {
                return Some(&plugin);
            }
        }
        None
    }

    fn insert_single(&mut self, cmd: Command, mut col: usize, mut row: usize, extra_insert: bool) {
        if row >= self.program.len() {
            self.program.push(vec![Command::Token(Token::Newline)]);
            if get_is_token!(cmd, Newline) {
                return;
            }
            row = self.program.len() - 1;
        }
        if let Command::Token(token) = &cmd  {
            match token {
                Token::Newline => {
                    // Split lines
                    let row_len = self.program[row].len();
                    if col >= row_len {
                        self.program.insert(row + 1, vec![Command::Token(Token::Newline)]);
                    } else {
                        let mut following_newline: Vec<_> = self.program[row].drain(col..row_len).collect();
                        if let Some(cmd) = self.program[row].last() {
                            if get_is_token!(cmd, LeftCurly) && !matches!(following_newline.first(), Some(Command::Token(Token::RightCurly))) {
                                following_newline.insert(0, Command::Token(Token::Space));   
                            }
                        }
                        for cmd in self.program[row].iter() {
                            if !get_is_token!(cmd, Space) {
                                break;   
                            }
                            following_newline.insert(0, Command::Token(Token::Space));
                        };
                        self.program[row].push(Command::Token(Token::Newline));
                        self.program.insert(row + 1, following_newline);
                    }
                    return;
                },
                _ => {}
            }
        }
        let row_len = self.program[row].len();
        if col >= row_len && row_len > 0 && get_is_token!(self.program[row].last().unwrap(), Newline) {
            col = row_len - 1;
        }
        if extra_insert {
            if get_is_token!(cmd, LeftCurly) {
                self.program[row].insert(usize::min(row_len, col), Command::Token(Token::RightCurly));
            }
            if get_is_token!(cmd, LeftParent) {
                self.program[row].insert(usize::min(row_len, col), Command::Token(Token::RightParent));
            }
            if get_is_token!(cmd, LeftSquare) {
                self.program[row].insert(usize::min(row_len, col), Command::Token(Token::RightSquare));
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
        if self.program[row].len() == 0 {
            self.program.remove(row);
        } else {
            if !get_is_token!(self.program[row].last().unwrap(), Newline) {
                self.program[row].push(Command::Token(Token::Newline));
            }
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
}

impl Serialize for Project {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        // 3 is the number of fields in the struct.
        let mut state = serializer.serialize_struct("Project", 3)?;
        state.serialize_field("program", &self.program)?;
        state.serialize_field("files", &self.files)?;
        state.serialize_field("plugins", &self.plugins.iter().map(|p| p.name).collect::<Vec<&str>>())?;
        state.end()
    }
}

impl CommandRange {
    pub fn single_icon(col: usize, row: usize) -> Self {
        Self { start: (col, row), end: (col, row) }
    }
}

fn get_cmd_plugins() -> Vec<Plugin> {
    let mut pv = Vec::new();

    // Turtle
    pv.push(
        Plugin {
            name: "turtle",
            icon: plugin_icon!("../icons/turtlico.svg"),
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
            ]
        }
    );
    // Control commands
    pv.push(
        Plugin {
            name: "control",
            icon: plugin_icon!("../icons/plugin_control.svg"),
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
            ]
        }
    );

    pv
}
