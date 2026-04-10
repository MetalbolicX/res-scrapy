type cliResult = {
  stdout: string,
  stderr: string,
  exitCode: int,
}

let runCli = (
  ~args: array<string>=[],
  ~input: string="",
): promise<cliResult> => {
  let cliPath = "/home/metalbolicx/Documents/res-scrapy/dist/main.mjs"
  (%raw(`
    (async (cliPath, args, input) => {
      const { spawn } = await import('node:child_process');
      return new Promise((resolve) => {
        const proc = spawn('node', [cliPath, ...args], {
          stdio: ['pipe', 'pipe', 'pipe'],
        });
        let stdout = '';
        let stderr = '';
        proc.stdout.on('data', (chunk) => { stdout += chunk.toString(); });
        proc.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
        proc.on('close', (code) => {
          resolve({ stdout, stderr, exitCode: code ?? 0 });
        });
        proc.on('error', (err) => {
          resolve({ stdout: '', stderr: err.message, exitCode: 1 });
        });
        if (input) {
          proc.stdin.write(input);
        }
        proc.stdin.end();
      });
    })
  `)(cliPath, args, input))->Obj.magic
}

let runCliWithSchemaFile = (
  ~schemaPath: string,
  ~schemaContent: string,
  ~cliArgs: array<string>=[],
  ~input: string="",
): promise<cliResult> => {
  let cliPath = "/home/metalbolicx/Documents/res-scrapy/dist/main.mjs"
  (%raw(`
    (async (cliPath, schemaPath, schemaContent, cliArgs, input) => {
      const { spawn } = await import('node:child_process');
      const fs = await import('node:fs');
      fs.writeFileSync(schemaPath, schemaContent);
      return new Promise((resolve) => {
        const proc = spawn('node', [cliPath, ...cliArgs, '--schemaPath', schemaPath], {
          stdio: ['pipe', 'pipe', 'pipe'],
        });
        let stdout = '';
        let stderr = '';
        proc.stdout.on('data', (chunk) => { stdout += chunk.toString(); });
        proc.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
        proc.on('close', (code) => {
          resolve({ stdout, stderr, exitCode: code ?? 0 });
        });
        proc.on('error', (err) => {
          resolve({ stdout: '', stderr: err.message, exitCode: 1 });
        });
        if (input) {
          proc.stdin.write(input);
        }
        proc.stdin.end();
      });
    })
  `)(cliPath, schemaPath, schemaContent, cliArgs, input))->Obj.magic
}
