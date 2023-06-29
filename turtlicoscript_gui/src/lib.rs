#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::any::Any;
use std::sync::mpsc::{Receiver};
use std::sync::{Arc, Mutex};

use checkargs::check_args;
use turtlicoscript::value::{Value, NativeFuncArgs, NativeFuncReturn, Library, LibraryContext, NativeFuncCtxArg};
use turtlicoscript::funcmap;
use turtlicoscript::error::RuntimeError;
use sprite::Sprite;

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
    pub fn go(&mut self, distance: f32) {
        Sprite::go(&mut self.sync_rx, &self.world, &0, distance, false);
    }

    pub fn set_sprite_xy(&mut self, x: f32, y: f32) {
        Sprite::set_pos(&mut self.sync_rx, &self.world, &0, x, y, false);
    }

    pub fn set_turtle_rot(&mut self, rot: f32) {
        Sprite::set_rotation(&mut self.sync_rx, &self.world, &0, rot, false);
    }
}

pub fn init_library(world: Arc<Mutex<world::World>>, sync_rx: Receiver<WorldSyncState>) -> Library {
    let vars = funcmap!{
        "gui",
        go,
        set_rot
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

#[check_args(Int=32)]
pub fn go(ctx: &mut NativeFuncCtxArg, mut args: NativeFuncArgs) -> NativeFuncReturn {
    let distance = arg0 as f32;
    match (&mut *ctx).as_any_mut().downcast_mut::<Context>() {
        Some(ctx) => {
            ctx.go(distance);
        },
        None => {}
    }
    Ok(Value::None)
}

#[check_args(Int=0)]
pub fn set_rot(ctx: &mut NativeFuncCtxArg, mut args: NativeFuncArgs) -> NativeFuncReturn {
    let rot = arg0 as f32;
    match (&mut *ctx).as_any_mut().downcast_mut::<Context>() {
        Some(ctx) => {
            ctx.set_turtle_rot(rot);
        },
        None => {}
    }
    Ok(Value::None)
}