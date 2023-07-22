#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::any::Any;
use std::collections::HashMap;
use std::sync::mpsc::Receiver;
use std::sync::{Arc, Mutex};

use checkargs::check_args;
use turtlicoscript::value::{Value, NativeFuncArgs, NativeFuncReturn, Library, LibraryContext, NativeFuncCtxArg, unwrap_context, HashableValue, ValueObject, FuncThisObject};
use turtlicoscript::{funcmap, funcmap_obj};
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
    pub fn sprite_new(&mut self) -> u32 {
        let mut world = self.world.lock().unwrap();
        let id = world.add_sprite();
        id
    }

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
        new_turtle,
        wait
    };
    println!("Initializing GUI...");

    let ctx = Box::new(Context {
        world: world,
        sync_rx: sync_rx,
    });

    let mut lib = Library {
        name: "gui".to_owned(),
        vars: vars,
        context: ctx
    };

    let default_turtle = new_turtle(&mut lib.context, None, vec![]).unwrap();
    if let Value::Object(obj) = default_turtle {
        for (key, value) in obj.borrow().iter() {
            if let HashableValue::String(name) = key {
                lib.vars.insert(name.to_owned(), value.to_owned());
            }
        }
        lib.vars.insert("turtle".to_owned(), Value::Object(obj));
    }

    lib
}

pub fn new_turtle(ctx: &mut NativeFuncCtxArg, _this: FuncThisObject, _args: NativeFuncArgs) -> NativeFuncReturn {
    let ctx = unwrap_context::<Context>(ctx);
    let id = ctx.sprite_new();
    let turtle_obj = std::rc::Rc::new(std::cell::RefCell::new(HashMap::new()));

    {
        let mut turtle = turtle_obj.borrow_mut();
        turtle.insert(HashableValue::String("sprite_id".to_owned()), Value::Int(id.try_into().unwrap()));

        turtle.extend(funcmap_obj!{
            "gui",
            Some(std::rc::Rc::<std::cell::RefCell<HashMap<HashableValue, Value>>>::downgrade(&turtle_obj)),
            go,
            set_xy,
            set_xy_px,
            set_target_xy,
            set_target_xy_px,
            set_rot,
            left,
            right,
            speed
        });
    }

    Ok(Value::Object(turtle_obj))
}

fn get_sprite_id(this: FuncThisObject) -> Result<SpriteID, RuntimeError> {
    match this {
        Some(this) => {
            match this.upgrade().unwrap().borrow().get(&"sprite_id".into()) {
                Some(id) => {
                    match id {
                        Value::Int(id) => Ok(SpriteID::try_from(*id).map_err(|_| RuntimeError::TypeError)?),
                        _ => {
                            Err(RuntimeError::TypeError)
                        }
                    }
                },
                None => {
                    Err(RuntimeError::InvalidIdentifier("sprite_id".to_owned()))
                }
            }
        },
        None => {
            Err(RuntimeError::MethodCalledAsFunction)
        }
    }
}


#[check_args(Int=1)]
pub fn go(ctx: &mut NativeFuncCtxArg, this: FuncThisObject, mut args: NativeFuncArgs) -> NativeFuncReturn {
    let sprite_id = get_sprite_id(this)?;
    let distance = arg0 as f32;
    unwrap_context::<Context>(ctx).sprite_go(sprite_id, distance);
    Ok(Value::None)
}

#[check_args(Float, Float)]
pub fn set_xy(ctx: &mut NativeFuncCtxArg, this: FuncThisObject, args: NativeFuncArgs) -> NativeFuncReturn {
    let sprite_id = get_sprite_id(this)?;
    let x = arg0 as f32 * BLOCK_SIZE_PX;
    let y = arg1 as f32 * BLOCK_SIZE_PX;
    unwrap_context::<Context>(ctx).sprite_set_xy(sprite_id, x, y);
    Ok(Value::None)
}

#[check_args(Float, Float)]
pub fn set_xy_px(ctx: &mut NativeFuncCtxArg, this: FuncThisObject, args: NativeFuncArgs) -> NativeFuncReturn {
    let sprite_id = get_sprite_id(this)?;
    let x = arg0 as f32;
    let y = arg1 as f32;
    unwrap_context::<Context>(ctx).sprite_set_xy(sprite_id, x, y);
    Ok(Value::None)
}

#[check_args(Float, Float)]
pub fn set_target_xy(ctx: &mut NativeFuncCtxArg, this: FuncThisObject, args: NativeFuncArgs) -> NativeFuncReturn {
    let sprite_id = get_sprite_id(this)?;
    let x = arg0 as f32 * BLOCK_SIZE_PX;
    let y = arg1 as f32 * BLOCK_SIZE_PX;
    unwrap_context::<Context>(ctx).sprite_set_target_xy(sprite_id, x, y);
    Ok(Value::None)
}

#[check_args(Float, Float)]
pub fn set_target_xy_px(ctx: &mut NativeFuncCtxArg, this: FuncThisObject, args: NativeFuncArgs) -> NativeFuncReturn {
    let sprite_id = get_sprite_id(this)?;
    let x = arg0 as f32;
    let y = arg1 as f32;
    unwrap_context::<Context>(ctx).sprite_set_target_xy(sprite_id, x, y);
    Ok(Value::None)
}

#[check_args(Int=0)]
pub fn set_rot(ctx: &mut NativeFuncCtxArg, this: FuncThisObject, mut args: NativeFuncArgs) -> NativeFuncReturn {
    let sprite_id = get_sprite_id(this)?;
    let rot = arg0 as f32;
    unwrap_context::<Context>(ctx).sprite_set_rot(sprite_id, rot);
    Ok(Value::None)
}

#[check_args(Int=90)]
pub fn left(ctx: &mut NativeFuncCtxArg, this: FuncThisObject, mut args: NativeFuncArgs) -> NativeFuncReturn {
    let sprite_id = get_sprite_id(this)?;
    let angle = arg0 as f32;
    unwrap_context::<Context>(ctx).sprite_rotate(sprite_id, -angle);
    Ok(Value::None)
}

#[check_args(Int=90)]
pub fn right(ctx: &mut NativeFuncCtxArg, this: FuncThisObject, mut args: NativeFuncArgs) -> NativeFuncReturn {
    let sprite_id = get_sprite_id(this)?;
    let angle = arg0 as f32;
    unwrap_context::<Context>(ctx).sprite_rotate(sprite_id, angle);
    Ok(Value::None)
}

#[check_args(Float=1)]
pub fn speed(ctx: &mut NativeFuncCtxArg, this: FuncThisObject, mut args: NativeFuncArgs) -> NativeFuncReturn {
    let sprite_id = get_sprite_id(this)?;
    let speed = arg0 as f32;
    unwrap_context::<Context>(ctx).sprite_speed(sprite_id, speed);
    Ok(Value::None)
}


#[check_args(Float=0)]
pub fn wait(ctx: &mut NativeFuncCtxArg, _this: FuncThisObject, mut args: NativeFuncArgs) -> NativeFuncReturn {
    let time = arg0;
    unwrap_context::<Context>(ctx).wait(time);
    Ok(Value::None)
}