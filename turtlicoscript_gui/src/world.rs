use std::sync::mpsc;
use std::collections::{HashMap};
use std::sync::{Arc, Mutex};
use egui_extras::RetainedImage;
use turtlicoscript::interpreter::CancellationToken;

use crate::WorldSyncState;
use crate::sprite::Sprite;


pub const NORMAL_SPEED: f32 = 32.0; // pixels per second
pub const NORMAL_SPEED_ROTATION: f32 = 90.0; // degrees per second
pub const BLOCK_SIZE_PX: f32 = 32.0;
pub const SCREEN_WIDTH: usize = 16;
pub const SCREEN_HEIGHT: usize = 10;
pub const SCREEN_WIDTH_PX: f32 = SCREEN_WIDTH as f32 * BLOCK_SIZE_PX;
pub const SCREEN_HEIGHT_PX: f32 = SCREEN_HEIGHT as f32 * BLOCK_SIZE_PX;

pub type SpriteID = u32;

pub struct World {
    pub sprites: HashMap<SpriteID, Sprite>,
    pub blocks: HashMap<String, egui_extras::RetainedImage>,
    last_anim_time: f64,
    pub update_tx: mpsc::Sender<WorldSyncState>,
    pub update_tx_closed: bool, // Interpreter disconnected
}

impl World {
    pub fn new(update_tx: mpsc::Sender<WorldSyncState>) -> Self {
        let map = HashMap::new();
        let mut s = Self {
            sprites: map,
            blocks: default_blocks(),
            last_anim_time: 0.0,
            update_tx,
            update_tx_closed: false,
        };
        s.add_sprite();
        s
    }
    pub fn new_arc_mutex(update_tx: mpsc::Sender<WorldSyncState>) -> Arc<Mutex<Self>> {
        Arc::new(Mutex::new(Self::new(update_tx)))
    }

    pub fn add_sprite(&mut self) -> SpriteID {
        let mut id = 0;
        while self.sprites.contains_key(&id) {
            id+= 1;
        }
        self.sprites.insert(id, Sprite::new());
        id
    }

    pub fn ui(&mut self, ui: &mut egui::Ui, cancellable: &Option<CancellationToken>) -> egui::Response {
        let avail_size = ui.available_size();
        let cam_scale = f32::max(f32::min(
            avail_size.x / SCREEN_WIDTH_PX,
            avail_size.y / SCREEN_HEIGHT_PX), 1.0);
        let _cam_block_size = cam_scale * BLOCK_SIZE_PX;
        let desired_size = egui::vec2(SCREEN_WIDTH_PX * cam_scale, SCREEN_HEIGHT_PX * cam_scale);

        let (world_rect, response) = ui.allocate_exact_size(desired_size, egui::Sense::click_and_drag());

        let default_block = self.blocks.get("turtle").unwrap();

        // Animations
        let mut current_time = 0.0;
        ui.ctx().input(|state|{
            current_time = state.time;
        });
        if self.last_anim_time == 0.0 {
            self.last_anim_time = current_time;
        }
        let delta = (current_time - self.last_anim_time) as f32;
        self.last_anim_time = current_time;
        for sprite in self.sprites.values_mut() {
            sprite.animate(delta);
        }
        let mut state = WorldSyncState::Update;
        if let Some(cancellable) = cancellable {
            if cancellable.load(std::sync::atomic::Ordering::Relaxed) {
                state = WorldSyncState::Cancelled;
            }
        }
        if let Err(_) = self.update_tx.send(state) {
            self.update_tx_closed = true;
        }
        ui.ctx().request_repaint();


        // Rendering
        if ui.is_rect_visible(world_rect) {
            let visuals = ui.style().noninteractive();
            //let world_rect = world_rect.expand(visuals.expansion);
            let wpainter = ui.painter().with_clip_rect(world_rect);
            wpainter
                .rect(world_rect, 0.0, egui::Color32::from_rgb(0, 0, 0), visuals.bg_stroke);

            for sprite in self.sprites.values() {
                let block = self.blocks.get(&sprite.block).unwrap_or(default_block);
                let sprite_rect = egui::Rect::from_min_size(
                    egui::Pos2 { x: sprite.rendered_x * cam_scale, y: sprite.rendered_y * cam_scale },
                    block.size_vec2() * cam_scale).translate(egui::vec2(world_rect.left(), world_rect.top()));
                let mut mesh = egui::Mesh::with_texture(block.texture_id(ui.ctx()));
                mesh.add_rect_with_uv(
                    sprite_rect,
                    egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
                    egui::Color32::WHITE);
                mesh.rotate(
                    emath::Rot2::from_angle(sprite.rendered_rot.to_radians()),
                    sprite_rect.min + egui::vec2(0.5, 0.5) * sprite_rect.size());
                    wpainter.add(egui::Shape::mesh(mesh));
            }
        }
       response
    }
}


fn default_blocks() -> HashMap<String, RetainedImage> {
    let mut map = HashMap::new();
    map.insert("turtle".to_owned(),
        RetainedImage::from_image_bytes("turtle", include_bytes!("../blocks/turtle.png")).unwrap()
        .with_options(egui::TextureOptions::NEAREST));
    map
}

pub fn normalize_angle(angle: f32) -> f32 {
    let angle = angle % 360.0;
    if angle < 0.0 { 360.0 + angle } else { angle }
}