type cliResult = {
  stdout: string,
  stderr: string,
  exitCode: int,
}

let defaultTimeoutMs = 10_000

let runCli = (
  ~args: array<string>=[],
  ~input: string="",
  ~timeoutMs: int=defaultTimeoutMs,
): promise<cliResult> => {
  (%raw(`
    (async (args, input, timeoutMs) => {
      const { spawn } = await import('node:child_process');
      const { join } = await import('node:path');
      const cliPath = join(process.cwd(), 'dist', 'main.mjs');
      return new Promise((resolve) => {
        const proc = spawn('node', [cliPath, ...args], {
          stdio: ['pipe', 'pipe', 'pipe'],
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
  `)(args, input, timeoutMs))->Obj.magic
}

let runCliWithSchemaFile = (
  ~schemaContent: string,
  ~cliArgs: array<string>=[],
  ~input: string="",
  ~timeoutMs: int=defaultTimeoutMs,
): promise<cliResult> => {
  (%raw(`
    (async (schemaContent, cliArgs, input, timeoutMs) => {
      const { spawn } = await import('node:child_process');
      const fs = await import('node:fs');
      const os = await import('node:os');
      const { join } = await import('node:path');
      const cliPath = join(process.cwd(), 'dist', 'main.mjs');
      const tempDir = fs.mkdtempSync(join(os.tmpdir(), 'res-scrapy-test-'));
      const schemaPath = join(tempDir, 'schema.json');
      fs.writeFileSync(schemaPath, schemaContent);

      return new Promise((resolve) => {
        const proc = spawn('node', [cliPath, ...cliArgs, '--schemaPath', schemaPath], {
          stdio: ['pipe', 'pipe', 'pipe'],
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
  `)(schemaContent, cliArgs, input, timeoutMs))->Obj.magic
}
