#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::any::Any;
use std::collections::HashMap;
use std::sync::mpsc::Receiver;
use std::sync::{Arc, Mutex};

use checkargs::check_args;
use turtlicoscript::interpreter::Scope;
use turtlicoscript::value::{Value, NativeFuncArgs, NativeFuncReturn, Library, LibraryContext, NativeFuncCtxArg, unwrap_context, HashableValue, FuncThisObject, TSObject};
use turtlicoscript::{funcmap, funcmap_obj};
use turtlicoscript::error::RuntimeError;
use sprite::Sprite;
use world::{SpriteID, BLOCK_SIZE_PX, World};

pub mod app;
pub mod sprite;
pub mod world;
pub mod worker;

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

    pub fn sprite_get_block_xy(&mut self, id: SpriteID) -> HashMap<HashableValue, Value> {
        let mut res = HashMap::new();
        let mut _world = self.world.lock().unwrap();
        let sprite = _world.sprites.get_mut(&id).unwrap();
        res.insert("x".into(), sprite.get_block_x().into());
        res.insert("y".into(), sprite.get_block_y().into());
        res
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

    pub fn sprite_skin(&mut self, id: SpriteID, skin: &String) -> Result<(), RuntimeError> {
        Sprite::set_skin(&self.world, &id, skin)
    }

    pub fn sprite_place_block(&mut self, id: SpriteID, block: Option<&String>, on_sprite: bool, x: Option<f64>, y: Option<f64>) {
        World::place_block(&self.world, id, block,  on_sprite, x, y);
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
    let mut scope = Scope::new();
    scope.vars.extend(funcmap!{
        "gui",
        new_turtle,
        wait
    });
    // Consts
    // scope.vars.insert("EXAMPLE".to_owned(), "value".into());

    println!("Initializing GUI...");

    let ctx = Box::new(Context {
        world: world,
        sync_rx: sync_rx,
    });

    let mut lib = Library {
        name: "gui".to_owned(),
        scope: scope,
        context: ctx
    };

    let default_turtle = new_turtle(&mut lib.context, None, vec![]).unwrap();
    if let Value::Object(obj) = default_turtle {
        for (key, value) in obj.borrow().fields.iter() {
            if let HashableValue::String(name) = key {
                lib.scope.vars.insert(name.to_owned(), value.to_owned());
            }
        }
        for prop in obj.borrow().fields_props.iter() {
            if let HashableValue::String(name) = prop {
                lib.scope.vars_props.insert(name.to_owned());
            }
        }
        lib.scope.vars.insert("turtle".to_owned(), Value::Object(obj));
    }

    lib
}

pub fn new_turtle(ctx: &mut NativeFuncCtxArg, _this: FuncThisObject, _args: NativeFuncArgs) -> NativeFuncReturn {
    let ctx = unwrap_context::<Context>(ctx);
    let id = ctx.sprite_new();
    let turtle_obj = std::rc::Rc::new(std::cell::RefCell::new(TSObject::new()));

    {
        let mut turtle = turtle_obj.borrow_mut();
        turtle.fields.insert("sprite_id".into(), Value::Int(id.try_into().unwrap()));

        turtle.fields.extend(funcmap_obj!{
            "gui",
            Some(std::rc::Rc::<std::cell::RefCell<TSObject>>::downgrade(&turtle_obj)),
            go,
            set_xy,
            set_xy_px,
            set_target_xy,
            set_target_xy_px,
            block_xy,
            set_rot,
            left,
            right,
            speed,
            skin,
            place_block,
            destroy_block
        });
        turtle.fields_props.extend(vec![
            "block_xy".into()
        ]);
    }

    Ok(Value::Object(turtle_obj))
}

fn get_sprite_id(this: FuncThisObject) -> Result<SpriteID, RuntimeError> {
    match this {
        Some(this) => {
            match this.upgrade().unwrap().borrow().fields.get(&"sprite_id".into()) {
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

#[check_args()]
pub fn block_xy(ctx: &mut NativeFuncCtxArg, this: FuncThisObject, args: NativeFuncArgs) -> NativeFuncReturn {
    let sprite_id = get_sprite_id(this)?;
    let res = unwrap_context::<Context>(ctx).sprite_get_block_xy(sprite_id);
    Ok(res.into())
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

#[check_args(Image)]
pub fn skin(ctx: &mut NativeFuncCtxArg, this: FuncThisObject, args: NativeFuncArgs) -> NativeFuncReturn {
    let sprite_id = get_sprite_id(this)?;
    let skin = arg0 as &String;
    unwrap_context::<Context>(ctx).sprite_skin(sprite_id, skin)?;
    Ok(Value::None)
}

fn place_destroy_block(ctx: &mut NativeFuncCtxArg, this: FuncThisObject, args: NativeFuncArgs, force_destroy: bool, force_place: bool) -> NativeFuncReturn {
    let sprite_id = get_sprite_id(this)?;
    let mut block: Option<&String> = None;
    let mut x: Option<f64> = None;
    let mut y: Option<f64> = None;
    let mut on_sprite = false;
    for (i, arg) in args.iter().enumerate() {
        match arg {
            Value::Image(value) => {
                if force_destroy {
                    return Err(RuntimeError::InvalidArgType(i));
                }
                block = Some(value);
            },
            Value::Int(value) => {
                if x.is_none() {
                    x = Some(*value as f64)
                } else if y.is_none() {
                    y = Some(*value as f64)
                } else {
                    return Err(RuntimeError::InvalidArgType(i));
                }
            },
            Value::Object(value) => {
                let value = value.borrow_mut();
                match value.fields.get(&("x".into())) {
                    Some(val_x) => {
                        x = Some(val_x.try_into()?)
                    },
                    None => return Err(RuntimeError::InvalidIdentifier("x".to_owned()))
                }
                match value.fields.get(&("y".into())) {
                    Some(val_y) => {
                        y = Some(val_y.try_into()?)
                    },
                    None => return Err(RuntimeError::InvalidIdentifier("y".to_owned()))
                }
            },
            Value::String(value) => {
                if value == "on_sprite" {
                    on_sprite = true;
                }
            },
            _ => {
                return Err(RuntimeError::InvalidArgType(i))
            }
        }
    }
    if force_place && matches!(block, None) {
        return  Err(RuntimeError::MissingParam("block".to_owned()));
    }
    unwrap_context::<Context>(ctx).sprite_place_block(sprite_id, block, on_sprite, x, y);
    Ok(Value::None)
} 
pub fn place_block(ctx: &mut NativeFuncCtxArg, this: FuncThisObject, args: NativeFuncArgs) -> NativeFuncReturn {
    place_destroy_block(ctx, this, args, false, true)
}

pub fn destroy_block(ctx: &mut NativeFuncCtxArg, this: FuncThisObject, args: NativeFuncArgs) -> NativeFuncReturn {
    place_destroy_block(ctx, this, args, true, false)
}

#[check_args(Float=0)]
pub fn wait(ctx: &mut NativeFuncCtxArg, _this: FuncThisObject, mut args: NativeFuncArgs) -> NativeFuncReturn {
    let time = arg0;
    unwrap_context::<Context>(ctx).wait(time);
    Ok(Value::None)
}