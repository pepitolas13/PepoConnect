//! Two engines in one process, talking over loopback.

use pepo_native::{Engine, Event, EventSink, Role};
use std::fs;
use std::path::PathBuf;
use std::sync::mpsc::{channel, Receiver, Sender};
use std::sync::Arc;
use std::time::{Duration, Instant};
use xxhash_rust::xxh3::xxh3_64;

fn sink(tx: Sender<Event>) -> EventSink {
    Arc::new(move |e| {
        let _ = tx.send(e);
    })
}

fn temp_dir(name: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("pepo_native_{name}_{}", std::process::id()));
    let _ = fs::remove_dir_all(&dir);
    fs::create_dir_all(&dir).unwrap();
    dir
}

fn random_file(path: &PathBuf, size: usize, seed: u64) -> Vec<u8> {
    let mut data = vec![0u8; size];
    let mut x = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
    for b in data.iter_mut() {
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        *b = x as u8;
    }
    fs::write(path, &data).unwrap();
    data
}

fn wait_done(rx: &Receiver<Event>, job: u64, timeout: Duration) -> Result<(u64, u64), String> {
    let deadline = Instant::now() + timeout;
    loop {
        let left = deadline.saturating_duration_since(Instant::now());
        match rx.recv_timeout(left) {
            Ok(Event::Done { job: j, bytes, hash }) if j == job => return Ok((bytes, hash)),
            Ok(Event::Error { job: j, message }) if j == job => return Err(message),
            Ok(_) => continue,
            Err(_) => return Err("timeout".into()),
        }
    }
}

struct Pair {
    a: Arc<Engine>,
    b: Arc<Engine>,
    a_rx: Receiver<Event>,
    b_rx: Receiver<Event>,
    a_port: u16,
    sid: [u8; 16],
    key: [u8; 32],
}

fn pair() -> Pair {
    let (atx, a_rx) = channel();
    let (btx, b_rx) = channel();
    let a = Engine::new(sink(atx));
    let b = Engine::new(sink(btx));
    let a_port = a.listen(0).unwrap();
    let sid = [3u8; 16];
    let key = [5u8; 32];
    a.add_session(sid, key);
    b.add_session(sid, key);
    Pair { a, b, a_rx, b_rx, a_port, sid, key }
}

#[test]
fn b_connects_and_sends_to_a() {
    let p = pair();
    let dir = temp_dir("send");
    let src = dir.join("src.bin");
    let data = random_file(&src, 20 * 1024 * 1024 + 12345, 1);
    let dst = dir.join("dst.bin");
    p.a.start(1, 77, p.sid, p.key, Role::Receive, dst.to_string_lossy().into(), 0, data.len() as u64, None)
        .unwrap();
    p.b.start(
        2,
        77,
        p.sid,
        p.key,
        Role::Send,
        src.to_string_lossy().into(),
        0,
        0,
        Some(("127.0.0.1".into(), p.a_port)),
    )
    .unwrap();
    let (rb, hb) = wait_done(&p.b_rx, 2, Duration::from_secs(30)).unwrap();
    let (ra, ha) = wait_done(&p.a_rx, 1, Duration::from_secs(30)).unwrap();
    assert_eq!(rb, data.len() as u64);
    assert_eq!(ra, data.len() as u64);
    assert_eq!(hb, xxh3_64(&data));
    assert_eq!(ha, hb);
    assert_eq!(fs::read(&dst).unwrap(), data);
}

#[test]
fn b_connects_and_receives_from_a() {
    let p = pair();
    let dir = temp_dir("recv");
    let src = dir.join("src.bin");
    let data = random_file(&src, 5 * 1024 * 1024 + 7, 2);
    let dst = dir.join("dst.bin");
    p.a.start(1, 9, p.sid, p.key, Role::Send, src.to_string_lossy().into(), 0, 0, None).unwrap();
    p.b.start(
        2,
        9,
        p.sid,
        p.key,
        Role::Receive,
        dst.to_string_lossy().into(),
        0,
        data.len() as u64,
        Some(("127.0.0.1".into(), p.a_port)),
    )
    .unwrap();
    wait_done(&p.a_rx, 1, Duration::from_secs(30)).unwrap();
    wait_done(&p.b_rx, 2, Duration::from_secs(30)).unwrap();
    assert_eq!(fs::read(&dst).unwrap(), data);
}

#[test]
fn resumes_from_offset() {
    let p = pair();
    let dir = temp_dir("resume");
    let src = dir.join("src.bin");
    let data = random_file(&src, 8 * 1024 * 1024, 3);
    let dst = dir.join("dst.bin");
    let offset = 3 * 1024 * 1024 + 100;
    fs::write(&dst, &data[..offset]).unwrap();
    p.a.start(1, 5, p.sid, p.key, Role::Receive, dst.to_string_lossy().into(), offset as u64, data.len() as u64, None)
        .unwrap();
    p.b.start(
        2,
        5,
        p.sid,
        p.key,
        Role::Send,
        src.to_string_lossy().into(),
        offset as u64,
        0,
        Some(("127.0.0.1".into(), p.a_port)),
    )
    .unwrap();
    let (rb, hb) = wait_done(&p.b_rx, 2, Duration::from_secs(30)).unwrap();
    let (ra, ha) = wait_done(&p.a_rx, 1, Duration::from_secs(30)).unwrap();
    assert_eq!(rb, (data.len() - offset) as u64);
    assert_eq!(ra, rb);
    assert_eq!(hb, xxh3_64(&data[offset..]));
    assert_eq!(ha, hb);
    assert_eq!(fs::read(&dst).unwrap(), data);
}

#[test]
fn cancel_stops_both_sides() {
    let p = pair();
    let dir = temp_dir("cancel");
    let src = dir.join("src.bin");
    // Big enough that the transfer is still running when the first progress
    // event (100 ms) arrives, even at several hundred MB/s.
    let size = 768 * 1024 * 1024;
    random_file(&src, size, 4);
    let dst = dir.join("dst.bin");
    p.a.start(1, 8, p.sid, p.key, Role::Receive, dst.to_string_lossy().into(), 0, size as u64, None)
        .unwrap();
    p.b.start(
        2,
        8,
        p.sid,
        p.key,
        Role::Send,
        src.to_string_lossy().into(),
        0,
        0,
        Some(("127.0.0.1".into(), p.a_port)),
    )
    .unwrap();
    // Wait for some progress, then cancel the sender.
    let deadline = Instant::now() + Duration::from_secs(20);
    loop {
        match p.b_rx.recv_timeout(deadline - Instant::now()) {
            Ok(Event::Progress { bytes, .. }) if bytes > 0 => break,
            Ok(Event::Done { .. }) => panic!("finished before cancel"),
            Ok(_) => continue,
            Err(_) => panic!("no progress"),
        }
    }
    p.b.cancel(2);
    assert_eq!(wait_done(&p.b_rx, 2, Duration::from_secs(20)), Err("cancelled".to_string()));
    let a = wait_done(&p.a_rx, 1, Duration::from_secs(20));
    assert!(a.is_err(), "receiver must not report success");
}

#[test]
fn unknown_session_is_dropped() {
    let p = pair();
    let dir = temp_dir("unknown");
    let src = dir.join("src.bin");
    random_file(&src, 1024, 5);
    let other_sid = [9u8; 16];
    p.b.add_session(other_sid, p.key);
    p.b.start(
        2,
        1,
        other_sid,
        p.key,
        Role::Send,
        src.to_string_lossy().into(),
        0,
        0,
        Some(("127.0.0.1".into(), p.a_port)),
    )
    .unwrap();
    assert!(wait_done(&p.b_rx, 2, Duration::from_secs(30)).is_err());
}

#[test]
fn wrong_key_is_rejected() {
    let p = pair();
    let dir = temp_dir("wrongkey");
    let src = dir.join("src.bin");
    random_file(&src, 1024 * 1024, 6);
    let dst = dir.join("dst.bin");
    p.a.start(1, 2, p.sid, p.key, Role::Receive, dst.to_string_lossy().into(), 0, 0, None).unwrap();
    let mut bad = p.key;
    bad[0] ^= 1;
    p.b.start(
        2,
        2,
        p.sid,
        bad,
        Role::Send,
        src.to_string_lossy().into(),
        0,
        0,
        Some(("127.0.0.1".into(), p.a_port)),
    )
    .unwrap();
    assert!(wait_done(&p.b_rx, 2, Duration::from_secs(30)).is_err());
    assert!(wait_done(&p.a_rx, 1, Duration::from_secs(30)).is_err());
}

#[test]
#[ignore = "throughput: run with --ignored --release"]
fn throughput_512mb() {
    let p = pair();
    let dir = temp_dir("perf");
    let src = dir.join("src.bin");
    let size = 512usize * 1024 * 1024;
    {
        let mut f = fs::File::create(&src).unwrap();
        use std::io::Write;
        let block: Vec<u8> = (0..(1 << 20)).map(|i| (i * 7 % 251) as u8).collect();
        for _ in 0..512 {
            f.write_all(&block).unwrap();
        }
    }
    let dst = dir.join("dst.bin");
    let t0 = Instant::now();
    p.a.start(1, 3, p.sid, p.key, Role::Receive, dst.to_string_lossy().into(), 0, size as u64, None)
        .unwrap();
    p.b.start(
        2,
        3,
        p.sid,
        p.key,
        Role::Send,
        src.to_string_lossy().into(),
        0,
        0,
        Some(("127.0.0.1".into(), p.a_port)),
    )
    .unwrap();
    wait_done(&p.b_rx, 2, Duration::from_secs(120)).unwrap();
    wait_done(&p.a_rx, 1, Duration::from_secs(120)).unwrap();
    let secs = t0.elapsed().as_secs_f64();
    println!("512 MB in {:.2} s = {:.0} MB/s", secs, 512.0 / secs);
    assert_eq!(fs::metadata(&dst).unwrap().len(), size as u64);
}
