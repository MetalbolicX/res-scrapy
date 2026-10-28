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
  ~setEnv: array<(string, string)>=[],
  ~unsetEnv: array<string>=[],
): promise<cliResult> => {
  %raw(`
    (async (args, input, cwd, timeoutMs, setEnv, unsetEnv) => {
      const { spawn } = await import('node:child_process');
      const fs = await import('node:fs');
      const { join } = await import('node:path');
      const workDir = cwd && cwd.length > 0 ? cwd : process.cwd();
      const cliPath = join(workDir, 'dist', 'main.mjs');
      const hasEnvOverrides = setEnv.length > 0 || unsetEnv.length > 0;
      const env = { ...process.env };
      for (const [key, value] of setEnv) { env[key] = value; }
      for (const key of unsetEnv) { delete env[key]; }
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
          ...(hasEnvOverrides ? { env } : {}),
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
  `)(args, input, cwd, timeoutMs, setEnv, unsetEnv)->Obj.magic
}

/** Keeps stdin open until the child closes; resolves only after all output drains. */
let runCliAndSignal = (
  ~args: array<string>,
  ~signal: string,
  ~input: string="",
  ~afterMs: int,
  ~timeoutMs: int=defaultTimeoutMs,
): promise<cliResult> => {
  %raw(`
    (async (args, signal, input, afterMs, timeoutMs) => {
      const { spawn } = await import('node:child_process');
      const { join } = await import('node:path');
      const cliPath = join(process.cwd(), 'dist', 'main.mjs');
      // Under load the child can lose the race to install its signal handlers
      // and die from the raw signal instead (Node reports code === null). Retry
      // only that signature, with a longer delay each time; after the last
      // attempt the result is returned unchanged so a real regression fails.
      const attemptDelays = [afterMs, 1000, 2000];
      const runOnce = delayMs =>
        new Promise((resolve) => {
          const proc = spawn(process.execPath, [cliPath, ...args], {
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
          const signalTimer = setTimeout(() => { proc.kill(signal); }, delayMs);
          const deadlineTimer = setTimeout(() => {
            timedOut = true;
            clearTimers();
            proc.kill('SIGKILL');
            proc.stdin.destroy();
          }, timeoutMs);
          proc.stdout.on('data', chunk => { stdout += chunk.toString(); });
          proc.stderr.on('data', chunk => { stderr += chunk.toString(); });
          proc.stdin.on('error', () => {});
          if (input) { proc.stdin.write(input); proc.stdin.end(); }
          proc.on('error', err => {
            spawnError = err;
            clearTimers();
            proc.kill('SIGKILL');
            proc.stdin.destroy();
          });
          proc.on('close', (code, closeSignal) => {
            if (settled) return;
            settled = true;
            clearTimers();
            proc.stdin.destroy();
            proc.stdout.destroy();
            proc.stderr.destroy();
            if (timedOut) stderr += '\\nTimed out after ' + timeoutMs + 'ms';
            if (spawnError) stderr += '\\n' + spawnError.message;
            resolve({
              stdout,
              stderr,
              exitCode: timedOut ? 124 : spawnError ? 1 : code ?? -1,
              killedByRawSignal: !timedOut && !spawnError && code === null && closeSignal === signal,
            });
          });
        });
      let result = { stdout: '', stderr: '', exitCode: -1 };
      for (const delayMs of attemptDelays) {
        const attempt = await runOnce(delayMs);
        const { killedByRawSignal, ...cliResult } = attempt;
        result = cliResult;
        if (!killedByRawSignal) break;
      }
      return result;
    })
  `)(args, signal, input, afterMs, timeoutMs)->Obj.magic
}

/** Spawns the CLI with stdout paused so writes buffer in the pipe, polls until
  * some output exists (never a fixed sleep), kills the child with `signal`,
  * then resumes and drains the remaining bytes. Exercises the production
  * `exitAfterFlush` wiring: stdout buffered while the reader is paused must
  * still be delivered before the process terminates. */
let runCliPausedStdoutAndSignal = (
  ~args: array<string>,
  ~signal: string,
  ~input: string="",
  ~timeoutMs: int=defaultTimeoutMs,
): promise<cliResult> => {
  %raw(`
    (async (args, signal, input, timeoutMs) => {
      const { spawn } = await import('node:child_process');
      const { join } = await import('node:path');
      const cliPath = join(process.cwd(), 'dist', 'main.mjs');
      return new Promise((resolve) => {
        const proc = spawn(process.execPath, [cliPath, ...args], {
          stdio: ['pipe', 'pipe', 'pipe'],
        });
        let stdout = '';
        let stderr = '';
        let settled = false;
        let pollTimer = null;
        const timer = setTimeout(() => {
          if (settled) return;
          settled = true;
          if (pollTimer) clearInterval(pollTimer);
          proc.kill('SIGKILL');
          proc.stdout.resume();
          resolve({
            stdout,
            stderr: (stderr + '\\nTimed out after ' + timeoutMs + 'ms').trim(),
            exitCode: 124,
          });
        }, timeoutMs);
        proc.stdout.pause();
        proc.stdout.on('data', chunk => { stdout += chunk.toString(); });
        proc.stderr.on('data', chunk => { stderr += chunk.toString(); });
        // Signal only once the child has produced output: handlers are then
        // long installed, so no raw-signal race retries are needed here.
        pollTimer = setInterval(() => {
          if (proc.stdout.readableLength > 0) {
            clearInterval(pollTimer);
            pollTimer = null;
            proc.kill(signal);
            proc.stdout.resume();
          }
        }, 100);
        proc.stdin.on('error', () => {});
        proc.on('error', err => {
          if (settled) return;
          settled = true;
          if (pollTimer) clearInterval(pollTimer);
          clearTimeout(timer);
          resolve({ stdout: '', stderr: err.message, exitCode: 1 });
        });
        proc.on('close', code => {
          if (settled) return;
          settled = true;
          if (pollTimer) clearInterval(pollTimer);
          clearTimeout(timer);
          proc.stdout.resume();
          resolve({ stdout, stderr, exitCode: code ?? -1 });
        });
        if (input) { proc.stdin.write(input); }
        proc.stdin.end();
      });
    })
  `)(args, signal, input, timeoutMs)->Obj.magic
}

/** Spawns the CLI reading stdout normally, then DESTROYS the stdout pipe once
  * `destroyAfterBytes` have been received (like `res-scrapy ... | head -c N`).
  * Reports the exit code, stderr, and the bytes delivered before the close. */
let runCliWithEarlyReaderClose = (
  ~args: array<string>,
  ~input: string="",
  ~destroyAfterBytes: int,
  ~timeoutMs: int=defaultTimeoutMs,
): promise<(cliResult, int)> => {
  %raw(`
    (async (args, input, destroyAfterBytes, timeoutMs) => {
      const { spawn } = await import('node:child_process');
      const { join } = await import('node:path');
      const cliPath = join(process.cwd(), 'dist', 'main.mjs');
      return new Promise((resolve) => {
        const proc = spawn(process.execPath, [cliPath, ...args], {
          stdio: ['pipe', 'pipe', 'pipe'],
        });
        let stdout = '';
        let stderr = '';
        let delivered = 0;
        let destroyed = false;
        const timer = setTimeout(() => {
          proc.kill('SIGKILL');
          resolve([{ stdout, stderr: (stderr + '\\nTimed out after ' + timeoutMs + 'ms').trim(), exitCode: 124 }, delivered]);
        }, timeoutMs);
        proc.stdout.on('data', chunk => {
          if (destroyed) return;
          delivered += chunk.length;
          stdout += chunk.toString();
          if (delivered >= destroyAfterBytes) {
            destroyed = true;
            proc.stdout.destroy();
          }
        });
        proc.stderr.on('data', chunk => { stderr += chunk.toString(); });
        proc.stdin.on('error', () => {});
        proc.on('error', err => {
          clearTimeout(timer);
          resolve([{ stdout: '', stderr: err.message, exitCode: 1 }, delivered]);
        });
        proc.on('close', code => {
          clearTimeout(timer);
          resolve([{ stdout, stderr, exitCode: code ?? -1 }, delivered]);
        });
        if (input) { proc.stdin.write(input); proc.stdin.end(); }
      });
    })
  `)(args, input, destroyAfterBytes, timeoutMs)->Obj.magic
}

/** Spawns the CLI with stdout redirected to `stdoutPath` (e.g. `/dev/full`,
  * which fails every write with ENOSPC like a full disk) and reports the exit
  * code and stderr. stdout is not captured. */
let runCliWithStdoutPath = (
  ~args: array<string>,
  ~input: string="",
  ~stdoutPath: string,
  ~timeoutMs: int=defaultTimeoutMs,
): promise<cliResult> => {
  %raw(`
    (async (args, input, stdoutPath, timeoutMs) => {
      const { spawn } = await import('node:child_process');
      const fs = await import('node:fs');
      const { join } = await import('node:path');
      const cliPath = join(process.cwd(), 'dist', 'main.mjs');
      const outFd = fs.openSync(stdoutPath, 'w');
      return new Promise((resolve) => {
        const proc = spawn(process.execPath, [cliPath, ...args], {
          stdio: ['pipe', outFd, 'pipe'],
        });
        fs.closeSync(outFd);
        let stderr = '';
        const timer = setTimeout(() => {
          proc.kill('SIGKILL');
          resolve({ stdout: '', stderr: (stderr + '\\nTimed out after ' + timeoutMs + 'ms').trim(), exitCode: 124 });
        }, timeoutMs);
        proc.stderr.on('data', chunk => { stderr += chunk.toString(); });
        proc.stdin.on('error', () => {});
        proc.on('error', err => {
          clearTimeout(timer);
          resolve({ stdout: '', stderr: err.message, exitCode: 1 });
        });
        proc.on('close', code => {
          clearTimeout(timer);
          resolve({ stdout: '', stderr, exitCode: code ?? -1 });
        });
        if (input) { proc.stdin.write(input); }
        proc.stdin.end();
      });
    })
  `)(args, input, stdoutPath, timeoutMs)->Obj.magic
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
