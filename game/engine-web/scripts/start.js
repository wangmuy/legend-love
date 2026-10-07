// scripts/start.js
// Web MUD 开发服务器启动脚本
// 用法: node scripts/start.js [--kill]
//   --kill  强制释放 8088 端口再启动
//   无参数  端口被占用时自动找空闲端口

const { spawn, execSync } = require('child_process');
const net = require('net');

const DEFAULT_PORT = 8088;

function isPortInUse(port) {
    return new Promise((resolve) => {
        const server = net.createServer();
        server.once('error', () => resolve(true));
        server.once('listening', () => {
            server.close();
            resolve(false);
        });
        server.listen(port, '0.0.0.0');
    });
}

function findFreePort(start) {
    return new Promise((resolve, reject) => {
        const server = net.createServer();
        server.listen(start, '0.0.0.0', () => {
            const port = server.address().port;
            server.close(() => resolve(port));
        });
        server.on('error', () => {
            // port taken, try next
            findFreePort(start + 1).then(resolve, reject);
        });
    });
}

async function main() {
    const args = process.argv.slice(2);
    const doKill = args.includes('--kill');

    const inUse = await isPortInUse(DEFAULT_PORT);

    if (inUse) {
        if (doKill) {
            console.log(`端口 ${DEFAULT_PORT} 被占用，正在释放...`);
            try {
                execSync(`fuser -k ${DEFAULT_PORT}/tcp 2>/dev/null`, { timeout: 5000 });
                // 等内核释放端口
                await new Promise(r => setTimeout(r, 1000));
                console.log(`端口 ${DEFAULT_PORT} 已释放。`);
            } catch (e) {
                console.error(`释放端口 ${DEFAULT_PORT} 失败:`, e.message);
                process.exit(1);
            }
        } else {
            // 自动找空闲端口
            const freePort = await findFreePort(DEFAULT_PORT + 1);
            console.log(`端口 ${DEFAULT_PORT} 被占用，自动使用端口 ${freePort}`);
            startServe(freePort);
            return;
        }
    }

    startServe(DEFAULT_PORT);
}

function startServe(port) {
    const proc = spawn('npx', ['serve', 'dist', '-p', String(port), '--no-clipboard'], {
        stdio: 'inherit',
        shell: true,
    });
    proc.on('close', (code) => process.exit(code));
}

main().catch(err => {
    console.error('启动失败:', err);
    process.exit(1);
});
