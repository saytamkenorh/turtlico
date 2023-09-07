use app::EditorApp;

pub mod app;
pub mod cmdrenderer;
pub mod cmdpalette;
pub mod dndctl;
pub mod programview;
pub mod project;

fn main() {
    let editor_app = Box::new(EditorApp::new());
    turtlicoscript_gui::app::RootApp::run(vec![
        editor_app
    ]);
}
