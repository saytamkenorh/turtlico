#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::any::Any;
use std::sync::mpsc::{Receiver};
use std::sync::{Arc, Mutex};

use checkargs::check_args;
use turtlicoscript::value::{Value, NativeFuncArgs, NativeFuncReturn, Library, LibraryContext, NativeFuncCtxArg, unwrap_context};
use turtlicoscript::funcmap;
use turtlicoscript::error::RuntimeError;
use sprite::Sprite;
use world::{SpriteID, BLOCK_SIZE_PX, World};

pub mod app;
pub mod sprite;
pub mod world;
mod worker;

pub enum WorldSyncState {
    Update,
    Cancelled,
}

pub struct Context {
    world: Arc<Mutex<world::World>>,
    sync_rx: Receiver<WorldSyncState>,
}

impl LibraryContext for Context {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl Context {
    pub fn sprite_go(&mut self, id: SpriteID, distance: f32) {
        Sprite::go(&mut self.sync_rx, &self.world, &id, distance, false);
    }

    pub fn sprite_set_xy(&mut self, id: SpriteID, x: f32, y: f32) {
        Sprite::set_pos(&mut self.sync_rx, &self.world, &id, x, y, false);
    }

    pub fn sprite_set_target_xy(&mut self, id: SpriteID, x: f32, y: f32) {
        Sprite::set_pos_target(&self.world, &id, x, y);
    }

    pub fn sprite_set_rot(&mut self, id: SpriteID, rot: f32) {
        Sprite::set_rotation(&mut self.sync_rx, &self.world, &id, rot, false);
    }

    pub fn sprite_rotate(&mut self, id: SpriteID, rot: f32) {
        let new_rot = Sprite::get_rotation(&self.world, &id) + rot;
        Sprite::set_rotation(&mut self.sync_rx, &self.world, &id, new_rot, false);
    }

    pub fn sprite_speed(&mut self, id: SpriteID, speed: f32) {
        Sprite::set_speed(&self.world, &id, speed);
    }

    pub fn wait(&mut self, time: f64) {
        if time == 0.0 {
            World::wait_for_input(&mut self.sync_rx, &self.world);
        } else {
            if time > 0.1 {
                let start_time = std::time::Instant::now();
                while std::time::Instant::now() < start_time + std::time::Duration::from_secs_f64(time) {
                    let state = self.sync_rx.recv().unwrap();
                    if matches!(state, WorldSyncState::Cancelled) {
                        break;
                    }
                }
            } else {
                std::thread::sleep(std::time::Duration::from_secs_f64(time));
            }
        }
    }
}

pub fn init_library(world: Arc<Mutex<world::World>>, sync_rx: Receiver<WorldSyncState>) -> Library {
    let vars = funcmap!{
        "gui",
        go,
        set_xy,
        set_xy_px,
        set_target_xy,
        set_target_xy_px,
        set_rot,
        left,
        right,
        speed,
        wait
    };
    println!("Initializing GUI...");

    let ctx = Context {
        world: world,
        sync_rx: sync_rx,
    };

    Library {
        name: "gui".to_owned(),
        vars: vars,
        context: Box::new(ctx)
    }
}

#[check_args(Int=1)]
pub fn go(ctx: &mut NativeFuncCtxArg, mut args: NativeFuncArgs) -> NativeFuncReturn {
    let distance = arg0 as f32;
    unwrap_context::<Context>(ctx).sprite_go(0, distance);
    Ok(Value::None)
}

#[check_args(Float, Float)]
pub fn set_xy(ctx: &mut NativeFuncCtxArg, args: NativeFuncArgs) -> NativeFuncReturn {
    let x = arg0 as f32 * BLOCK_SIZE_PX;
    let y = arg1 as f32 * BLOCK_SIZE_PX;
    unwrap_context::<Context>(ctx).sprite_set_xy(0, x, y);
    Ok(Value::None)
}

#[check_args(Float, Float)]
pub fn set_xy_px(ctx: &mut NativeFuncCtxArg, args: NativeFuncArgs) -> NativeFuncReturn {
    let x = arg0 as f32;
    let y = arg1 as f32;
    unwrap_context::<Context>(ctx).sprite_set_xy(0, x, y);
    Ok(Value::None)
}

#[check_args(Float, Float)]
pub fn set_target_xy(ctx: &mut NativeFuncCtxArg, args: NativeFuncArgs) -> NativeFuncReturn {
    let x = arg0 as f32 * BLOCK_SIZE_PX;
    let y = arg1 as f32 * BLOCK_SIZE_PX;
    unwrap_context::<Context>(ctx).sprite_set_target_xy(0, x, y);
    Ok(Value::None)
}

#[check_args(Float, Float)]
pub fn set_target_xy_px(ctx: &mut NativeFuncCtxArg, args: NativeFuncArgs) -> NativeFuncReturn {
    let x = arg0 as f32;
    let y = arg1 as f32;
    unwrap_context::<Context>(ctx).sprite_set_target_xy(0, x, y);
    Ok(Value::None)
}

#[check_args(Int=0)]
pub fn set_rot(ctx: &mut NativeFuncCtxArg, mut args: NativeFuncArgs) -> NativeFuncReturn {
    let rot = arg0 as f32;
    unwrap_context::<Context>(ctx).sprite_set_rot(0, rot);
    Ok(Value::None)
}

#[check_args(Int=90)]
pub fn left(ctx: &mut NativeFuncCtxArg, mut args: NativeFuncArgs) -> NativeFuncReturn {
    let angle = arg0 as f32;
    unwrap_context::<Context>(ctx).sprite_rotate(0, -angle);
    Ok(Value::None)
}

#[check_args(Int=90)]
pub fn right(ctx: &mut NativeFuncCtxArg, mut args: NativeFuncArgs) -> NativeFuncReturn {
    let angle = arg0 as f32;
    unwrap_context::<Context>(ctx).sprite_rotate(0, angle);
    Ok(Value::None)
}

#[check_args(Float=1)]
pub fn speed(ctx: &mut NativeFuncCtxArg, mut args: NativeFuncArgs) -> NativeFuncReturn {
    let speed = arg0 as f32;
    unwrap_context::<Context>(ctx).sprite_speed(0, speed);
    Ok(Value::None)
}


#[check_args(Float=0)]
pub fn wait(ctx: &mut NativeFuncCtxArg, mut args: NativeFuncArgs) -> NativeFuncReturn {
    let time = arg0;
    unwrap_context::<Context>(ctx).wait(time);
    Ok(Value::None)
}