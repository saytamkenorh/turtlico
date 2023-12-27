pub enum SaveFileMsg {
    Saved(Option<std::path::PathBuf>),
    Canceled,
    Err(String)
}

pub enum OpenFileMsg {
    Openend(Vec<u8>),
    Canceled,
    Err(String)
}

pub trait OpenFileDialog {
    fn get_receiver(&self) -> &std::sync::mpsc::Receiver<OpenFileMsg>;
}

#[cfg(not(target_arch = "wasm32"))]
struct OpenFileDialogRfd {
    receiver: std::sync::mpsc::Receiver<OpenFileMsg>,
}
#[cfg(not(target_arch = "wasm32"))]
impl OpenFileDialog for OpenFileDialogRfd {
    fn get_receiver(&self) -> &std::sync::mpsc::Receiver<OpenFileMsg> {
        &self.receiver
    }
}

#[cfg(target_arch = "wasm32")]
#[allow(dead_code)]
struct OpenFileDialogWeb {
    receiver: std::sync::mpsc::Receiver<OpenFileMsg>,
    el_on_change: gloo::events::EventListener,
    el_on_loadend: gloo::events::EventListener,
}

#[cfg(target_arch = "wasm32")]
impl OpenFileDialog for OpenFileDialogWeb {
    fn get_receiver(&self) -> &std::sync::mpsc::Receiver<OpenFileMsg> {
        &self.receiver
    }
}

#[cfg(target_arch = "wasm32")]
pub fn save_file(data: Vec<u8>, path: Option<std::path::PathBuf>) -> std::sync::mpsc::Receiver<SaveFileMsg> {
    let (sender, receiver) = std::sync::mpsc::channel();
    let window = web_sys::window().unwrap();
    let document = window.document().unwrap();
    let body = document.body().unwrap();

    let data = String::from_utf8(data).unwrap();

    let a = wasm_bindgen::JsCast::dyn_into::<web_sys::HtmlAnchorElement>(document.create_element("a").unwrap()).unwrap();
    let mut blob_props = web_sys::BlobPropertyBag::new();
    blob_props.type_("application/octet-stream");
    let blob = web_sys::Blob::new_with_str_sequence_and_options(&js_array(&[data.as_str()]), &blob_props).unwrap();
    
    a.set_href(&web_sys::Url::create_object_url_with_blob(&blob).unwrap());
    
    let name = match path {
        Some(path) => {
            path.file_name().unwrap_or(std::ffi::OsStr::new("project.tcpf")).to_str().unwrap_or("project.tcpf").to_owned()
        },
        None => "project.tcpf".to_owned()
    };
    a.set_download(&name);
    
    body.append_child(&a).unwrap();
    a.click();
    body.remove_child(&a).unwrap();

    //https://stackoverflow.com/questions/27946228/file-download-a-byte-array-as-a-file-in-javascript-extjs

    sender.send(SaveFileMsg::Saved(None)).ok();
    receiver
}
#[cfg(not(target_arch = "wasm32"))]
pub fn save_file(data: Vec<u8>, path: Option<std::path::PathBuf>) -> std::sync::mpsc::Receiver<SaveFileMsg> {
    let (sender, receiver) = std::sync::mpsc::channel();
    
    if let Some(path) = path {
        execute(async move {
            match save_to_path(&path, data) {
                Ok(_) => {
                    sender.send(SaveFileMsg::Saved(Some(path))).ok();
                },
                Err(err) => {
                    sender.send(SaveFileMsg::Err(err)).ok();
                }
            }
        });
        return receiver;
    }
    
    let task = rfd::AsyncFileDialog::new()
                    .add_filter("Turtlico project", &["tcpf"])
                    .save_file();

    execute(async move {
        let file = task.await;
        if let Some(file) = file {
            let mut new_path = std::path::PathBuf::from(file.path());
            new_path.set_extension(".tcpf");
            match save_to_path(&new_path, data) {
                Ok(_) => {
                    sender.send(SaveFileMsg::Saved(Some(new_path))).ok();
                },
                Err(err) => {
                    sender.send(SaveFileMsg::Err(err)).ok();
                }
            }
        } else {
            sender.send(SaveFileMsg::Canceled).ok();
        }
    });
    receiver
}

#[cfg(not(target_arch = "wasm32"))]
pub fn open_file() -> Box<impl OpenFileDialog> {
    let (sender, receiver) = std::sync::mpsc::channel();
    
    let task = rfd::AsyncFileDialog::new()
                    .add_filter("Turtlico project", &["tcpf"])
                    .pick_file();
    
    execute(async move {
        let file = task.await;
        if let Some(file) = file {
            let data = file.read().await;
            sender.send(OpenFileMsg::Openend(data)).ok();
        } else {
            sender.send(OpenFileMsg::Canceled).ok();
        }
    });
    Box::new(OpenFileDialogRfd{
        receiver: receiver
    })
}

#[cfg(target_arch = "wasm32")]
pub fn open_file() -> Box<impl OpenFileDialog> {
    let (sender, receiver) = std::sync::mpsc::channel();

    let window = web_sys::window().unwrap();
    let document = window.document().unwrap();
    
    let input = wasm_bindgen::JsCast::dyn_into::<web_sys::HtmlInputElement>(document.create_element("input").unwrap()).unwrap();
    input.set_type("file");
    input.set_accept(".tcpf");
    let input2 = input.clone();

    let file_reader = web_sys::FileReader::new().unwrap();
            
    let file_reader2 = file_reader.clone();
    let sender2 = sender.clone();
    let on_loadend = gloo::events::EventListener::new(&file_reader, "loadend", move |_event| {
        let result = file_reader2.result();
        match result {
            Ok(result) => {
                crate::t_log("File loaded successfully");
                let data = js_sys::Uint8Array::new(&result);
                sender2.send(OpenFileMsg::Openend(data.to_vec())).ok();
            },
            Err(err) => {
                crate::t_log("File loading failed");
                let msg = format!("{}", err.is_string());
                sender2.send(OpenFileMsg::Err(msg)).ok();
            }
        }
    });

    let on_change = gloo::events::EventListener::new(&input, "change", move |_event| {
        let files = input2.files().expect("Cannot get files from input element");
        if files.length() > 0 {
            crate::t_log("File chosen");
            let f = files.get(0).unwrap();           
            file_reader.read_as_array_buffer(&f).unwrap();
        } else {
            sender.send(OpenFileMsg::Canceled).ok();
        }
    });
    input.click();

    Box::new(OpenFileDialogWeb{
        receiver: receiver,
        el_on_change: on_change,
        el_on_loadend: on_loadend,
    })
}

#[allow(dead_code)]
fn save_to_path(path: &std::path::PathBuf, data: Vec<u8>) -> Result<(), String> {
    let mut file = std::fs::File::create(&path).map_err(|err| err.to_string())?;
    use std::io::Write;

    file.write_all(&data).map_err(|err| err.to_string())?;
    Ok(())
}


#[allow(dead_code)]
#[cfg(not(target_arch = "wasm32"))]
fn execute<F: std::future::Future<Output = ()> + Send + 'static>(f: F) {
    std::thread::spawn(move || futures::executor::block_on(f));
}

#[cfg(target_arch = "wasm32")]
fn js_array(values: &[&str]) -> wasm_bindgen::JsValue {
    return wasm_bindgen::JsValue::from(values.into_iter()
        .map(|x| wasm_bindgen::JsValue::from_str(x))
        .collect::<js_sys::Array>());
}
