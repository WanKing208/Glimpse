// 用 CDP 驱动无头 Chromium：点击底部 tab 并截图
const fs = require('fs');

const PORT = 9333;
const BASE = `http://127.0.0.1:${PORT}`;

async function getTarget() {
  for (let i = 0; i < 40; i++) {
    try {
      const res = await fetch(`${BASE}/json`);
      const list = await res.json();
      const page = list.find((t) => t.type === 'page' && t.webSocketDebuggerUrl);
      if (page) return page;
    } catch (_) {}
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error('no target');
}

function rpc(ws) {
  let id = 0;
  const pending = new Map();
  ws.addEventListener('message', (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result);
    }
  });
  return (method, params = {}) =>
    new Promise((resolve, reject) => {
      const myId = ++id;
      pending.set(myId, { resolve, reject });
      ws.send(JSON.stringify({ id: myId, method, params }));
    });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  const target = await getTarget();
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((r) => ws.addEventListener('open', r));
  const send = rpc(ws);

  await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', {
    width: 412,
    height: 900,
    deviceScaleFactor: 2,
    mobile: true,
  });

  await send('Page.navigate', { url: 'http://127.0.0.1:8899/' });
  await sleep(9000);

  const shot = async (name) => {
    const { data } = await send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(`/tmp/shot_${name}.png`, Buffer.from(data, 'base64'));
    console.log('saved', name);
  };

  const click = async (x, y) => {
    await send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
    await sleep(60);
    await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
    await sleep(1400);
  };

  await shot('1_dashboard');

  // 底部导航：6 个 tab 均分宽度（左右各 8px 内边距）
  const tabs = ['proxies', 'connections', 'rules', 'logs', 'settings'];
  const w = (412 - 16) / 6;
  for (let i = 0; i < tabs.length; i++) {
    const x = 8 + w * (i + 1) + w / 2;
    await click(x, 862);
    await shot(`${i + 2}_${tabs[i]}`);
  }

  ws.close();
  process.exit(0);
})().catch((e) => {
  console.error('ERR', e.message);
  process.exit(1);
});
