use std::collections::HashMap;
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

pub struct Project {
    pub modify_timestamp: std::time::Instant,
    pub program: Vec<Vec<Command>>,
    
    /// File system path of the project (if applicable)
    pub path: Option<String>,
    /// Project emmbeded files (blocks etc.)
    pub files: HashMap<String, Vec<u8>>,
    blocks: HashMap<String, egui_extras::RetainedImage>,
    
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
            modify_timestamp: std::time::Instant::now(),
            program: Vec::new(),
            path: None,
            files: HashMap::new(),
            blocks: HashMap::new(),
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

    fn insert_single(&mut self, cmd: Command, mut col: usize, mut row: usize) {
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
                        let following_newline: Vec<_> = self.program[row].drain(col..row_len).collect();
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
        self.program[row].insert(usize::min(row_len, col), cmd);
    }

    pub fn insert(&mut self, block: Vec<Vec<Command>>, col: usize, row: usize) {
        for line in block.iter().rev() {
            for cmd in line.iter().rev() {
                self.insert_single(cmd.clone(), col, row);
            }
        }
        self.modify_timestamp = std::time::Instant::now();
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
        self.modify_timestamp = std::time::Instant::now();
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
            ]
        }
    );
    // Control commands

    pv
}
