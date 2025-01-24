pub const BTN_ICON_SIZE: u32 = 22;
pub const BTN_ICON_SIZE_VEC: egui::Vec2 = egui::Vec2::new(BTN_ICON_SIZE as f32, BTN_ICON_SIZE as f32);
pub const MARGIN_SMALL: f32 = 4.0;
pub const MARGIN_MEDIUM: f32 = 8.0;
pub const COLOR_ERROR: egui::Color32 = egui::Color32::from_rgb(255, 200, 200);

pub fn error_frame<F>(
    ui: &mut egui::Ui,
    text: &str,
    on_close: F,
    close_img: &egui::ImageSource<'static>,
) where
    F: FnOnce(),
{
    egui::Frame::group(ui.style())
        .fill(COLOR_ERROR)
        .show(ui, |ui| {
            ui.set_width(ui.available_width() - MARGIN_MEDIUM);
            ui.with_layout(egui::Layout::right_to_left(egui::Align::Min), |ui| {
                let btn =
                    ui.add_sized(BTN_ICON_SIZE_VEC, egui::ImageButton::new(close_img.clone()));
                if btn.clicked() {
                    on_close();
                }
                ui.with_layout(egui::Layout::top_down(egui::Align::Min), |ui| {
                    ui.add(egui::Label::new(text).wrap());
                });
            });
        });
}

pub fn key_selector_ui(ui: &mut egui::Ui, val: &mut String) -> egui::Response {
    let desired_size = 50.0 * egui::vec2(1.0, 1.0);
    let (rect, mut response) =
        ui.allocate_exact_size(desired_size, egui::Sense::focusable_noninteractive());

    ui.input_mut(|i| {
        if let Some(key) = i.keys_down.iter().last().cloned() {
            i.consume_key(egui::Modifiers::NONE, key);
            let new_val = key.symbol_or_name();
            if new_val != val {
                *val = new_val.to_owned();
                response.mark_changed();
            }
        }
    });

    if ui.is_rect_visible(rect) {
        let visuals = ui.style().interact(&response);
        let rect = rect.expand(visuals.expansion);
        let radius = 10.0;
        ui.painter()
            .rect(rect, radius, visuals.bg_fill, visuals.bg_stroke);
        ui.put(rect.shrink(2.0), egui::Label::new(val.to_owned()));
    }

    response
}

pub fn key_selector(val: &mut String) -> impl egui::Widget + '_ {
    move |ui: &mut egui::Ui| key_selector_ui(ui, val)
}
