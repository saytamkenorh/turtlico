use std::collections::hash_map::RandomState;
use std::sync::mpsc::{self, Receiver};
use std::collections::{HashMap, HashSet, BTreeMap};
use std::sync::{Arc, Mutex};
use egui::Key;
use ndarray::prelude::*;
use turtlicoscript::interpreter::CancellationToken;

use crate::WorldSyncState;
use crate::sprite::Sprite;


pub const NORMAL_SPEED: f32 = 64.0; // pixels per second
pub const NORMAL_SPEED_ROTATION: f32 = 180.0; // degrees per second
pub const BLOCK_SIZE_PX: f32 = 32.0;
pub const SCREEN_WIDTH: usize = 16;
pub const SCREEN_HEIGHT: usize = 10;
pub const SCREEN_WIDTH_PX: f32 = SCREEN_WIDTH as f32 * BLOCK_SIZE_PX;
pub const SCREEN_HEIGHT_PX: f32 = SCREEN_HEIGHT as f32 * BLOCK_SIZE_PX;
pub const LONG_PRESS_DURATION: f64 = 1.5;

macro_rules! insert_block_embedded {
    ( $map:expr, $ctx:expr, $name:expr, $file:expr ) => {
        World::load_block_bytes(
            &mut $map, $ctx, $name, include_bytes!($file),
            std::path::Path::new($file).extension().unwrap().to_str().unwrap()
        ).unwrap();
    };
}

pub type SpriteID = u32;
pub type BlockTextures = HashMap<String, egui::load::SizedTexture>;

pub enum BlockTextureError {
    LoadError(egui::load::LoadError),
    UnknownBlock,
}

pub struct World {
    pub sprites: HashMap<SpriteID, Sprite>,
    pub blocks: BlockTextures,
    blocks_load_default: bool,
    pub block_map: Array3<Option<String>>,
    
    last_anim_time: f64,
    pub update_tx: mpsc::Sender<WorldSyncState>,
    pub update_tx_closed: bool, // Interpreter disconnected
    pub script_dir: Option<String>,

    pub keys_down: HashSet<Key, RandomState>,
    pub primary_ptr_down: bool,
    pub secondary_ptr_down: bool,
}

impl World {
    pub fn new(update_tx: mpsc::Sender<WorldSyncState>) -> Self {
        let map = HashMap::new();
        let block_map_depth = 3;
        let s = Self {
            sprites: map,
            blocks: HashMap::new(),
            blocks_load_default: true,
            block_map: Array::from_elem((SCREEN_WIDTH, SCREEN_HEIGHT, block_map_depth), None),

            last_anim_time: 0.0,
            update_tx,
            update_tx_closed: false,
            script_dir: None,
            
            keys_down: HashSet::new(),
            primary_ptr_down: false,
            secondary_ptr_down: false,
        };
        s
    }
    pub fn new_arc_mutex(update_tx: mpsc::Sender<WorldSyncState>, script_dir: Option<String>) -> Arc<Mutex<Self>> {
        let mut world = Self::new(update_tx);
        world.script_dir = script_dir;
        Arc::new(Mutex::new(world))
    }

    pub fn add_sprite(&mut self) -> SpriteID {
        let mut id = 0;
        while self.sprites.contains_key(&id) {
            id+= 1;
        }
        self.sprites.insert(id, Sprite::new());
        id
    }

    pub fn get_block(&mut self, name: &str) -> Result<String, turtlicoscript::error::RuntimeError> {
        if self.blocks.contains_key(name) {
            return Ok(name.to_owned());
        }
        if name.starts_with("./") && !self.blocks.contains_key(name) {
            if let Some(project_dir) = &self.script_dir {
                let path = std::path::Path::new(&project_dir).join(&name[2..]);
                if path.exists() {
                    return Ok(name.to_owned());
                }
            }
        }
        Err(turtlicoscript::error::RuntimeError::InvalidBlock(name.to_owned()))
    }

    fn get_block_texture<'a>(blocks: &'a mut BlockTextures, script_dir: &Option<String>, ctx: &'a egui::Context, name: &'a str) -> Result<&'a egui::load::SizedTexture, BlockTextureError> {
        if blocks.contains_key(name) {
            return Ok(blocks.get(name).unwrap());
        }
        if name.starts_with("./") {
            if let Some(project_dir) = script_dir {
                let path = std::path::Path::new(&project_dir).join(&name[2..]);
                if path.exists() {
                    match Self::load_block_file(blocks, ctx, name, &path.into_os_string().into_string().unwrap()) {
                        Ok(_) => {},
                        Err(err) => {
                            return Err(BlockTextureError::LoadError(err));
                        }
                    }
                }
            }
        }
        Err(BlockTextureError::UnknownBlock)
    }

    pub fn ui(&mut self, ui: &mut egui::Ui, cancellable: &Option<CancellationToken>) -> egui::Response {
        if self.blocks_load_default {
            self.blocks = Self::default_blocks(ui.ctx());
            self.blocks_load_default = false;
        }
        
        let avail_size = ui.available_size();
        let cam_scale = f32::max(f32::min(
            avail_size.x / SCREEN_WIDTH_PX,
            avail_size.y / SCREEN_HEIGHT_PX), 1.0);
        let _cam_block_size = cam_scale * BLOCK_SIZE_PX;
        let desired_size = egui::vec2(SCREEN_WIDTH_PX * cam_scale, SCREEN_HEIGHT_PX * cam_scale);

        let (world_rect, response) = ui.allocate_exact_size(desired_size, egui::Sense::click_and_drag());

        let default_block = *self.blocks.get("turtle").unwrap();
        let script_dir = self.script_dir.clone();

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
                .rect(world_rect, 0.0, egui::Color32::from_rgb(255, 255, 255), visuals.bg_stroke);

            // Blocks
            for z in (0..self.block_map.len_of(Axis(2))).rev() {
                for x in 0..self.block_map.len_of(Axis(0)) {
                    for y in 0..self.block_map.len_of(Axis(1)) {
                        let block_name = self.block_map.get((x, y, z)).unwrap();
                        if let Some(block_name) = block_name {
                            let block = self.blocks.get(block_name).unwrap_or(&default_block);
                            let x = x as f32 * BLOCK_SIZE_PX;
                            let y = y as f32 * BLOCK_SIZE_PX;
                            self.render_block(&wpainter, block, x, y, 0.0, cam_scale);
                        }
                    }
                }
            }
            // Graphics
            // Sprites
            for sprite in self.sprites.values() {
                // let block = self.blocks.get(&sprite.skin).unwrap_or(default_block);
                let block = Self::get_block_texture(&mut self.blocks, &script_dir, ui.ctx(), &sprite.skin).unwrap_or(&default_block).clone();
                self.render_block(&wpainter, &block, sprite.rendered_x, sprite.rendered_y, sprite.rendered_rot, cam_scale);
            }
        }

        // Input
        self.primary_ptr_down = response.clicked_by(egui::PointerButton::Primary);

        ui.input(|i| {
            let long_touch = i.pointer.button_down(egui::PointerButton::Primary) &&
             match i.pointer.press_start_time() {
                Some(start_time) => {
                    f64::abs(i.time - start_time) >= LONG_PRESS_DURATION
                },
                None => {false}
            };
            self.secondary_ptr_down = response.clicked_by(egui::PointerButton::Secondary) || long_touch;
            self.keys_down =  i.keys_down.clone();
        });

       response
    }

    pub fn render_block(&self, painter: &egui::Painter, block: &egui::load::SizedTexture, x: f32, y: f32, rot: f32, cam_scale: f32) {
        let rect = egui::Rect::from_min_size(
            egui::Pos2 { x: x * cam_scale, y: y * cam_scale },
            block.size * cam_scale).translate(egui::vec2(painter.clip_rect().left(), painter.clip_rect().top()));
        let mut mesh = egui::Mesh::with_texture(block.id);
        mesh.add_rect_with_uv(
            rect,
            egui::Rect::from_min_max(egui::pos2(0.0, 0.0), egui::pos2(1.0, 1.0)),
            egui::Color32::WHITE);
        mesh.rotate(
            emath::Rot2::from_angle(rot.to_radians()),
            rect.min + egui::vec2(0.5, 0.5) * rect.size());
        painter.add(egui::Shape::mesh(mesh));
    }

    /// Wait for a key press or a touch/click
    pub fn wait_for_input(sync_rx: &Receiver<WorldSyncState>, world: &Arc<Mutex<World>>) {
        loop {
            let state = sync_rx.recv().unwrap(); // Wait for next frame
            {
                let _world = world.lock().unwrap();
                if _world.keys_down.len() > 0 || _world.primary_ptr_down || _world.secondary_ptr_down || matches!(state, WorldSyncState::Cancelled) {
                    break;
                }
            }
        }
    }

    pub fn place_block(world: &Arc<Mutex<World>>, sprite: SpriteID, block: Option<&String>, on_sprite: bool, x: Option<f64>, y: Option<f64>) {
        let mut world = world.lock().unwrap();
        let sprite = world.sprites.get(&sprite).unwrap();

        if (x.is_some() && x.unwrap().fract() != 0.0) || (y.is_some() && y.unwrap().fract() != 0.0) {
            todo!("Placing blocks as graphics is not supported yet")
        }

        let bx = if let Some(x) = x { x as usize } else if on_sprite || y.is_some() { sprite.get_block_x() } else { sprite.get_forward_block_x() };
        let by = if let Some(y) = y { y as usize } else if on_sprite || x.is_some() { sprite.get_block_y() } else { sprite.get_forward_block_y() };
        match block {
            Some(block) => {
                for bz in 0..world.block_map.len_of(Axis(2)) - 1 {
                    let new_val = world.block_map[(bx, by, bz)].clone();
                    world.block_map[(bx, by, bz + 1)] = new_val;
                }
                world.block_map[(bx, by, 0)] = Some(block.to_owned());
            },
            None => {
                for bz in 0..world.block_map.len_of(Axis(2)) {
                    world.block_map[(bx, by, bz)] = None;
                }
            }
        }
    }

    fn load_block_file(blocks: &mut BlockTextures, ctx: &egui::Context, name: &str, path: &str) -> Result<(), egui::load::LoadError> {
        blocks.insert(name.to_owned(), load_texture_from_uri(ctx, &format!("file://{}", path), egui::SizeHint::Scale(1.0.into()))?);
        Ok(())
    }

    fn load_block_bytes(blocks: &mut BlockTextures, ctx: &egui::Context, name: &str, bytes: &'static [u8], fmt: &str) -> Result<(), egui::load::LoadError> {
        blocks.insert(name.to_owned(), load_texture_from_bytes(ctx, bytes, fmt, egui::SizeHint::Scale(1.0.into()))?);
        Ok(())
    }

    pub fn default_blocks(ctx: &egui::Context) -> BlockTextures {
        egui_extras::install_image_loaders(&ctx);
        let mut map = BlockTextures::new();
        insert_block_embedded!(map, ctx, "bricks", "../blocks/bricks.png");
        insert_block_embedded!(map, ctx, "fence", "../blocks/fence.png");
        insert_block_embedded!(map, ctx, "flower", "../blocks/flower.png");
        insert_block_embedded!(map, ctx, "grass", "../blocks/grass.png");
        insert_block_embedded!(map, ctx, "turtle", "../blocks/turtle.png");
        insert_block_embedded!(map, ctx, "wood", "../blocks/wood.png");
        map
    }
}

pub fn load_texture_from_uri(ctx: &egui::Context, uri: &str, size_hint: egui::load::SizeHint) -> Result<egui::load::SizedTexture, egui::load::LoadError> {
    let result = ctx.try_load_texture(uri, egui::TextureOptions::NEAREST, size_hint);
    match result {
        Ok(pool) => {
            loop {
                match pool {
                    egui::load::TexturePoll::Pending { size: _ } => {
                    },
                    egui::load::TexturePoll::Ready { texture } => {
                        break Ok(texture);
                    }
                }
            }
        },
        Err(err) => {
            Err(err)
        }
    }
}

pub fn load_texture_from_bytes(ctx: &egui::Context, bytes: &'static [u8], fmt: &str, size_hint: egui::load::SizeHint) -> Result<egui::load::SizedTexture, egui::load::LoadError> {
    let uri = format!("bytes://{}.{}", uuid::Uuid::new_v4(), fmt);
    ctx.include_bytes(uri.clone(), bytes);
    load_texture_from_uri(ctx, &uri, size_hint)
}

pub fn normalize_angle(angle: f32) -> f32 {
    let angle = angle % 360.0;
    if angle < 0.0 { 360.0 + angle } else { angle }
}