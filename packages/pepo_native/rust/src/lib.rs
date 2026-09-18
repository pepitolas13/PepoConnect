//! C ABI used by `pepo_core` (Dart, `dart:ffi`).
//!
//! Every function is safe to call from any thread and never panics across
//! the boundary. Events are posted to a Dart `ReceivePort` as strings:
//! `p\t<job>\t<bytes>`, `d\t<job>\t<bytes>\t<xxh3 hex>` and
//! `e\t<job>\t<message>`.

mod engine;
pub mod wire;

pub use engine::{Engine, Event, EventSink, Role};

use allo_isolate::Isolate;
use std::ffi::{c_char, c_void, CStr};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::Arc;

/// Bumped whenever the C ABI or the wire protocol changes incompatibly.
pub const ABI_VERSION: u32 = 1;

pub struct EngineHandle {
    engine: Arc<Engine>,
}

fn guard<T>(default: T, f: impl FnOnce() -> T) -> T {
    catch_unwind(AssertUnwindSafe(f)).unwrap_or(default)
}

unsafe fn c_str(p: *const c_char) -> Option<String> {
    if p.is_null() {
        return None;
    }
    CStr::from_ptr(p).to_str().ok().map(|s| s.to_string())
}

unsafe fn bytes16(p: *const u8) -> Option<[u8; 16]> {
    if p.is_null() {
        return None;
    }
    let mut out = [0u8; 16];
    out.copy_from_slice(std::slice::from_raw_parts(p, 16));
    Some(out)
}

unsafe fn bytes32(p: *const u8) -> Option<[u8; 32]> {
    if p.is_null() {
        return None;
    }
    let mut out = [0u8; 32];
    out.copy_from_slice(std::slice::from_raw_parts(p, 32));
    Some(out)
}

fn event_text(e: &Event) -> String {
    match e {
        Event::Progress { job, bytes } => format!("p\t{job}\t{bytes}"),
        Event::Done { job, bytes, hash } => format!("d\t{job}\t{bytes}\t{hash:016x}"),
        Event::Error { job, message } => format!("e\t{job}\t{}", message.replace(['\t', '\n'], " ")),
    }
}

#[no_mangle]
pub extern "C" fn pepo_native_abi_version() -> u32 {
    ABI_VERSION
}

/// Stores Dart's `NativeApi.postCObject` so events can reach a `ReceivePort`.
/// Must be called once before any engine posts events.
///
/// # Safety
/// `post_cobject` must be the address of `Dart_PostCObject`.
#[no_mangle]
pub unsafe extern "C" fn pepo_native_init_dart(post_cobject: *mut c_void) -> i32 {
    if post_cobject.is_null() {
        return -1;
    }
    let f: allo_isolate::ffi::DartPostCObjectFnType = std::mem::transmute(post_cobject);
    allo_isolate::store_dart_post_cobject(f);
    0
}

/// Creates an engine whose events go to the Dart port `event_port`.
#[no_mangle]
pub extern "C" fn pepo_native_new(event_port: i64) -> *mut EngineHandle {
    guard(std::ptr::null_mut(), || {
        let isolate = Isolate::new(event_port);
        let sink: EventSink = Arc::new(move |e: Event| {
            isolate.post(event_text(&e));
        });
        Box::into_raw(Box::new(EngineHandle { engine: Engine::new(sink) }))
    })
}

/// Stops every job, closes the listener and frees the engine.
///
/// # Safety
/// `h` must come from `pepo_native_new` and not be used afterwards.
#[no_mangle]
pub unsafe extern "C" fn pepo_native_free(h: *mut EngineHandle) {
    if h.is_null() {
        return;
    }
    let handle = Box::from_raw(h);
    guard((), || handle.engine.stop());
}

/// Binds the bulk listener on `port` (0 = any) and returns the bound port,
/// or -1.
///
/// # Safety
/// `h` must be a live engine.
#[no_mangle]
pub unsafe extern "C" fn pepo_native_listen(h: *mut EngineHandle, port: u16) -> i32 {
    if h.is_null() {
        return -1;
    }
    let engine = &(*h).engine;
    guard(-1, || match engine.listen(port) {
        Ok(p) => p as i32,
        Err(_) => -1,
    })
}

/// # Safety
/// `sid` points to 16 bytes and `key` to 32 bytes.
#[no_mangle]
pub unsafe extern "C" fn pepo_native_session_add(
    h: *mut EngineHandle,
    sid: *const u8,
    key: *const u8,
) -> i32 {
    if h.is_null() {
        return -1;
    }
    let (Some(sid), Some(key)) = (bytes16(sid), bytes32(key)) else {
        return -1;
    };
    guard(-1, || {
        (*h).engine.add_session(sid, key);
        0
    })
}

/// # Safety
/// `sid` points to 16 bytes.
#[no_mangle]
pub unsafe extern "C" fn pepo_native_session_remove(h: *mut EngineHandle, sid: *const u8) -> i32 {
    if h.is_null() {
        return -1;
    }
    let Some(sid) = bytes16(sid) else {
        return -1;
    };
    guard(-1, || {
        (*h).engine.remove_session(&sid);
        0
    })
}

/// Starts a job. `role` is 0 to send `path` from `offset`, 1 to receive into
/// `path` (which is truncated to `offset` first; `size` is the announced
/// total, 0 if unknown). With a non-null `host` the job connects to
/// `host:port`; otherwise it waits for the peer to connect to our listener
/// with the same transfer id. Returns 0, or -1 on bad arguments.
///
/// # Safety
/// Pointers must be valid; strings are NUL-terminated UTF-8.
#[no_mangle]
pub unsafe extern "C" fn pepo_native_start(
    h: *mut EngineHandle,
    job: u64,
    transfer: u32,
    sid: *const u8,
    key: *const u8,
    role: u8,
    path: *const c_char,
    offset: u64,
    size: u64,
    host: *const c_char,
    port: u16,
) -> i32 {
    if h.is_null() {
        return -1;
    }
    let (Some(sid), Some(key), Some(path)) = (bytes16(sid), bytes32(key), c_str(path)) else {
        return -1;
    };
    let role = match role {
        0 => Role::Send,
        1 => Role::Receive,
        _ => return -1,
    };
    let connect = c_str(host).map(|hst| (hst, port));
    guard(-1, || {
        match (*h).engine.start(job, transfer, sid, key, role, path, offset, size, connect) {
            Ok(()) => 0,
            Err(_) => -1,
        }
    })
}

/// # Safety
/// `h` must be a live engine.
#[no_mangle]
pub unsafe extern "C" fn pepo_native_cancel(h: *mut EngineHandle, job: u64) {
    if h.is_null() {
        return;
    }
    guard((), || (*h).engine.cancel(job));
}

/// xxh3-64 of a byte range (lets the Dart side check it agrees with its
/// own implementation).
///
/// # Safety
/// `data` points to `len` readable bytes.
#[no_mangle]
pub unsafe extern "C" fn pepo_native_xxh3(data: *const u8, len: usize) -> u64 {
    if data.is_null() {
        return 0;
    }
    let slice = std::slice::from_raw_parts(data, len);
    xxhash_rust::xxh3::xxh3_64(slice)
}
