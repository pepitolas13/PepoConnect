//! Bulk transfer engine: a TCP listener, a table of session keys, and jobs
//! that move one file each over an encrypted connection (see `wire`).
//!
//! Dart decides who connects (the side that opened the control channel) and
//! registers a job on both ends; the connection carries the transfer id so
//! the acceptor can match it. Progress, completion and errors are reported
//! through a callback (posted to a Dart port by the FFI layer).

use crate::wire::{self, FrameCipher, Header};
use std::collections::HashMap;
use std::fs::{File, OpenOptions};
use std::io::{self, BufReader, BufWriter, Read, Seek, SeekFrom, Write};
use std::net::{Shutdown, SocketAddr, TcpListener, TcpStream, ToSocketAddrs};
use std::sync::atomic::{AtomicBool, AtomicU16, Ordering};
use std::sync::{Arc, Condvar, Mutex};
use std::thread;
use std::time::{Duration, Instant};
use xxhash_rust::xxh3::Xxh3;

/// 1 MiB per frame: large enough to saturate a link, small enough to keep
/// memory flat with three connections in flight.
pub const CHUNK: usize = 1 << 20;
const CONNECT_TIMEOUT: Duration = Duration::from_secs(6);
const HEADER_TIMEOUT: Duration = Duration::from_secs(10);
const READY_TIMEOUT: Duration = Duration::from_secs(15);
const DATA_TIMEOUT: Duration = Duration::from_secs(30);
const ACK_TIMEOUT: Duration = Duration::from_secs(120);
const JOB_WAIT: Duration = Duration::from_secs(12);
const PENDING_TIMEOUT: Duration = Duration::from_secs(20);
const PROGRESS_EVERY: Duration = Duration::from_millis(100);

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Role {
    Send,
    Receive,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Event {
    Progress { job: u64, bytes: u64 },
    Done { job: u64, bytes: u64, hash: u64 },
    Error { job: u64, message: String },
}

pub type EventSink = Arc<dyn Fn(Event) + Send + Sync>;

pub struct Job {
    pub id: u64,
    pub transfer: u32,
    pub sid: [u8; 16],
    pub key: [u8; 32],
    pub role: Role,
    pub path: String,
    pub offset: u64,
    /// Receive: the size the sender announced (0 = unknown).
    pub size: u64,
    cancelled: AtomicBool,
    stream: Mutex<Option<TcpStream>>,
}

impl Job {
    pub fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::Relaxed)
    }
}

pub struct Engine {
    events: EventSink,
    sessions: Mutex<HashMap<[u8; 16], [u8; 32]>>,
    jobs: Mutex<HashMap<u64, Arc<Job>>>,
    /// Jobs waiting for the peer to connect, keyed by transfer id.
    pending: Mutex<HashMap<u32, Arc<Job>>>,
    pending_changed: Condvar,
    listener: Mutex<Option<TcpListener>>,
    port: AtomicU16,
    stopped: AtomicBool,
}

impl Engine {
    pub fn new(events: EventSink) -> Arc<Engine> {
        Arc::new(Engine {
            events,
            sessions: Mutex::new(HashMap::new()),
            jobs: Mutex::new(HashMap::new()),
            pending: Mutex::new(HashMap::new()),
            pending_changed: Condvar::new(),
            listener: Mutex::new(None),
            port: AtomicU16::new(0),
            stopped: AtomicBool::new(false),
        })
    }

    /// Binds the bulk listener on every IPv4 interface (peers are reached by
    /// their IPv4 address; a `::` socket is IPv6-only on Windows) and starts
    /// the accept loop. Returns the bound port.
    pub fn listen(self: &Arc<Self>, port: u16) -> io::Result<u16> {
        let listener = TcpListener::bind(("0.0.0.0", port))?;
        let bound = listener.local_addr()?.port();
        self.port.store(bound, Ordering::Relaxed);
        let accept = listener.try_clone()?;
        *self.listener.lock().unwrap() = Some(listener);
        let engine = Arc::clone(self);
        thread::Builder::new()
            .name("pepo-bulk-accept".into())
            .spawn(move || engine.accept_loop(accept))?;
        Ok(bound)
    }

    pub fn port(&self) -> u16 {
        self.port.load(Ordering::Relaxed)
    }

    pub fn add_session(&self, sid: [u8; 16], key: [u8; 32]) {
        self.sessions.lock().unwrap().insert(sid, key);
    }

    pub fn remove_session(&self, sid: &[u8; 16]) {
        self.sessions.lock().unwrap().remove(sid);
    }

    /// Starts a job. With `connect` the job dials the peer; otherwise it waits
    /// for the peer to connect to our listener with the same transfer id.
    #[allow(clippy::too_many_arguments)]
    pub fn start(
        self: &Arc<Self>,
        id: u64,
        transfer: u32,
        sid: [u8; 16],
        key: [u8; 32],
        role: Role,
        path: String,
        offset: u64,
        size: u64,
        connect: Option<(String, u16)>,
    ) -> Result<(), String> {
        if self.stopped.load(Ordering::Relaxed) {
            return Err("engine stopped".into());
        }
        let job = Arc::new(Job {
            id,
            transfer,
            sid,
            key,
            role,
            path,
            offset,
            size,
            cancelled: AtomicBool::new(false),
            stream: Mutex::new(None),
        });
        {
            let mut jobs = self.jobs.lock().unwrap();
            if jobs.contains_key(&id) {
                return Err(format!("job {id} already exists"));
            }
            jobs.insert(id, Arc::clone(&job));
        }
        match connect {
            Some((host, port)) => {
                let engine = Arc::clone(self);
                thread::Builder::new()
                    .name(format!("pepo-bulk-out-{transfer}"))
                    .spawn(move || engine.run_outbound(job, host, port))
                    .map_err(|e| e.to_string())?;
            }
            None => {
                {
                    let mut pending = self.pending.lock().unwrap();
                    pending.insert(transfer, Arc::clone(&job));
                    self.pending_changed.notify_all();
                }
                // Nobody waits forever: if the peer never connects, report it.
                let engine = Arc::clone(self);
                let _ = thread::Builder::new()
                    .name(format!("pepo-bulk-wait-{transfer}"))
                    .spawn(move || {
                        thread::sleep(PENDING_TIMEOUT);
                        let still_pending = engine
                            .pending
                            .lock()
                            .unwrap()
                            .get(&transfer)
                            .map(|j| Arc::ptr_eq(j, &job))
                            .unwrap_or(false);
                        if still_pending {
                            engine.pending.lock().unwrap().remove(&transfer);
                            engine.finish(&job, Err("peer did not connect".into()));
                        }
                    });
            }
        }
        Ok(())
    }

    pub fn cancel(&self, id: u64) {
        let job = self.jobs.lock().unwrap().get(&id).cloned();
        if let Some(job) = job {
            job.cancelled.store(true, Ordering::Relaxed);
            if let Some(s) = job.stream.lock().unwrap().as_ref() {
                let _ = s.shutdown(Shutdown::Both);
            }
            let was_pending = self.pending.lock().unwrap().remove(&job.transfer).is_some();
            if was_pending {
                self.finish(&job, Err("cancelled".into()));
            }
        }
    }

    pub fn stop(&self) {
        self.stopped.store(true, Ordering::Relaxed);
        let ids: Vec<u64> = self.jobs.lock().unwrap().keys().copied().collect();
        for id in ids {
            self.cancel(id);
        }
        if let Some(l) = self.listener.lock().unwrap().take() {
            // Unblock accept() by connecting to ourselves.
            let port = l.local_addr().map(|a| a.port()).unwrap_or(0);
            drop(l);
            if port != 0 {
                let _ = TcpStream::connect_timeout(
                    &SocketAddr::from(([127, 0, 0, 1], port)),
                    Duration::from_millis(200),
                );
            }
        }
    }

    // -------------------------------------------------------------------------

    fn accept_loop(self: Arc<Self>, listener: TcpListener) {
        loop {
            if self.stopped.load(Ordering::Relaxed) {
                return;
            }
            match listener.accept() {
                Ok((stream, _)) => {
                    if self.stopped.load(Ordering::Relaxed) {
                        return;
                    }
                    let engine = Arc::clone(&self);
                    let _ = thread::Builder::new()
                        .name("pepo-bulk-in".into())
                        .spawn(move || engine.run_inbound(stream));
                }
                Err(_) => {
                    if self.stopped.load(Ordering::Relaxed) {
                        return;
                    }
                    thread::sleep(Duration::from_millis(50));
                }
            }
        }
    }

    fn run_inbound(self: Arc<Self>, mut stream: TcpStream) {
        let _ = stream.set_read_timeout(Some(HEADER_TIMEOUT));
        let mut raw = [0u8; wire::HEADER_LEN];
        if stream.read_exact(&mut raw).is_err() {
            return;
        }
        let header = match Header::decode(&raw) {
            Ok(h) => h,
            Err(_) => return,
        };
        let session_key = match self.sessions.lock().unwrap().get(&header.sid) {
            Some(k) => *k,
            None => return, // not one of our sessions: drop silently
        };
        // The job may be registered a moment after the peer connected.
        let job = {
            let deadline = Instant::now() + JOB_WAIT;
            let mut pending = self.pending.lock().unwrap();
            loop {
                if let Some(j) = pending.remove(&header.transfer) {
                    break Some(j);
                }
                let now = Instant::now();
                if now >= deadline || self.stopped.load(Ordering::Relaxed) {
                    break None;
                }
                let (guard, _) = self
                    .pending_changed
                    .wait_timeout(pending, deadline - now)
                    .unwrap();
                pending = guard;
            }
        };
        let job = match job {
            Some(j) => j,
            None => return,
        };
        if job.sid != header.sid || job.key != session_key {
            self.finish(&job, Err("session mismatch".into()));
            return;
        }
        let expected_role = match job.role {
            Role::Send => wire::ROLE_CONNECTOR_RECEIVES,
            Role::Receive => wire::ROLE_CONNECTOR_SENDS,
        };
        if header.role != expected_role {
            self.finish(&job, Err("role mismatch".into()));
            return;
        }
        let key = wire::connection_key(&session_key, &header.salt);
        let result = self.run_connection(&job, stream, key, false);
        self.finish(&job, result);
    }

    fn run_outbound(self: Arc<Self>, job: Arc<Job>, host: String, port: u16) {
        let result = self.connect_and_run(&job, &host, port);
        self.finish(&job, result);
    }

    fn connect_and_run(&self, job: &Arc<Job>, host: &str, port: u16) -> Result<(u64, u64), String> {
        let addrs: Vec<SocketAddr> = (host, port)
            .to_socket_addrs()
            .map_err(|e| format!("resolve {host}: {e}"))?
            .collect();
        let mut last = String::from("no address");
        let mut stream = None;
        for addr in addrs {
            if job.is_cancelled() {
                return Err("cancelled".into());
            }
            match TcpStream::connect_timeout(&addr, CONNECT_TIMEOUT) {
                Ok(s) => {
                    stream = Some(s);
                    break;
                }
                Err(e) => last = format!("connect {addr}: {e}"),
            }
        }
        let mut stream = stream.ok_or(last)?;
        let mut salt = [0u8; 16];
        getrandom::getrandom(&mut salt).map_err(|e| e.to_string())?;
        let header = Header {
            role: match job.role {
                Role::Send => wire::ROLE_CONNECTOR_SENDS,
                Role::Receive => wire::ROLE_CONNECTOR_RECEIVES,
            },
            sid: job.sid,
            transfer: job.transfer,
            salt,
        };
        stream.write_all(&header.encode()).map_err(|e| e.to_string())?;
        let key = wire::connection_key(&job.key, &salt);
        self.run_connection(job, stream, key, true)
    }

    /// Runs the framed protocol on an established connection. Returns
    /// (bytes moved, xxh3 hash of them).
    fn run_connection(
        &self,
        job: &Arc<Job>,
        stream: TcpStream,
        key: [u8; 32],
        connector: bool,
    ) -> Result<(u64, u64), String> {
        let _ = stream.set_nodelay(true);
        let _ = stream.set_read_timeout(Some(READY_TIMEOUT));
        let _ = stream.set_write_timeout(Some(DATA_TIMEOUT));
        *job.stream.lock().unwrap() = stream.try_clone().ok();
        let mut cipher = FrameCipher::new(&key, connector);
        let mut reader = BufReader::with_capacity(256 * 1024, stream.try_clone().map_err(|e| e.to_string())?);
        let mut writer = BufWriter::with_capacity(256 * 1024, stream);
        let mut buf: Vec<u8> = Vec::with_capacity(CHUNK + 64);

        // Ready handshake: the acceptor confirms the transfer and offset.
        if connector {
            cipher.read_frame(&mut reader, &mut buf).map_err(|e| format!("waiting for peer: {e}"))?;
            if buf.first() != Some(&wire::KIND_READY) {
                return Err("peer refused the transfer".into());
            }
            let their_offset = wire::read_u64(&buf[1..]).ok_or("bad ready frame")?;
            if their_offset != job.offset {
                return Err(format!("offset mismatch: {} vs {}", their_offset, job.offset));
            }
        } else {
            let mut f = wire::frame_ready(job.offset);
            cipher.write_frame(&mut writer, &mut f).map_err(|e| e.to_string())?;
            writer.flush().map_err(|e| e.to_string())?;
        }
        let _ = reader.get_ref().set_read_timeout(Some(DATA_TIMEOUT));

        match job.role {
            Role::Send => self.send_file(job, &mut cipher, &mut reader, &mut writer, &mut buf),
            Role::Receive => self.receive_file(job, &mut cipher, &mut reader, &mut writer, &mut buf),
        }
    }

    fn send_file(
        &self,
        job: &Arc<Job>,
        cipher: &mut FrameCipher,
        reader: &mut BufReader<TcpStream>,
        writer: &mut BufWriter<TcpStream>,
        buf: &mut Vec<u8>,
    ) -> Result<(u64, u64), String> {
        let mut file = File::open(&job.path).map_err(|e| format!("open {}: {e}", job.path))?;
        file.seek(SeekFrom::Start(job.offset)).map_err(|e| e.to_string())?;
        let mut hasher = Xxh3::new();
        let mut sent: u64 = 0;
        let mut offset = job.offset;
        let mut last_report = Instant::now();
        let mut chunk = vec![0u8; CHUNK];
        loop {
            if job.is_cancelled() {
                let mut f = wire::frame_abort("cancelled");
                let _ = cipher.write_frame(writer, &mut f);
                let _ = writer.flush();
                return Err("cancelled".into());
            }
            let n = read_full(&mut file, &mut chunk).map_err(|e| format!("read: {e}"))?;
            if n == 0 {
                break;
            }
            hasher.update(&chunk[..n]);
            buf.clear();
            buf.push(wire::KIND_DATA);
            buf.extend_from_slice(&offset.to_be_bytes());
            buf.extend_from_slice(&chunk[..n]);
            cipher.write_frame(writer, buf).map_err(|e| format!("send: {e}"))?;
            offset += n as u64;
            sent += n as u64;
            if last_report.elapsed() >= PROGRESS_EVERY {
                last_report = Instant::now();
                (self.events)(Event::Progress { job: job.id, bytes: offset });
            }
        }
        let hash = hasher.digest();
        let mut f = wire::frame_eof(hash, sent);
        cipher.write_frame(writer, &mut f).map_err(|e| format!("send: {e}"))?;
        writer.flush().map_err(|e| format!("send: {e}"))?;
        (self.events)(Event::Progress { job: job.id, bytes: offset });
        let _ = reader.get_ref().set_read_timeout(Some(ACK_TIMEOUT));
        cipher.read_frame(reader, buf).map_err(|e| format!("waiting for ack: {e}"))?;
        match buf.first() {
            Some(&wire::KIND_ACK) => {
                let ok = buf.get(9).copied().unwrap_or(0) == 1;
                if ok {
                    Ok((sent, hash))
                } else {
                    Err("peer rejected the data (hash mismatch)".into())
                }
            }
            Some(&wire::KIND_ABORT) => Err(abort_reason(buf)),
            _ => Err("unexpected reply".into()),
        }
    }

    fn receive_file(
        &self,
        job: &Arc<Job>,
        cipher: &mut FrameCipher,
        reader: &mut BufReader<TcpStream>,
        writer: &mut BufWriter<TcpStream>,
        buf: &mut Vec<u8>,
    ) -> Result<(u64, u64), String> {
        let mut file = OpenOptions::new()
            .create(true)
            .write(true)
            .open(&job.path)
            .map_err(|e| format!("open {}: {e}", job.path))?;
        file.set_len(job.offset).map_err(|e| e.to_string())?;
        file.seek(SeekFrom::Start(job.offset)).map_err(|e| e.to_string())?;
        let mut out = BufWriter::with_capacity(CHUNK, file);
        let mut hasher = Xxh3::new();
        let mut expected = job.offset;
        let mut received: u64 = 0;
        let mut last_report = Instant::now();
        loop {
            if job.is_cancelled() {
                let mut f = wire::frame_abort("cancelled");
                let _ = cipher.write_frame(writer, &mut f);
                let _ = writer.flush();
                let _ = out.flush();
                return Err("cancelled".into());
            }
            cipher.read_frame(reader, buf).map_err(|e| format!("receive: {e}"))?;
            match buf.first().copied() {
                Some(wire::KIND_DATA) => {
                    let offset = wire::read_u64(&buf[1..]).ok_or("bad data frame")?;
                    if offset != expected {
                        return Err(format!("out of order data: {offset} != {expected}"));
                    }
                    let data = &buf[9..];
                    if job.size > 0 && expected + data.len() as u64 > job.size {
                        return Err("more data than announced".into());
                    }
                    out.write_all(data).map_err(|e| format!("write: {e}"))?;
                    hasher.update(data);
                    expected += data.len() as u64;
                    received += data.len() as u64;
                    if last_report.elapsed() >= PROGRESS_EVERY {
                        last_report = Instant::now();
                        (self.events)(Event::Progress { job: job.id, bytes: expected });
                    }
                }
                Some(wire::KIND_EOF) => {
                    let their_hash = wire::read_u64(&buf[1..]).ok_or("bad eof frame")?;
                    let their_bytes = wire::read_u64(&buf[9..]).ok_or("bad eof frame")?;
                    out.flush().map_err(|e| format!("write: {e}"))?;
                    out.get_ref().sync_data().map_err(|e| format!("sync: {e}"))?;
                    let hash = hasher.digest();
                    let ok = their_hash == hash && their_bytes == received;
                    let mut f = wire::frame_ack(received, ok);
                    cipher.write_frame(writer, &mut f).map_err(|e| e.to_string())?;
                    writer.flush().map_err(|e| e.to_string())?;
                    (self.events)(Event::Progress { job: job.id, bytes: expected });
                    return if ok {
                        Ok((received, hash))
                    } else {
                        Err("hash mismatch".into())
                    };
                }
                Some(wire::KIND_ABORT) => {
                    let _ = out.flush();
                    return Err(abort_reason(buf));
                }
                _ => return Err("unexpected frame".into()),
            }
        }
    }

    fn finish(&self, job: &Arc<Job>, result: Result<(u64, u64), String>) {
        self.jobs.lock().unwrap().remove(&job.id);
        self.pending.lock().unwrap().remove(&job.transfer);
        if let Some(s) = job.stream.lock().unwrap().take() {
            let _ = s.shutdown(Shutdown::Both);
        }
        match result {
            Ok((bytes, hash)) => (self.events)(Event::Done { job: job.id, bytes, hash }),
            Err(message) => {
                let message = if job.is_cancelled() { "cancelled".to_string() } else { message };
                (self.events)(Event::Error { job: job.id, message })
            }
        }
    }
}

fn abort_reason(buf: &[u8]) -> String {
    let reason = String::from_utf8_lossy(&buf[1..]);
    if reason.is_empty() {
        "aborted by peer".into()
    } else {
        format!("peer: {reason}")
    }
}

/// Reads until `buf` is full or EOF.
fn read_full(file: &mut File, buf: &mut [u8]) -> io::Result<usize> {
    let mut total = 0;
    while total < buf.len() {
        match file.read(&mut buf[total..]) {
            Ok(0) => break,
            Ok(n) => total += n,
            Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
            Err(e) => return Err(e),
        }
    }
    Ok(total)
}
