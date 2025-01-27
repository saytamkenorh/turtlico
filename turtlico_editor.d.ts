declare namespace wasm_bindgen {
	/* tslint:disable */
	/* eslint-disable */
	export function child_entry_point(ptr: number): void;
	/**
	 * Chroma subsampling format
	 */
	export enum ChromaSampling {
	  /**
	   * Both vertically and horizontally subsampled.
	   */
	  Cs420 = 0,
	  /**
	   * Horizontally subsampled.
	   */
	  Cs422 = 1,
	  /**
	   * Not subsampled.
	   */
	  Cs444 = 2,
	  /**
	   * Monochrome.
	   */
	  Cs400 = 3,
	}
	
}

declare type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

declare interface InitOutput {
  readonly main: (a: number, b: number) => number;
  readonly child_entry_point: (a: number) => void;
  readonly __externref_table_alloc: () => number;
  readonly __wbindgen_export_1: WebAssembly.Table;
  readonly memory: WebAssembly.Memory;
  readonly __wbindgen_exn_store: (a: number) => void;
  readonly __wbindgen_malloc: (a: number, b: number) => number;
  readonly __wbindgen_realloc: (a: number, b: number, c: number, d: number) => number;
  readonly __wbindgen_free: (a: number, b: number, c: number) => void;
  readonly __wbindgen_export_7: WebAssembly.Table;
  readonly closure56_externref_shim: (a: number, b: number, c: any) => void;
  readonly _dyn_core__ops__function__FnMut_____Output___R_as_wasm_bindgen__closure__WasmClosure___describe__invoke__h9bbecf469e0c8d50_multivalue_shim: (a: number, b: number) => [number, number];
  readonly __externref_table_dealloc: (a: number) => void;
  readonly closure135_externref_shim: (a: number, b: number, c: any) => void;
  readonly closure240_externref_shim: (a: number, b: number, c: any, d: any) => void;
  readonly __wbindgen_thread_destroy: (a?: number, b?: number, c?: number) => void;
  readonly __wbindgen_start: (a: number) => void;
}

/**
* If `module_or_path` is {RequestInfo} or {URL}, makes a request and
* for everything else, calls `WebAssembly.instantiate` directly.
*
* @param {{ module_or_path: InitInput | Promise<InitInput>, memory?: WebAssembly.Memory, thread_stack_size?: number }} module_or_path - Passing `InitInput` directly is deprecated.
* @param {WebAssembly.Memory} memory - Deprecated.
*
* @returns {Promise<InitOutput>}
*/
declare function wasm_bindgen (module_or_path?: { module_or_path: InitInput | Promise<InitInput>, memory?: WebAssembly.Memory, thread_stack_size?: number } | InitInput | Promise<InitInput>, memory?: WebAssembly.Memory): Promise<InitOutput>;
