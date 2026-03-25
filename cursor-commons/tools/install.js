#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

// ── Colours ──────────────────────────────────────────────────────────────────
const isTTY = process.stdout.isTTY;
const c = {
  red:    isTTY ? '\x1b[31m' : '',
  green:  isTTY ? '\x1b[32m' : '',
  yellow: isTTY ? '\x1b[33m' : '',
  blue:   isTTY ? '\x1b[34m' : '',
  bold:   isTTY ? '\x1b[1m'  : '',
  reset:  isTTY ? '\x1b[0m'  : '',
};

const log  = (msg) => console.log(msg);
const info = (msg) => log(`${c.blue}${msg}${c.reset}`);
const ok   = (msg) => log(`${c.green}${msg}${c.reset}`);
const warn = (msg) => log(`${c.yellow}${msg}${c.reset}`);
const err  = (msg) => { console.error(`${c.bold}${c.red}Error: ${msg}${c.reset}`); process.exit(1); };

// ── Config ────────────────────────────────────────────────────────────────────
const HOME               = os.homedir();
const CURSOR_COMMONS_HOME = process.env.CURSOR_COMMONS_HOME || path.join(HOME, '.cursor-commons');
const REMOTE             = process.env.REMOTE || 'https://github.com/adinath/aifsd-commons.git';
const BRANCH             = process.env.BRANCH || 'develop';
const UNATTENDED         = process.env.UNATTENDED === '1' || !isTTY || process.argv.includes('--unattended');
const IS_UPGRADE         = process.argv.includes('--upgrade');

// ── Helpers ───────────────────────────────────────────────────────────────────
function commandExists(cmd) {
  try { execSync(`${os.platform() === 'win32' ? 'where' : 'which'} ${cmd}`, { stdio: 'ignore' }); return true; }
  catch { return false; }
}

function run(cmd, cwd) {
  execSync(cmd, { cwd, stdio: 'inherit' });
}

function backupDir(src, dest) {
  if (fs.existsSync(src) || isSymlink(src)) {
    if (fs.existsSync(dest)) {
      const timestamped = `${dest}-${timestamp()}`;
      fs.renameSync(dest, timestamped);
      warn(`Backed up previous ${path.basename(dest)} to ${timestamped}`);
    }
    fs.renameSync(src, dest);
    ok(`Backed up ${src} → ${dest}`);
  }
}

function copyDir(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath  = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDir(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function isSymlink(p) {
  try { return fs.lstatSync(p).isSymbolicLink(); } catch { return false; }
}

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
}

function getShellRc() {
  const candidates = ['.bashrc', '.zshrc', '.profile'];
  for (const f of candidates) {
    const p = path.join(HOME, f);
    if (fs.existsSync(p)) return p;
  }
  return path.join(HOME, '.bashrc');
}

function pruneOldBackups(prefix, keep = 5) {
  const dir = path.dirname(prefix);
  const base = path.basename(prefix);
  const backups = fs.readdirSync(dir)
    .filter(f => f.startsWith(base))
    .map(f => path.join(dir, f))
    .sort()
    .reverse();
  for (const old of backups.slice(keep)) {
    fs.rmSync(old, { recursive: true, force: true });
    warn(`Removed old backup: ${old}`);
  }
}

// ── Steps ─────────────────────────────────────────────────────────────────────
function setupCursorCommons() {
  info('Cloning Cursor Commons...');
  if (!commandExists('git')) err('git is not installed. Please install git first.');

  if (fs.existsSync(CURSOR_COMMONS_HOME)) {
    warn(`Directory ${CURSOR_COMMONS_HOME} already exists.`);
    if (!UNATTENDED) {
      const readline = require('readline');
      const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
      return new Promise((resolve) => {
        rl.question('Do you want to reinstall/update? [Y/n] ', (ans) => {
          rl.close();
          if (/^[Nn]/.test(ans)) { log('Installation skipped.'); process.exit(0); }
          run(`git fetch origin && git checkout -q ${BRANCH} && git pull --quiet origin ${BRANCH}`, CURSOR_COMMONS_HOME);
          resolve();
        });
      });
    }
    run(`git fetch origin`, CURSOR_COMMONS_HOME);
    run(`git checkout -q ${BRANCH}`, CURSOR_COMMONS_HOME);
    run(`git pull --quiet origin ${BRANCH}`, CURSOR_COMMONS_HOME);
  } else {
    run(`git clone --branch ${BRANCH} --depth 1 ${REMOTE} "${CURSOR_COMMONS_HOME}"`);
  }
  log('');
}

function setupCursorDir() {
  info('Setting up cursor-settings directory...');
  const cursorDir    = path.join(HOME, '.cursor');
  const backupDir_   = path.join(HOME, '.cursor.pre-cursor-commons');
  const cursorSrc    = path.join(CURSOR_COMMONS_HOME, 'cursor-commons', 'cursor-settings');

  if (IS_UPGRADE) {
    // Upgrade: timestamped backup, merge over existing
    if (fs.existsSync(cursorDir) || isSymlink(cursorDir)) {
      const backup = `${cursorDir}.backup-${timestamp()}`;
      copyDir(cursorDir, backup);
      ok(`Backed up existing .cursor → ${backup}`);
      pruneOldBackups(path.join(HOME, '.cursor.backup-'), 5);
    }
    fs.mkdirSync(cursorDir, { recursive: true });
    copyDir(cursorSrc, cursorDir);
  } else {
    // Fresh install: rename backup
    backupDir(cursorDir, backupDir_);
    copyDir(cursorSrc, cursorDir);
  }

  ok(`Installed .cursor → ${cursorDir}`);
  log('');
}

function setupShellRc() {
  if (os.platform() === 'win32') return; // Windows users use npx directly

  info('Configuring shell...');
  const shellRc    = getShellRc();
  const marker     = '# Cursor Commons - shared Cursor IDE config';
  const hook = `
# Cursor Commons - shared Cursor IDE config
if [ -d "\${CURSOR_COMMONS_HOME:-$HOME/.cursor-commons}" ]; then
  export CURSOR_COMMONS_HOME="\${CURSOR_COMMONS_HOME:-$HOME/.cursor-commons}"
  [ -f "$CURSOR_COMMONS_HOME/cursor-commons/tools/check_for_upgrade.sh" ] && . "$CURSOR_COMMONS_HOME/cursor-commons/tools/check_for_upgrade.sh"
  alias cursor-commons-update='npx --yes github:adinath/aifsd-commons --upgrade'
fi
`;

  let existing = '';
  if (fs.existsSync(shellRc)) existing = fs.readFileSync(shellRc, 'utf8');

  if (existing.includes(marker)) {
    ok(`Cursor Commons hook already present in ${shellRc}`);
  } else {
    fs.appendFileSync(shellRc, hook);
    ok(`Added Cursor Commons hook to ${shellRc}`);
  }
  log('');
}

function printSuccess() {
  const shellRc = getShellRc();
  log('');
  log(`${c.green}${c.bold}Cursor Commons is now installed!${c.reset}`);
  log('');
  log(`  ${c.blue}•${c.reset} Cursor commands and rules are in ${path.join(HOME, '.cursor')}`);
  log(`  ${c.blue}•${c.reset} Update any time:  npx --yes github:adinath/aifsd-commons --upgrade`);
  if (os.platform() !== 'win32') {
    log(`  ${c.blue}•${c.reset} Restart your terminal or run: source ${shellRc}`);
  }
  log('');
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  if (!commandExists('git')) err('git is not installed. Please install git first.');

  await setupCursorCommons();
  setupCursorDir();
  setupShellRc();
  printSuccess();
}

main().catch((e) => err(e.message));
