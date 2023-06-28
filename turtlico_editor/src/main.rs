use app::EditorApp;

pub mod app;

fn main() {
    let editor_app = Box::new(EditorApp::new());
    turtlicoscript_gui::app::RootApp::run(vec![
        editor_app
    ]);
}
