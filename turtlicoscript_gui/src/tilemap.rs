use ndarray::Array2;
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Clone)]
pub struct Tilemap {
    pub tiles: Array2<Option<String>>,
}

impl Tilemap {
    pub fn new(width: usize, height: usize) -> Self {
        Self {
            tiles: Array2::from_elem((width, height), None),
        }
    }

    pub fn get_width(&self) -> usize {
        self.tiles.dim().0
    }

    pub fn get_height(&self) -> usize {
        self.tiles.dim().1
    }

    pub fn get_block(&mut self, x: usize, y: usize) -> Option<String> {
        let dim = self.tiles.dim();
        if x < dim.0 && y < dim.1 {
            self.tiles[(x, y)].clone()
        } else {
            None
        }
    }

    pub fn set_block(&mut self, x: usize, y: usize, id: Option<String>) {
        self.tiles[(x, y)] = id;
    }
}