use wasm_bindgen::{JsValue, prelude::wasm_bindgen};
use web_sys::console;

#[cfg(target_arch = "wasm32")]
pub fn spawn(f: impl FnOnce() + Send + 'static) -> Result<web_sys::Worker, JsValue> {
  let w = web_sys::Worker::new("./worker.js")?;
  // Double-boxing because `dyn FnOnce` is unsized and so `Box<dyn FnOnce()>` has
  // an undefined layout (although I think in practice its a pointer and a length?).
  let ptr = Box::into_raw(Box::new(Box::new(f) as Box<dyn FnOnce()>));

  // See `worker.js` for the format of this message.
  let msg: js_sys::Array = [
      &wasm_bindgen::module(),
      &wasm_bindgen::memory(),
      &JsValue::from(ptr as u32),
  ]
  .into_iter()
  .collect();
  if let Err(e) = w.post_message(&msg) {
      // We expect the worker to deallocate the box, but if there was an error then
      // we'll do it ourselves.
      let _ = unsafe { Box::from_raw(ptr) };
      Err(e)
  } else {
      Ok(w)
  }
}

#[wasm_bindgen(js_name = "child_entry_point")]
pub fn child_entry_point(ptr: u32) {
  console::log_1(&"[worker] Hello from WASM child entry point".into());
  let work = unsafe { Box::from_raw(ptr as *mut Box<dyn FnOnce()>) };
  (*work)();
}