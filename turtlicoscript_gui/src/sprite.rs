use std::sync::{Mutex, Arc, mpsc::Receiver};

use turtlicoscript::error::RuntimeError;

use crate::{world::{*}, WorldSyncState};

pub struct Sprite {
    pub skin: String,
    pub speed: f32, // 1.0 - normal, lower = faster, higher = slower
    pub rendered_rot: f32, // rendered rotation
    pub rot: f32, // clockwise rotation, 0 - right
    pub x: f32,
    pub y: f32,
    pub rendered_x: f32,
    pub rendered_y: f32,
}

impl Sprite {
    pub fn new() -> Self {
        let x = 0.0;
        let y = BLOCK_SIZE_PX * (SCREEN_HEIGHT as f32 - 1.0);
        let rot = 0.0;
        Self {
            skin: "turtle".to_owned(),
            speed: 1.0,
            rendered_rot: rot,
            rot: rot,
            x: x,
            y: y,
            rendered_x: x,
            rendered_y: y,
        }
    }

    pub fn animate(&mut self, delta: f32) {
        let dist_cw = if self.rendered_rot > self.rot { 360.0 - self.rendered_rot + self.rot } else { self.rot - self.rendered_rot };
        let dist_ccw = if self.rendered_rot > self.rot { self.rendered_rot - self.rot } else { self.rendered_rot + 360.0 - self.rot };
        let step_rot = self.speed * NORMAL_SPEED_ROTATION * delta;
        let new_rot =
            if f32::abs(self.rot - self.rendered_rot) <= step_rot {self.rot}
            else if dist_cw < dist_ccw {normalize_angle(self.rendered_rot + step_rot)}
            else {normalize_angle(self.rendered_rot - step_rot)};

        self.rendered_rot = new_rot;

        let start = emath::vec2(self.rendered_x, self.rendered_y);
        let end = emath::vec2(self.x, self.y);
        let angle: f32 = (end - start).angle();
        let step_move = self.speed * NORMAL_SPEED * delta;

        let step_x = step_move * f32::cos(angle);
        let new_x = if (self.x - self.rendered_x) < 0.0 { f32::max(self.rendered_x + step_x, self.x) } else {f32::min(self.rendered_x + step_x, self.x)};

        let step_y = step_move * f32::sin(angle);
        let new_y = if (self.y - self.rendered_y) < 0.0 { f32::max(self.rendered_y + step_y, self.y) } else {f32::min(self.rendered_y + step_y, self.y)};

        // println!("{} {} -> {} {}, angle {} step {} new {}", self.rendered_x, self.rendered_y, self.x, self.y, angle, step_y, new_y);

        self.rendered_x = new_x;
        self.rendered_y = new_y;
    }

    pub fn get_block_x(&self) -> usize {
        f32::floor(self.rendered_x / BLOCK_SIZE_PX) as usize
    }

    pub fn get_block_y(&self) -> usize {
        f32::floor(self.rendered_y / BLOCK_SIZE_PX) as usize
    }

    pub fn get_forward_block_x(&self) -> usize {
        f32::floor((self.rendered_x + f32::cos(self.rot.to_radians()) * BLOCK_SIZE_PX) / BLOCK_SIZE_PX) as usize
    }

    pub fn get_forward_block_y(&self) -> usize {
        f32::floor((self.rendered_y + f32::sin(self.rot.to_radians()) * BLOCK_SIZE_PX) / BLOCK_SIZE_PX) as usize
    }

    pub fn go(sync_rx: &Receiver<WorldSyncState>, world: &Arc<Mutex<World>>, id: &SpriteID, distance: f32, instant: bool) {
        let target_x;
        let target_y;
        {
            let _world = world.lock().unwrap();
            let sprite = _world.sprites.get(id).unwrap();
            target_x = f32::round(sprite.x + f32::cos(sprite.rot.to_radians()) * distance * BLOCK_SIZE_PX);
            target_y = f32::round(sprite.y + f32::sin(sprite.rot.to_radians()) * distance * BLOCK_SIZE_PX);
        }
        Sprite::set_pos(sync_rx, world, id, target_x, target_y, instant);
    }

    pub fn set_pos(sync_rx: &Receiver<WorldSyncState>, world: &Arc<Mutex<World>>, id: &SpriteID, x: f32, y: f32, instant: bool) {
        let speed;
        {
            let _world = world.lock().unwrap();
            speed = _world.sprites.get(id).unwrap().speed;
        }
        if speed > 0.0 && !instant {
            {
                let mut _world = world.lock().unwrap();
                let sprite = _world.sprites.get_mut(id).unwrap();
                sprite.x = x;
                sprite.y = y;
            }
            loop {
                let state = sync_rx.recv().unwrap(); // Wait for next frame
                {
                    let _world = world.lock().unwrap();
                    let sprite = _world.sprites.get(id).unwrap();
                    if sprite.rendered_x == sprite.x && sprite.rendered_y == sprite.y || matches!(state, WorldSyncState::Cancelled) {
                        break;
                    }
                }
            }
        } else {
            let mut _world = world.lock().unwrap();
            let sprite = _world.sprites.get_mut(id).unwrap();
            sprite.x = x;
            sprite.y = y;
            sprite.rendered_x = sprite.x;
            sprite.rendered_y = sprite.y;
        }
    }

    pub fn set_pos_target(world: &Arc<Mutex<World>>, id: &SpriteID, x: f32, y: f32) {
        let mut _world = world.lock().unwrap();
        let sprite = _world.sprites.get_mut(id).unwrap();
        sprite.x = x;
        sprite.y = y;
    }

    pub fn set_rotation(sync_rx: &Receiver<WorldSyncState>, world: &Arc<Mutex<World>>, id: &SpriteID, rot: f32, instant: bool) {
        let speed;
        {
            let _world = world.lock().unwrap();
            speed = _world.sprites.get(id).unwrap().speed;
        }
        let rot = normalize_angle(rot);

        if speed > 0.0 && !instant {
            {
                let mut _world = world.lock().unwrap();
                _world.sprites.get_mut(id).unwrap().rot = rot;
            }
            loop {
                let state = sync_rx.recv().unwrap(); // Wait for next frame
                {
                    let _world = world.lock().unwrap();
                    let sprite = _world.sprites.get(id).unwrap();
                    if sprite.rendered_rot == sprite.rot || matches!(state, WorldSyncState::Cancelled) {
                        break;
                    }
                }
            }
        } else {
            let mut _world = world.lock().unwrap();
            let sprite = _world.sprites.get_mut(id).unwrap();
            sprite.rot = rot;
            sprite.rendered_rot = sprite.rot;
        }
    }

    pub fn get_rotation(world: &Arc<Mutex<World>>, id: &SpriteID) -> f32 {
        let mut _world = world.lock().unwrap();
        _world.sprites.get_mut(id).unwrap().rot
    }

    pub fn set_speed(world: &Arc<Mutex<World>>, id: &SpriteID, speed: f32) {
        let mut _world = world.lock().unwrap();
        _world.sprites.get_mut(id).unwrap().speed = speed;
    }

    pub fn set_skin(world: &Arc<Mutex<World>>, id: &SpriteID, skin: &String) -> Result<(), RuntimeError>{
        let mut _world = world.lock().unwrap();
        _world.sprites.get_mut(id).unwrap().skin = _world.get_block(skin)?;
        Ok(())
    }
}