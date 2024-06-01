use app::EditorApp;

pub mod app;
pub mod cmdrenderer;
pub mod cmdpalette;
pub mod dndctl;
pub mod nativedialogs;
pub mod programview;
pub mod programviewdialogs;
pub mod project;
pub mod widgets;

fn main() {
    env_init();
    turtlicoscript_gui::app::RootApp::run(
        |ctx|{ vec![
            Box::new(EditorApp::new(ctx))
        ]}
    );
}

#[cfg(not(target_arch = "wasm32"))]
fn t_log(text: &str) {
    println!("{}", text);
}

#[cfg(target_arch = "wasm32")]
fn t_log(text: &str) {
    web_sys::console::log_1(&text.into());
}

#[cfg(not(target_arch = "wasm32"))]
fn env_init() {
}

#[cfg(target_arch = "wasm32")]
fn env_init() {
    console_error_panic_hook::set_once();
}
