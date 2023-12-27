use egui_extras::RetainedImage;
use emath::Vec2;

pub const BTN_ICON_SIZE: u32 = 22;
pub const BTN_ICON_SIZE_VEC: Vec2 = Vec2::new(BTN_ICON_SIZE as f32, BTN_ICON_SIZE as f32);
pub const MARGIN_SMALL: f32 = 4.0;
pub const MARGIN_MEDIUM: f32 = 8.0;
pub const COLOR_ERROR: egui::Color32 = egui::Color32::from_rgb(255, 200, 200);

pub fn error_frame<F>(ui: &mut egui::Ui, text: &str, on_close: F, close_img: &RetainedImage) where F: FnOnce() {
    egui::Frame::group(ui.style())
        .fill(COLOR_ERROR)
        .show(ui, |ui| {
            ui.set_width(ui.available_width() - MARGIN_MEDIUM);
            ui.with_layout(egui::Layout::right_to_left(emath::Align::Min), |ui| {
                let btn = ui.add(egui::ImageButton::new(
                    close_img.texture_id(ui.ctx()),
                    Vec2::new(BTN_ICON_SIZE as f32, BTN_ICON_SIZE as f32),
                ));
                if btn.clicked() {
                    on_close();
                }
                ui.with_layout(egui::Layout::top_down(emath::Align::Min), |ui| {
                    ui.add(egui::Label::new(text).wrap(true));
                });
            });
        });
}
