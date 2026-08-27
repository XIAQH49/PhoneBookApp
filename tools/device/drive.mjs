#!/usr/bin/env node
/**
 * PhoneBookApp 真机驱动 CLI（HarmonyOS hdc 封装）——供任何 AI/脚本复用。
 *
 * 用法：node tools/device/drive.mjs <command> [args]
 *
 * 命令：
 *   status                   设备连接状态（JSON）
 *   launch <bundle> <ability>  拉起应用（默认 com.example.phonebookapp / EntryAbility）
 *   kill <bundle>              强杀应用（持久化测试用）
 *   wake                       唤醒屏幕
 *   layout [outFile]           抓取前台窗口控件树并保存（默认 m2_layout.json），输出文本元素列表
 *   texts <file>               打印布局文件中的全部文本（含坐标中心）
 *   find <file> <text>         查找文本元素的中心坐标（点击目标）
 *   tap <x> <y>                注入点击
 *   swipe <x1> <y1> <x2> <y2> [ms]  注入滑动（默认 300ms；侧滑返回用 x1=10）
 *   missions                   前台任务列表（判断文件选择器/拨号盘是否唤起）
 *   installInfo <bundle>       应用安装信息（updateTime 判断是否装了新包）
 *   screenshot [file]          截屏保存（仅对可读图的模型有用；控件树文本才是"眼睛"）
 *
 * 环境：hdc 路径可用 HDC 环境变量覆盖，默认 DevEco SDK 自带路径。
 */
import { spawnSync } from 'node:child_process';
import * as fs from 'node:fs';

const HDC = process.env.HDC ?? 'D:\\DevEco Studio\\sdk\\default\\openharmony\\toolchains\\hdc.exe';
const DEFAULT_BUNDLE = 'com.example.phonebookapp';
const DEFAULT_ABILITY = 'EntryAbility';

function sh(args, timeoutMs = 30000) {
  const r = spawnSync(HDC, args, { encoding: 'utf8', timeout: timeoutMs });
  const out = (r.stdout ?? '') + (r.stderr ?? '');
  return { code: r.status, out: out.trim() };
}

function fail(msg) {
  console.error('[drive] FAIL: ' + msg);
  process.exit(1);
}

function walk(node, acc) {
  if (!node) return;
  const a = node.attributes ?? {};
  const text = (a.text ?? '').trim();
  const type = a.type ?? '';
  const bounds = a.bounds ?? '';
  if (text || type === 'Checkbox') {
    const m = bounds.match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);
    const center = m
      ? { x: Math.round((+m[1] + +m[3]) / 2), y: Math.round((+m[2] + +m[4]) / 2) }
      : null;
    acc.push({ text, type, checked: a.checked ?? null, bounds, center });
  }
  (node.children ?? []).forEach(c => walk(c, acc));
}

function loadLayout(file) {
  if (!fs.existsSync(file)) fail('布局文件不存在: ' + file + '（先运行 layout 命令）');
  const tree = JSON.parse(fs.readFileSync(file, 'utf8'));
  const items = [];
  walk(tree, items);
  return items;
}

const [cmd, ...args] = process.argv.slice(2);

switch (cmd) {
  case 'status': {
    const r = sh(['list', 'targets']);
    const connected = r.out !== '[Empty]' && r.out.length > 0;
    console.log(JSON.stringify({ connected, targets: connected ? r.out : [] }));
    break;
  }
  case 'launch': {
    const bundle = args[0] ?? DEFAULT_BUNDLE;
    const ability = args[1] ?? DEFAULT_ABILITY;
    const r = sh(['shell', 'aa', 'start', '-b', bundle, '-a', ability]);
    console.log(JSON.stringify({ ok: !/failed/i.test(r.out), out: r.out }));
    break;
  }
  case 'kill': {
    const bundle = args[0] ?? DEFAULT_BUNDLE;
    const r = sh(['shell', 'aa', 'force-stop', bundle]);
    console.log(JSON.stringify({ ok: true, out: r.out }));
    break;
  }
  case 'wake': {
    const r = sh(['shell', 'power-shell', 'wakeup']);
    console.log(JSON.stringify({ ok: true, out: r.out }));
    break;
  }
  case 'layout': {
    const outFile = args[0] ?? 'm2_layout.json';
    const d = sh(['shell', 'uitest', 'dumpLayout']);
    const m = d.out.match(/saved to:(\S+)/);
    if (!m) fail('dumpLayout 失败: ' + d.out.slice(0, 300));
    const recv = sh(['file', 'recv', m[1], outFile]);
    if (recv.code !== 0) fail('recv 失败: ' + recv.out.slice(0, 300));
    const items = loadLayout(outFile);
    console.log(JSON.stringify({
      file: outFile,
      texts: items.filter(i => i.text).map(i => i.text),
      elements: items
    }));
    break;
  }
  case 'texts': {
    const items = loadLayout(args[0] ?? 'm2_layout.json');
    for (const i of items) {
      if (i.text) console.log(i.text + '\tB=' + i.bounds + '\tC=' + (i.center ? i.center.x + ',' + i.center.y : ''));
    }
    break;
  }
  case 'find': {
    const file = args[0] ?? 'm2_layout.json';
    const needle = args[1];
    if (!needle) fail('用法: find <file> <text>');
    const items = loadLayout(file);
    const hit = items.find(i => i.text && i.text.includes(needle));
    if (!hit) { console.log('NOT_FOUND'); process.exit(1); }
    console.log(JSON.stringify(hit));
    break;
  }
  case 'tap': {
    const x = args[0], y = args[1];
    if (x === undefined || y === undefined) fail('用法: tap <x> <y>');
    const r = sh(['shell', 'uinput', '-T', '-c', x, y]);
    console.log(JSON.stringify({ ok: true, out: r.out }));
    break;
  }
  case 'swipe': {
    if (args.length < 4) fail('用法: swipe <x1> <y1> <x2> <y2> [ms]');
    const ms = args[4] ?? '300';
    const r = sh(['shell', 'uinput', '-T', '-m', args[0], args[1], args[2], args[3], ms]);
    console.log(JSON.stringify({ ok: true, out: r.out }));
    break;
  }
  case 'missions': {
    const r = sh(['shell', 'aa', 'dump', '--all']);
    console.log(r.out);
    break;
  }
  case 'installInfo': {
    const bundle = args[0] ?? DEFAULT_BUNDLE;
    const r = sh(['shell', 'bm', 'dump', '-n', bundle]);
    const m = r.out.match(/"updateTime":\s*(\d+)/);
    console.log(JSON.stringify({ bundle, updateTime: m ? Number(m[1]) : null }));
    break;
  }
  case 'screenshot': {
    const outFile = args[0] ?? 'm2_shot.jpeg';
    sh(['shell', 'snapshot_display', '-f', '/data/local/tmp/__shot.jpeg']);
    const recv = sh(['file', 'recv', '/data/local/tmp/__shot.jpeg', outFile]);
    console.log(JSON.stringify({ ok: recv.code === 0, file: outFile }));
    break;
  }
  default:
    console.log('未知命令: ' + (cmd ?? '(空)') + '。可用：status launch kill wake layout texts find tap swipe missions installInfo screenshot');
    process.exit(1);
}
