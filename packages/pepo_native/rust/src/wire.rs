//! Framing and encryption of one bulk connection.
//!
//! The connector opens a TCP connection and sends a plaintext header:
//!
//! ```text
//! magic "PEPO2\0" (6) | protocol u8 | role u8 | session id (16) | transfer u32 BE | salt (16)
//! ```
//!
//! `role` says what the connector does with the file (0 = it sends, 1 = it
//! receives). Both sides derive a per-connection key with HKDF-SHA256 from
//! the session key and the salt, so a nonce can never repeat across
//! connections. Everything after the header is `u32 BE length | AES-256-GCM
//! ciphertext` of a plaintext frame; the nonce is `direction byte | 3 zero
//! bytes | u64 BE counter`, one counter per direction.

use aes_gcm::aead::{AeadInPlace, KeyInit};
use aes_gcm::{Aes256Gcm, Nonce};
use hkdf::Hkdf;
use sha2::Sha256;
use std::io::{self, Read, Write};

pub const MAGIC: &[u8; 6] = b"PEPO2\0";
pub const PROTOCOL: u8 = 1;
pub const HEADER_LEN: usize = 6 + 1 + 1 + 16 + 4 + 16;
pub const ROLE_CONNECTOR_SENDS: u8 = 0;
pub const ROLE_CONNECTOR_RECEIVES: u8 = 1;
pub const TAG_LEN: usize = 16;
/// Largest plaintext frame we accept (1 MiB of data plus the frame header).
pub const MAX_PLAINTEXT: usize = (1 << 20) + 64;

pub const KIND_DATA: u8 = 1;
pub const KIND_READY: u8 = 2;
pub const KIND_EOF: u8 = 3;
pub const KIND_ACK: u8 = 4;
pub const KIND_ABORT: u8 = 5;

pub struct Header {
    pub role: u8,
    pub sid: [u8; 16],
    pub transfer: u32,
    pub salt: [u8; 16],
}

impl Header {
    pub fn encode(&self) -> [u8; HEADER_LEN] {
        let mut out = [0u8; HEADER_LEN];
        out[..6].copy_from_slice(MAGIC);
        out[6] = PROTOCOL;
        out[7] = self.role;
        out[8..24].copy_from_slice(&self.sid);
        out[24..28].copy_from_slice(&self.transfer.to_be_bytes());
        out[28..44].copy_from_slice(&self.salt);
        out
    }

    pub fn decode(buf: &[u8; HEADER_LEN]) -> Result<Header, String> {
        if &buf[..6] != MAGIC {
            return Err("not a PepoConnect bulk connection".into());
        }
        if buf[6] != PROTOCOL {
            return Err(format!("unsupported bulk protocol {}", buf[6]));
        }
        let role = buf[7];
        if role != ROLE_CONNECTOR_SENDS && role != ROLE_CONNECTOR_RECEIVES {
            return Err("bad role".into());
        }
        let mut sid = [0u8; 16];
        sid.copy_from_slice(&buf[8..24]);
        let transfer = u32::from_be_bytes([buf[24], buf[25], buf[26], buf[27]]);
        let mut salt = [0u8; 16];
        salt.copy_from_slice(&buf[28..44]);
        Ok(Header { role, sid, transfer, salt })
    }
}

/// Per-connection key: HKDF-SHA256(session key, salt, "pepo-bulk-conn-v1").
pub fn connection_key(session_key: &[u8; 32], salt: &[u8; 16]) -> [u8; 32] {
    let hk = Hkdf::<Sha256>::new(Some(salt), session_key);
    let mut out = [0u8; 32];
    hk.expand(b"pepo-bulk-conn-v1", &mut out).expect("32 bytes is a valid HKDF length");
    out
}

/// Encrypts and decrypts frames on one connection.
pub struct FrameCipher {
    cipher: Aes256Gcm,
    send_dir: u8,
    recv_dir: u8,
    send_ctr: u64,
    recv_ctr: u64,
}

impl FrameCipher {
    /// `connector` is true on the side that opened the TCP connection.
    pub fn new(key: &[u8; 32], connector: bool) -> FrameCipher {
        FrameCipher {
            cipher: Aes256Gcm::new(key.into()),
            send_dir: if connector { 0 } else { 1 },
            recv_dir: if connector { 1 } else { 0 },
            send_ctr: 0,
            recv_ctr: 0,
        }
    }

    fn nonce(dir: u8, ctr: u64) -> [u8; 12] {
        let mut n = [0u8; 12];
        n[0] = dir;
        n[4..].copy_from_slice(&ctr.to_be_bytes());
        n
    }

    /// Encrypts `frame` in place (appending the tag) and writes it prefixed
    /// with its length. `frame` must have capacity for the tag.
    pub fn write_frame<W: Write>(&mut self, w: &mut W, frame: &mut Vec<u8>) -> io::Result<()> {
        let nonce = Self::nonce(self.send_dir, self.send_ctr);
        self.send_ctr = self.send_ctr.wrapping_add(1);
        let tag = self
            .cipher
            .encrypt_in_place_detached(Nonce::from_slice(&nonce), b"", frame)
            .map_err(|_| io::Error::new(io::ErrorKind::Other, "encrypt failed"))?;
        frame.extend_from_slice(&tag);
        let len = (frame.len() as u32).to_be_bytes();
        w.write_all(&len)?;
        w.write_all(frame)?;
        Ok(())
    }

    /// Reads one frame into `buf` (cleared first) and decrypts it in place.
    pub fn read_frame<R: Read>(&mut self, r: &mut R, buf: &mut Vec<u8>) -> io::Result<()> {
        let mut len = [0u8; 4];
        r.read_exact(&mut len)?;
        let len = u32::from_be_bytes(len) as usize;
        if len < TAG_LEN || len > MAX_PLAINTEXT + TAG_LEN {
            return Err(io::Error::new(io::ErrorKind::InvalidData, "bad frame length"));
        }
        buf.clear();
        buf.resize(len, 0);
        r.read_exact(buf)?;
        let (body, tag) = buf.split_at_mut(len - TAG_LEN);
        let tag: [u8; TAG_LEN] = tag.try_into().expect("tag length");
        let nonce = Self::nonce(self.recv_dir, self.recv_ctr);
        self.recv_ctr = self.recv_ctr.wrapping_add(1);
        self.cipher
            .decrypt_in_place_detached(Nonce::from_slice(&nonce), b"", body, (&tag).into())
            .map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "authentication failed"))?;
        buf.truncate(len - TAG_LEN);
        Ok(())
    }
}

pub fn frame_ready(offset: u64) -> Vec<u8> {
    let mut f = Vec::with_capacity(9 + TAG_LEN);
    f.push(KIND_READY);
    f.extend_from_slice(&offset.to_be_bytes());
    f
}

pub fn frame_eof(hash: u64, bytes: u64) -> Vec<u8> {
    let mut f = Vec::with_capacity(17 + TAG_LEN);
    f.push(KIND_EOF);
    f.extend_from_slice(&hash.to_be_bytes());
    f.extend_from_slice(&bytes.to_be_bytes());
    f
}

pub fn frame_ack(bytes: u64, ok: bool) -> Vec<u8> {
    let mut f = Vec::with_capacity(10 + TAG_LEN);
    f.push(KIND_ACK);
    f.extend_from_slice(&bytes.to_be_bytes());
    f.push(ok as u8);
    f
}

pub fn frame_abort(reason: &str) -> Vec<u8> {
    let mut f = Vec::with_capacity(1 + reason.len() + TAG_LEN);
    f.push(KIND_ABORT);
    f.extend_from_slice(reason.as_bytes());
    f
}

pub fn read_u64(b: &[u8]) -> Option<u64> {
    if b.len() < 8 {
        return None;
    }
    Some(u64::from_be_bytes(b[..8].try_into().ok()?))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn header_round_trip() {
        let h = Header { role: 1, sid: [7; 16], transfer: 0xDEADBEEF, salt: [9; 16] };
        let d = Header::decode(&h.encode()).unwrap();
        assert_eq!(d.role, 1);
        assert_eq!(d.sid, [7; 16]);
        assert_eq!(d.transfer, 0xDEADBEEF);
        assert_eq!(d.salt, [9; 16]);
        let mut bad = h.encode();
        bad[0] = b'X';
        assert!(Header::decode(&bad).is_err());
    }

    #[test]
    fn frames_round_trip_and_reject_tampering() {
        let key = connection_key(&[1; 32], &[2; 16]);
        let mut a = FrameCipher::new(&key, true);
        let mut b = FrameCipher::new(&key, false);
        let mut wire = Vec::new();
        for i in 0..3u64 {
            let mut f = frame_ready(i);
            a.write_frame(&mut wire, &mut f).unwrap();
        }
        let mut cursor = std::io::Cursor::new(wire.clone());
        let mut buf = Vec::new();
        for i in 0..3u64 {
            b.read_frame(&mut cursor, &mut buf).unwrap();
            assert_eq!(buf[0], KIND_READY);
            assert_eq!(read_u64(&buf[1..]), Some(i));
        }
        // Flip one ciphertext byte: authentication fails.
        let mut tampered = wire;
        tampered[6] ^= 0x01;
        let mut c = FrameCipher::new(&key, false);
        let mut cursor = std::io::Cursor::new(tampered);
        assert!(c.read_frame(&mut cursor, &mut buf).is_err());
    }
}
