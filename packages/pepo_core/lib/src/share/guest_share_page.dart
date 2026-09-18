/// The single-file web page served to guests (no app needed). Texts are in
/// Spanish with an English fallback picked from `navigator.language`.
/// `__SESSION_JSON__` is replaced with the session description.
const String guestSharePageHtml = r'''<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PepoConnect</title>
<style>
  :root { color-scheme: light dark; --bg:#f3f3f3; --card:#ffffff; --stroke:#0000000f; --text:#000000e4; --text2:#0000009e; --accent:#005fb8; --accent-text:#fff; --ok:#0f7b0f; --err:#c42b1c; --drop:#eaf3fc; --dropb:#7fb8e6; }
  @media (prefers-color-scheme: dark) { :root { --bg:#202020; --card:#2b2b2b; --stroke:#ffffff14; --text:#fff; --text2:#ffffffc5; --accent:#60cdff; --accent-text:#000; --ok:#6ccb5f; --err:#ff99a4; --drop:#1f2c3a; --dropb:#3a6ea5; } }
  * { box-sizing: border-box; }
  body { margin:0; font: 14px/20px "Segoe UI Variable Text","Segoe UI",Roboto,-apple-system,system-ui,sans-serif; background:var(--bg); color:var(--text); }
  main { max-width: 560px; margin: 0 auto; padding: 24px 16px 48px; }
  header { display:flex; align-items:center; gap:12px; margin-bottom: 20px; }
  header svg { width: 40px; height: 40px; border-radius: 9px; flex: none; }
  h1 { font-size: 20px; line-height: 28px; font-weight: 600; margin: 0; }
  .sub { color: var(--text2); margin: 0; }
  .card { background: var(--card); border: 1px solid var(--stroke); border-radius: 8px; padding: 12px 16px; }
  .msg { white-space: pre-wrap; margin-bottom: 16px; }
  .row { display:flex; align-items:center; gap:12px; padding: 10px 0; border-top: 1px solid var(--stroke); }
  .row:first-child { border-top: 0; }
  .name { flex:1; min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
  .size { color: var(--text2); flex:none; }
  .btn { border: 1px solid var(--stroke); background: var(--card); color: var(--text); border-radius: 4px; padding: 5px 12px; font: inherit; cursor:pointer; }
  .btn.primary { background: var(--accent); color: var(--accent-text); border-color: transparent; }
  .btn:active { transform: scale(0.97); }
  .bar { height: 4px; border-radius: 2px; background: var(--stroke); overflow:hidden; margin-top: 6px; }
  .bar > i { display:block; height:100%; width:0; background: var(--accent); transition: width .15s ease-out; }
  .drop { border: 2px dashed var(--dropb); background: var(--drop); border-radius: 12px; padding: 32px 16px; text-align:center; margin-bottom: 16px; }
  .drop.over { border-style: solid; }
  .hint { color: var(--text2); font-size: 12px; margin-top: 12px; }
  .ok { color: var(--ok); } .err { color: var(--err); }
  footer { margin-top: 24px; color: var(--text2); font-size: 12px; }
  input[type=file] { display:none; }
</style>
</head>
<body>
<main>
  <header>
    <svg viewBox="0 0 512 512" aria-hidden="true"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#0A3D8F"/><stop offset="1" stop-color="#12B6D9"/></linearGradient></defs><rect width="512" height="512" rx="112" fill="url(#g)"/><rect x="112" y="128" width="220" height="176" rx="30" fill="none" stroke="#fff" stroke-width="28"/><rect x="196" y="200" width="220" height="176" rx="30" fill="none" stroke="#fff" stroke-width="28"/><path d="M232 348 L288 274 L322 318 L346 292 L392 348 Z" fill="#fff"/><circle cx="356" cy="250" r="18" fill="#FFC857"/></svg>
    <div><h1 id="title">PepoConnect</h1><p class="sub" id="subtitle"></p></div>
  </header>
  <div id="content"></div>
  <footer id="footer"></footer>
</main>
<script>
const S = __SESSION_JSON__;
const es = !(navigator.language || 'es').toLowerCase().startsWith('en');
const T = es ? {
  send: 'Archivos para ti', sendSub: '{n} archivos · {size}', recv: 'Envía archivos a {host}', recvSub: 'Suelta aquí los archivos o elige en tu dispositivo',
  download: 'Descargar', downloadAll: 'Descargar todo', choose: 'Elegir archivos', sending: 'Enviando…', sent: 'Enviado', failed: 'Error',
  expires: 'Este enlace caduca en {m} min y solo funciona en esta red.', expired: 'El enlace ha caducado. Pide otro en el PC.', taken: 'Este enlace ya se está usando en otro dispositivo.',
  tooBig: 'Archivo demasiado grande', noPrograms: 'Este PC no acepta programas', from: 'De {host}', multi: 'Puedes elegir varios archivos a la vez.'
} : {
  send: 'Files for you', sendSub: '{n} files · {size}', recv: 'Send files to {host}', recvSub: 'Drop files here or choose from your device',
  download: 'Download', downloadAll: 'Download all', choose: 'Choose files', sending: 'Sending…', sent: 'Sent', failed: 'Failed',
  expires: 'This link expires in {m} min and only works on this network.', expired: 'The link has expired. Ask for a new one on the PC.', taken: 'This link is already in use on another device.',
  tooBig: 'File too large', noPrograms: 'This PC does not accept programs', from: 'From {host}', multi: 'You can choose several files at once.'
};
const fmt = (t, o) => t.replace(/\{(\w+)\}/g, (_, k) => o[k]);
const bytes = n => n < 1024 ? n + ' B' : n < 1048576 ? (n/1024).toFixed(0) + ' KB' : n < 1073741824 ? (n/1048576).toFixed(1).replace('.', es ? ',' : '.') + ' MB' : (n/1073741824).toFixed(2).replace('.', es ? ',' : '.') + ' GB';
const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };
const content = document.getElementById('content');
document.getElementById('footer').textContent = fmt(T.expires, {m: Math.max(1, Math.round((S.expiresAt - Date.now()) / 60000))});

if (S.mode === 'send') {
  const total = S.files.reduce((a, f) => a + f.size, 0);
  document.getElementById('title').textContent = T.send;
  document.getElementById('subtitle').textContent = fmt(T.sendSub, {n: S.files.length, size: bytes(total)});
  if (S.message) content.appendChild(el('div', 'card msg', S.message));
  const card = el('div', 'card');
  for (const f of S.files) {
    const row = el('div', 'row');
    row.appendChild(el('span', 'name', f.name));
    row.appendChild(el('span', 'size', bytes(f.size)));
    const a = el('a', 'btn', T.download); a.href = S.base + '/file/' + f.id; a.setAttribute('download', f.name);
    row.appendChild(a);
    card.appendChild(row);
  }
  content.appendChild(card);
  if (S.files.length > 1) {
    const all = el('button', 'btn primary', T.downloadAll); all.style.marginTop = '16px';
    all.onclick = async () => { for (const f of S.files) { const a = document.createElement('a'); a.href = S.base + '/file/' + f.id; a.download = f.name; a.click(); await new Promise(r => setTimeout(r, 700)); } };
    content.appendChild(all);
  }
} else {
  document.getElementById('title').textContent = fmt(T.recv, {host: S.host});
  document.getElementById('subtitle').textContent = T.recvSub;
  if (S.message) content.appendChild(el('div', 'card msg', S.message));
  const drop = el('div', 'drop');
  const choose = el('button', 'btn primary', T.choose);
  const input = document.createElement('input'); input.type = 'file'; input.multiple = true;
  choose.onclick = () => input.click();
  drop.appendChild(choose); drop.appendChild(input);
  drop.appendChild(el('div', 'hint', T.multi));
  content.appendChild(drop);
  const list = el('div', 'card'); list.style.display = 'none'; content.appendChild(list);
  const queue = [];
  let busy = false;
  const enqueue = files => { for (const f of files) queue.push(f); list.style.display = ''; pump(); };
  const pump = () => {
    if (busy || !queue.length) return;
    busy = true;
    const f = queue.shift();
    const row = el('div', 'row'); const box = el('div', 'name');
    box.appendChild(el('div', null, f.name));
    const bar = el('div', 'bar'); const fill = el('i'); bar.appendChild(fill); box.appendChild(bar);
    row.appendChild(box); const st = el('span', 'size', T.sending); row.appendChild(st); list.appendChild(row);
    const xhr = new XMLHttpRequest();
    xhr.open('PUT', S.base + '/upload?name=' + encodeURIComponent(f.name));
    xhr.upload.onprogress = e => { if (e.lengthComputable) fill.style.width = (e.loaded / e.total * 100) + '%'; };
    xhr.onload = () => { const ok = xhr.status >= 200 && xhr.status < 300; st.textContent = ok ? T.sent : (xhr.status === 413 ? T.tooBig : xhr.status === 415 ? T.noPrograms : T.failed); st.className = 'size ' + (ok ? 'ok' : 'err'); fill.style.width = '100%'; busy = false; pump(); };
    xhr.onerror = () => { st.textContent = T.failed; st.className = 'size err'; busy = false; pump(); };
    xhr.send(f);
  };
  input.onchange = () => enqueue(input.files);
  drop.ondragover = e => { e.preventDefault(); drop.classList.add('over'); };
  drop.ondragleave = () => drop.classList.remove('over');
  drop.ondrop = e => { e.preventDefault(); drop.classList.remove('over'); enqueue(e.dataTransfer.files); };
}
</script>
</body>
</html>
''';

/// Minimal error page.
String guestErrorPage(String message) =>
    '''<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>PepoConnect</title><style>body{font:16px/24px "Segoe UI",Roboto,system-ui,sans-serif;margin:0;background:#f3f3f3;color:#000000e4}main{max-width:560px;margin:48px auto;padding:24px}</style></head><body><main><h1>PepoConnect</h1><p>$message</p></main></body></html>''';
