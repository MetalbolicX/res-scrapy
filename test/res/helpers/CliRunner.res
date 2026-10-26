type cliResult = {
  stdout: string,
  stderr: string,
  exitCode: int,
}

let defaultTimeoutMs = 10_000

let runCli = (
  ~args: array<string>=[],
  ~input: string="",
  ~cwd: string="",
  ~timeoutMs: int=defaultTimeoutMs,
): promise<cliResult> => {
  %raw(`
    (async (args, input, cwd, timeoutMs) => {
      const { spawn } = await import('node:child_process');
      const fs = await import('node:fs');
      const { join } = await import('node:path');
      const workDir = cwd && cwd.length > 0 ? cwd : process.cwd();
      const cliPath = join(workDir, 'dist', 'main.mjs');
      if (!fs.existsSync(cliPath)) {
        return {
          stdout: '',
          stderr: 'dist/main.mjs not found — run \`pnpm run bundle\` before E2E tests',
          exitCode: 127,
        };
      }
      return new Promise((resolve) => {
        const proc = spawn('node', [cliPath, ...args], {
          stdio: ['pipe', 'pipe', 'pipe'],
          cwd: workDir,
        });
        let stdout = '';
        let stderr = '';
        const timer = setTimeout(() => {
          proc.kill('SIGKILL');
          resolve({
            stdout,
            stderr: (stderr + '\\nTimed out after ' + timeoutMs + 'ms').trim(),
            exitCode: 124,
          });
        }, timeoutMs);
        proc.stdout.on('data', (chunk) => { stdout += chunk.toString(); });
        proc.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
        proc.on('close', (code) => {
          clearTimeout(timer);
          resolve({ stdout, stderr, exitCode: code ?? 0 });
        });
        proc.on('error', (err) => {
          clearTimeout(timer);
          resolve({ stdout: '', stderr: err.message, exitCode: 1 });
        });
        if (input) {
          proc.stdin.write(input);
        }
        proc.stdin.end();
      });
    })
  `)(args, input, cwd, timeoutMs)->Obj.magic
}

/** Keeps stdin open until the child closes; resolves only after all output drains. */
let runCliAndSignal = (
  ~args: array<string>,
  ~signal: string,
  ~afterMs: int,
  ~timeoutMs: int=defaultTimeoutMs,
): promise<cliResult> => {
  %raw(`
    (async (args, signal, afterMs, timeoutMs) => {
      const { spawn } = await import('node:child_process');
      const { join } = await import('node:path');
      return new Promise((resolve) => {
        const proc = spawn(process.execPath, [join(process.cwd(), 'dist', 'main.mjs'), ...args], {
          stdio: ['pipe', 'pipe', 'pipe'],
        });
        let stdout = '';
        let stderr = '';
        let timedOut = false;
        let spawnError = null;
        let settled = false;
        const clearTimers = () => {
          clearTimeout(signalTimer);
          clearTimeout(deadlineTimer);
        };
        const signalTimer = setTimeout(() => { proc.kill(signal); }, afterMs);
        const deadlineTimer = setTimeout(() => {
          timedOut = true;
          clearTimers();
          proc.kill('SIGKILL');
          proc.stdin.destroy();
        }, timeoutMs);
        proc.stdout.on('data', chunk => { stdout += chunk.toString(); });
        proc.stderr.on('data', chunk => { stderr += chunk.toString(); });
        proc.stdin.on('error', () => {});
        proc.on('error', err => {
          spawnError = err;
          clearTimers();
          proc.kill('SIGKILL');
          proc.stdin.destroy();
        });
        proc.on('close', code => {
          if (settled) return;
          settled = true;
          clearTimers();
          proc.stdin.destroy();
          proc.stdout.destroy();
          proc.stderr.destroy();
          if (timedOut) stderr += '\\nTimed out after ' + timeoutMs + 'ms';
          if (spawnError) stderr += '\\n' + spawnError.message;
          resolve({ stdout, stderr, exitCode: timedOut ? 124 : spawnError ? 1 : code ?? -1 });
        });
      });
    })
  `)(args, signal, afterMs, timeoutMs)->Obj.magic
}

let runCliWithSchemaFile = (
  ~schemaContent: string,
  ~cliArgs: array<string>=[],
  ~input: string="",
  ~cwd: string="",
  ~timeoutMs: int=defaultTimeoutMs,
): promise<cliResult> => {
  %raw(`
    (async (schemaContent, cliArgs, input, cwd, timeoutMs) => {
      const { spawn } = await import('node:child_process');
      const fs = await import('node:fs');
      const os = await import('node:os');
      const { join } = await import('node:path');
      const workDir = cwd && cwd.length > 0 ? cwd : process.cwd();
      const cliPath = join(workDir, 'dist', 'main.mjs');
      const tempDir = fs.mkdtempSync(join(os.tmpdir(), 'res-scrapy-test-'));
      const schemaPath = join(tempDir, 'schema.json');
      fs.writeFileSync(schemaPath, schemaContent);
      if (!fs.existsSync(cliPath)) {
        fs.rmSync(tempDir, { recursive: true, force: true });
        return {
          stdout: '',
          stderr: 'dist/main.mjs not found — run \`pnpm run bundle\` before E2E tests',
          exitCode: 127,
        };
      }

      return new Promise((resolve) => {
        const proc = spawn('node', [cliPath, ...cliArgs, '--schemaPath', schemaPath], {
          stdio: ['pipe', 'pipe', 'pipe'],
          cwd: workDir,
        });
        let stdout = '';
        let stderr = '';
        const cleanup = () => {
          try {
            fs.rmSync(tempDir, { recursive: true, force: true });
          } catch {}
        };
        const timer = setTimeout(() => {
          proc.kill('SIGKILL');
          cleanup();
          resolve({
            stdout,
            stderr: (stderr + '\\nTimed out after ' + timeoutMs + 'ms').trim(),
            exitCode: 124,
          });
        }, timeoutMs);

        proc.stdout.on('data', (chunk) => { stdout += chunk.toString(); });
        proc.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
        proc.on('close', (code) => {
          clearTimeout(timer);
          cleanup();
          resolve({ stdout, stderr, exitCode: code ?? 0 });
        });
        proc.on('error', (err) => {
          clearTimeout(timer);
          cleanup();
          resolve({ stdout: '', stderr: err.message, exitCode: 1 });
        });
        if (input) {
          proc.stdin.write(input);
        }
        proc.stdin.end();
      });
    })
  `)(schemaContent, cliArgs, input, cwd, timeoutMs)->Obj.magic
}
