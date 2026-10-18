const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');

const projectRoot = path.resolve(__dirname, '..');
const panelScript = path.join(projectRoot, 'admin-panel', 'start-admin-panel.ps1');
const powershell = process.env.POWERSHELL_EXECUTABLE || 'powershell.exe';

async function unusedPort() {
  const server = net.createServer();
  await new Promise((resolve, reject) => server.listen(0, '127.0.0.1', resolve).once('error', reject));
  const { port } = server.address();
  await new Promise(resolve => server.close(resolve));
  return port;
}

function waitForPanel(child, output, timeoutMs = 10000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`El panel no inició a tiempo. Salida: ${output()}`)), timeoutMs);
    const onData = chunk => {
      const text = chunk.toString();
      if (text.includes('Panel administrativo local:')) {
        clearTimeout(timer);
        child.stdout.off('data', onData);
        resolve(text);
      }
    };
    child.stdout.on('data', onData);
    child.once('error', error => { clearTimeout(timer); reject(error); });
    child.once('exit', code => {
      clearTimeout(timer);
      reject(new Error(`El panel terminó antes de iniciar (código ${code}). Salida: ${output()}`));
    });
  });
}

test('admin panel: health, autenticación, API y archivos estáticos', async t => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'bolsa-admin-test-'));
  const runtimeConfigDir = path.join(tempRoot, 'src', 'whatsapp');
  fs.mkdirSync(runtimeConfigDir, { recursive: true });
  fs.copyFileSync(path.join(projectRoot, 'src', 'whatsapp', 'runtime-config.ps1'), path.join(runtimeConfigDir, 'runtime-config.ps1'));

  const port = await unusedPort();
  let captured = '';
  const child = spawn(powershell, [
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', panelScript,
    '-ProjectRoot', tempRoot, '-Port', String(port)
  ], { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
  child.stdout.on('data', chunk => { captured += chunk.toString(); });
  child.stderr.on('data', chunk => { captured += chunk.toString(); });

  try {
    const startup = await waitForPanel(child, () => captured);
    const token = startup.match(/#([A-Za-z0-9_-]+)/)?.[1];
    assert.ok(token, 'el servidor imprime un token de sesión temporal');
    const base = `http://127.0.0.1:${port}`;

    await t.test('health no expone datos sensibles', async () => {
      const response = await fetch(`${base}/api/health`);
      assert.equal(response.status, 200);
      assert.deepEqual(await response.json(), { ok: true });
    });

    await t.test('las rutas de datos requieren token', async () => {
      const response = await fetch(`${base}/api/reviews`);
      assert.equal(response.status, 401);
      assert.match((await response.json()).error, /no autorizada/i);
    });

    await t.test('la sesión válida recibe una instantánea con colecciones', async () => {
      const response = await fetch(`${base}/api/reviews`, { headers: { 'X-Admin-Token': token } });
      assert.equal(response.status, 200);
      const snapshot = await response.json();
      for (const key of ['cases', 'resolved', 'profiles', 'admins']) assert.ok(Array.isArray(snapshot[key]), `${key} es una lista`);
    });

    await t.test('sirve la interfaz con cabeceras de seguridad', async () => {
      const response = await fetch(base);
      assert.equal(response.status, 200);
      assert.match(response.headers.get('content-type'), /text\/html/);
      assert.match(response.headers.get('content-security-policy'), /default-src 'self'/);
      assert.match(await response.text(), /admin-panel|Revisiones/i);
    });

    await t.test('rechaza rutas estáticas que escapan del panel', async () => {
      const response = await fetch(`${base}/..%2Fsrc%2Fwhatsapp%2Fruntime-config.ps1`);
      assert.equal(response.status, 404);
    });
  } finally {
    child.kill();
    await new Promise(resolve => {
      if (child.exitCode !== null) return resolve();
      child.once('exit', resolve);
      setTimeout(resolve, 1500).unref();
    });
    fs.rmSync(tempRoot, { recursive: true, force: true });
  }
});
