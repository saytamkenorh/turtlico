use std::any::Any;

use checkargs::check_args;
use turtlicoscript::value::{Value, NativeFuncArgs, NativeFuncReturn, Library, LibraryContext, NativeFuncCtxArg};
use turtlicoscript::funcmap;
use turtlicoscript::error::RuntimeError;

const NORMAL_SPEED: f32 = 48.0; // pixels per second
const NORMAL_SPEED_ROTATION: f32 = 90.0; // degrees per second
const FRAME_INTERVAL: u64 = 33; // Milliseconds per frame update

pub struct Context {
    window: slint::Weak<MainWindow>,
    speed: f32, // 1.0 - normal, lower = faster, higher = slower
    rot: f32, // rotation, 0 - right
    x: f32,
    y: f32
}
impl LibraryContext for Context {
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl Context {
    pub fn go(&mut self, distance: f32) {
        let rot = self.rot;

        let mut d = 0.0;
        let origx = self.x;
        let orgiy = self.y;
        if self.speed > 0.0 {
            while d < distance {
                d = f32::min(distance, d + (NORMAL_SPEED * (FRAME_INTERVAL as f32) / 1000.0));
                std::thread::sleep(std::time::Duration::from_millis(FRAME_INTERVAL));
                self.set_turtle_xy(
                    f32::round(origx + f32::cos(f32::to_radians(rot)) * d),
                    f32::round(orgiy + f32::sin(f32::to_radians(360.0 - rot)) * d)
                );
            }
        }
        self.set_turtle_xy(
            f32::round(origx + f32::cos(f32::to_radians(rot)) * distance),
            f32::round(orgiy + f32::sin(f32::to_radians(360.0 - rot)) * distance)
        );
    }

    pub fn set_turtle_xy(&mut self, x: f32, y: f32) {
        self.x = x;
        self.y = y;
        let win_copy = self.window.clone();
        slint::invoke_from_event_loop(move || {
            let win = win_copy.unwrap();
            win.set_turtle_x(x as i32);
            win.set_turtle_y(y as i32);
        }).unwrap();
    }

    pub fn set_turtle_rot(&mut self, rot: f32) {
        let rot = rot % 360.0;
        let rot = if rot < 0.0 { 360.0 + rot } else { rot };

        if self.speed > 0.0 {
            let speed = NORMAL_SPEED_ROTATION * (FRAME_INTERVAL as f32) / 1000.0;

            let mut rot_anim = self.rot;
            let rot_target =
                if f32::abs((rot - 360.0) - self.rot) < f32::abs(rot - self.rot) {
                    rot - 360.0
                } else {rot};
            while rot_anim != rot_target {
                self._set_turtle_rot(rot_anim);
                rot_anim = f32::clamp(rot_target, rot_anim - speed, rot_anim + speed);
                std::thread::sleep(std::time::Duration::from_millis(FRAME_INTERVAL));
            }
        }
        self._set_turtle_rot(rot);
    }

    fn _set_turtle_rot(&mut self, rot: f32) {
        self.rot = rot % 360.0;
        self.rot = if self.rot < 0.0 { 360.0 - self.rot } else { self.rot };
        let win_copy = self.window.clone();
        slint::invoke_from_event_loop(move || {
            let win = win_copy.unwrap();
            win.set_turtle_rot(360 - rot as i32);
        }).unwrap();
    }
}

pub fn init_library(win: slint::Weak<MainWindow>) -> Library {
    let vars = funcmap!{
        "gui",
        go,
        set_rot
    };
    println!("Initializing GUI...");


    let ctx = Context {
        window: win.clone(),
        speed: 1.0,
        rot: 0.0,
        x: 0.0,
        y: 0.0
    };
    slint::invoke_from_event_loop(move || {
        win.unwrap().show();
    }).unwrap();

    Library {
        name: "gui".to_owned(),
        vars: vars,
        context: Box::new(ctx)
    }
}

slint::include_modules!();

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