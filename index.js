// First up, but try to do feature detection to provide better error messages
function loadWasm() {
    // https://github.com/gzuidhof/coi-serviceworker
    let genericErr = 'Cannot initiate Turtlico Web. Try using a current version of the web browser in non-private mode.\n\n';
    
    if (!navigator.serviceWorker) {
        alert(genericErr + 'service worker not available, perhaps due to private mode');
    }
    
    const reloadedBySelf = window.sessionStorage.getItem("coiReloadedBySelf");
    
    if (typeof SharedArrayBuffer !== 'function') {
        if (reloadedBySelf) {
            alert(genericErr + 'this browser does not have SharedArrayBuffer support enabled');
        }
        return
    }
    // Test for bulk memory operations with passive data segments
    //  (module (memory 1) (data passive ""))
    const buf = new Uint8Array([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
        0x05, 0x03, 0x01, 0x00, 0x01, 0x0b, 0x03, 0x01, 0x01, 0x00]);
    if (!WebAssembly.validate(buf)) {
        if (reloadedBySelf) {
            alert(genericErr + 'this browser does not support passive wasm memory');
        }
        return
    }

    wasm_bindgen('./turtlico_editor_bg.wasm')
        .catch(console.error);
}

loadWasm();