use emath::{Vec2, Pos2, Rect};

use crate::cmdrenderer::CMD_SIZE_VEC;

pub struct DnDCtl<T: DragData> {
    drag_data: Option<(Pos2, T)>,
    offset: Vec2,
    /// True if the data were dropped last frame
    dropped: bool,
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum DragAction {
    COPY,
    MOVE,
}

pub trait DragData {
    fn get_size(&mut self, painter: &egui::Painter) -> (Vec2, Vec2);
    fn get_action(&mut self) -> DragAction;
    fn drag_finish(&mut self);
    fn render(&mut self, painter: &egui::Painter, pos: Pos2);
}

impl<T: DragData> DnDCtl<T> {
    pub fn new() -> Self {
        Self {
            drag_data: None,
            offset: Vec2::new(0.0, 0.0),
            dropped: false
        }
    }

    pub fn ui(&mut self, ui: &mut egui::Ui) {
        if self.dropped {
            self.drag_data = None;
        }
        self.dropped = false;
        let mut pos = None;
        ui.input(|i| {
            if i.pointer.any_released() {
                return;
            }
            pos = i.pointer.interact_pos();
        });
        match &mut self.drag_data {
            Some(ref mut drag_data) => {
                match pos {
                    Some(pos) => {
                        let (size, offset) = drag_data.1.get_size(&ui.painter());
                        self.offset = offset;
                        drag_data.0 = pos + self.offset;
                        let rect = Rect::from_min_size(drag_data.0.round(), size);
                        let painter = ui.painter_at(rect);
                        drag_data.1.render(&painter, rect.min);
                    },
                    None => {
                        self.dropped = true;
                    }
                }
            }
            _ => (),
        }

    }

    pub fn drag_start(&mut self, ui: &mut egui::Ui, data: T) {
        ui.input(|i| {
            if let Some(pos) = i.pointer.interact_pos() {
                self.drag_data = Some((pos, data));
            } else {
                self.drag_data = None;
            }
        });
    }

    pub fn get_drag_data(&self) -> &Option<(Pos2, T)> {
        &self.drag_data
    }

    pub fn drag_receive(&mut self, rect: Rect) -> Option<(Pos2, T)> {
        match self.drag_data {
            Some(ref mut drag_data) => {
                if self.dropped && rect.contains(drag_data.0 - self.offset) {
                    drag_data.1.drag_finish();
                    Some((drag_data.0 - self.offset, self.drag_data.take().unwrap().1))
                } else {
                    None
                }
            },
            None => {
                None
            }
        }  
    }
}