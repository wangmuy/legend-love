const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const DIST = path.join(ROOT, 'dist');
const SRC = path.join(ROOT, 'data-web');

function mkdir(dir) {
    fs.mkdirSync(dir, { recursive: true });
}

function copy(src, dest) {
    fs.cpSync(src, dest, { recursive: true, force: true });
}

// Clean dist
mkdir(DIST);

// 1. Frontend files
console.log('[1/4] Copying frontend files...');
const frontendFiles = [
    'index.html', 'style.css', 'index.js', 'worker.js',
    'engine_web.lua', 'data_loader.lua', 'state_manager.lua',
    'web_game_bridge.lua', 'web_command_engine.lua', 'mmap_smap_handlers.lua',
];
for (const f of frontendFiles) {
    const srcPath = path.join(ROOT, f);
    if (fs.existsSync(srcPath)) {
        fs.copyFileSync(srcPath, path.join(DIST, f));
        console.log(`  ${f}`);
    }
}

// 1b. Framework modules
console.log('[1b/4] Copying framework modules...');
const frameworkDir = path.resolve(ROOT, '..', 'framework');
if (fs.existsSync(frameworkDir)) {
    const distFwDir = path.join(DIST, 'framework');
    mkdir(distFwDir);
    const fwFiles = fs.readdirSync(frameworkDir);
    for (const f of fwFiles) {
        if (f.endsWith('.lua')) {
            fs.copyFileSync(path.join(frameworkDir, f), path.join(distFwDir, f));
            console.log(`  framework/${f}`);
        }
    }
}

// 1c. Script modules
console.log('[1c/4] Copying script modules...');
const scriptDir = path.resolve(ROOT, '..', 'script');
if (fs.existsSync(scriptDir)) {
    const distScDir = path.join(DIST, 'script');
    mkdir(distScDir);
    const scriptFiles = ['jymain.lua', 'jyconst.lua', 'jymodify.lua'];
    for (const f of scriptFiles) {
        const srcPath = path.join(scriptDir, f);
        if (fs.existsSync(srcPath)) {
            fs.copyFileSync(srcPath, path.join(distScDir, f));
            console.log(`  script/${f}`);
        }
    }
}

// 2. Data files
console.log('[2/4] Copying data-web...');
if (fs.existsSync(SRC)) {
    copy(SRC, path.join(DIST, 'data-web'));
}

// 3. Libraries
console.log('[3/4] Copying libraries from node_modules...');
const libs = [
    { src: 'node_modules/xterm/lib/xterm.js', dest: 'lib/xterm.js' },
    { src: 'node_modules/xterm/css/xterm.css', dest: 'lib/xterm.css' },
    { src: 'node_modules/fengari-web/dist/fengari-web.js', dest: 'lib/fengari-web.js' },
    { src: 'node_modules/@xterm/addon-fit/lib/addon-fit.js', dest: 'lib/xterm-addon-fit.js' },
];
mkdir(path.join(DIST, 'lib'));
for (const lib of libs) {
    const srcPath = path.join(ROOT, lib.src);
    if (fs.existsSync(srcPath)) {
        fs.copyFileSync(srcPath, path.join(DIST, lib.dest));
        console.log(`  ${lib.dest}`);
    } else {
        console.log(`  [WARN] ${lib.src} not found`);
    }
}

// 3b. Copy oldevent scripts to dist/script/oldevent/
const OLDSCRIPT = path.resolve(ROOT, '..', 'script', 'oldevent');
if (fs.existsSync(OLDSCRIPT)) {
    const DST_SCRIPT = path.join(DIST, 'script', 'oldevent');
    fs.mkdirSync(DST_SCRIPT, { recursive: true });
    fs.cpSync(OLDSCRIPT, DST_SCRIPT, { recursive: true, force: true });
    console.log(`  oldevent/: ${fs.readdirSync(OLDSCRIPT).length} files`);
}

// 4. index.html: switch CDN → local lib refs
console.log('[4/4] Updating index.html for local libs...');
const htmlPath = path.join(DIST, 'index.html');
let html = fs.readFileSync(htmlPath, 'utf-8');
html = html.replace(
    /https:\/\/cdn\.jsdelivr\.net\/npm\/xterm@5\.3\.0\/css\/xterm\.css/g,
    'lib/xterm.css'
);
html = html.replace(
    /https:\/\/cdn\.jsdelivr\.net\/npm\/xterm@5\.3\.0\/lib\/xterm\.js/g,
    'lib/xterm.js'
);
html = html.replace(
    /https:\/\/cdn\.jsdelivr\.net\/npm\/@xterm\/addon-fit@0\.11\.0\/lib\/addon-fit\.js/g,
    'lib/xterm-addon-fit.js'
);
html = html.replace(
    /https:\/\/cdn\.jsdelivr\.net\/npm\/fengari-web@0\.1\.4\/dist\/fengari-web\.js/g,
    'lib/fengari-web.js'
);
html = html.replace(
    /xterm\.css" crossorigin/g,
    'xterm.css"'
);
fs.writeFileSync(htmlPath, html);

// 4b. worker.js: switch CDN → local lib refs for fengari
const workerPath = path.join(DIST, 'worker.js');
if (fs.existsSync(workerPath)) {
    let workerSrc = fs.readFileSync(workerPath, 'utf-8');
    workerSrc = workerSrc.replace(
        /https:\/\/cdn\.jsdelivr\.net\/npm\/fengari-web@0\.1\.4\/dist\/fengari-web\.js/g,
        'lib/fengari-web.js'
    );
    fs.writeFileSync(workerPath, workerSrc);
    console.log('  worker.js: CDN→local');
}

console.log('');
console.log('Build complete: dist/');
console.log('Run: npm start');