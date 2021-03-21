const container = document.getElementById("container")!;
const input = <HTMLInputElement>document.getElementById("input")!;
const inputBox = document.getElementById("input-box")!;

function boot(): void {
  const system = new System();
  input.focus();
  input.addEventListener("keypress", (event) => {
    if (event.keyCode === 13) {
      const command = input.value;
      input.value = "";
      system.run(command);
    }
  });

  input.addEventListener("keydown", (event) => {
    if (event.keyCode === 9) {
      event.preventDefault();
      const completion = autocomplete(system, input.value);
      if (completion) {
        input.value = input.value + completion;
      }
    }
  });
}

function autocomplete(system: System, text: string): string | null {
  const words = text.split(" ");
  let word = words[words.length - 1];
  const parentPath = getParentPath(word);

  let d;
  if (parentPath === "/") {
    word = word.slice(1);
    d = system.getFileByName(parentPath);
  } else if (parentPath !== "") {
    word = word.slice(parentPath.length + 1);
    d = system.getFileByName(parentPath);
  } else {
    d = system.getWorkingDirectory();
  }

  if (!d || !d.children) {
    return null;
  }

  for (const childId of d.children) {
    const childEntry = system.getFile(childId)!;
    if (childEntry.name.startsWith(word)) {
      return childEntry.name.slice(word.length);
    }
  }

  return null;
}

function getParentPath(path: string): string {
  const slashIndex = path.lastIndexOf("/");
  if (slashIndex === 0) {
    return "/";
  } else if (slashIndex !== -1) {
    return path.slice(0, slashIndex);
  } else {
    return "";
  }
}

interface FileEntry {
  id: number;
  parent: number | null;
  name: string;
  directory: boolean;
  children?: number[];
  contents?: string;
}

class System {
  private stdout: Shell;
  private binaries: Map<string, (system: System, words: string[]) => void>;
  private files: Map<number, FileEntry>;
  private workingDirectory: number;

  constructor() {
    this.stdout = new Shell();

    this.binaries = new Map();
    this.binaries.set("pwd", pwd);
    this.binaries.set("cd", cd);
    this.binaries.set("show", show);
    this.binaries.set("s", show);

    this.files = new Map();
    this.files.set(0, {
      id: 0,
      parent: null,
      name: "/",
      directory: true,
      children: [1, 2],
    });
    this.files.set(1, {
      id: 1,
      parent: 0,
      name: "documents",
      directory: true,
      children: [3, 4],
    });
    this.files.set(2, {
      id: 2,
      parent: 0,
      name: "pictures",
      directory: true,
      children: [],
    });
    this.files.set(3, {
      id: 3,
      parent: 1,
      name: "hello.txt",
      directory: false,
      contents: "Hello, world!\n",
    });
    this.files.set(4, {
      id: 4,
      parent: 1,
      name: "haiku.txt",
      directory: false,
      // Courtesy of https://www.gnu.org/fun/jokes/error-haiku.en.html
      contents:
        "A file that big?\nIt might be very useful.\nBut now it is gone.\n",
    });

    this.workingDirectory = 0;
  }

  run(command: string): void {
    this.stdout.printPrompt("> " + command);
    const words = command.split(" ");
    const name = words[0];
    const args = words.slice(1);
    if (name === "") {
      return;
    } else {
      const handler = this.binaries.get(name);
      if (handler) {
        handler(this, args);
      } else {
        this.stdout.print(`Command not found: ${name}`);
      }
    }
    this.stdout.flush();
  }

  getWorkingDirectory(): FileEntry {
    return this.files.get(this.workingDirectory)!;
  }

  setWorkingDirectory(id: number): void {
    const entry = this.getFile(id);
    if (entry && entry.directory) {
      this.workingDirectory = id;
    }
  }

  getFile(id: number): FileEntry | null {
    return this.files.get(id) ?? null;
  }

  getFileByName(name: string): FileEntry | null {
    if (name === ".") {
      return this.getWorkingDirectory();
    }

    let d = (name.startsWith("/")
      ? this.getFile(0)
      : this.getWorkingDirectory())!;

    for (const part of name.split("/")) {
      if (part === "" || part === ".") {
        continue;
      }

      if (!d.directory) {
        return null;
      }

      if (part === "..") {
        if (d.parent === null) {
          return null;
        } else {
          d = this.getFile(d.parent)!;
        }
      } else {
        let found = false;
        for (const childId of d.children!) {
          const child = this.getFile(childId)!;
          if (child.name === part) {
            d = child!;
            found = true;
            break;
          }
        }

        if (!found) {
          return null;
        }
      }
    }

    return d;
  }

  getStdout(): Shell {
    return this.stdout;
  }
}

class Shell {
  private buffer: (HTMLElement | Text)[];

  constructor() {
    this.buffer = [];
  }

  print(text: string): void {
    this.printWithCssClass(text);
  }

  printPrompt(prompt: string): void {
    this.printWithCssClass(prompt, "prompt");
    this.print("\n");
  }

  printFileName(name: string): void {
    this.printWithCssClass(name, "cartouche");
  }

  printError(text: string): void {
    this.printWithCssClass(text, "error");
  }

  printWithCssClass(text: string, cssClass?: string): void {
    if (cssClass) {
      const span = document.createElement("span");
      span.classList.add(cssClass);
      span.textContent = text;
      this.buffer.push(span);
    } else {
      const textNode = document.createTextNode(text);
      this.buffer.push(textNode);
    }
  }

  flush() {
    if (this.buffer.length === 0) {
      return;
    }

    const code = document.createElement("code");

    for (const child of this.buffer) {
      code.appendChild(child);
    }

    const pre = document.createElement("pre");
    pre.appendChild(code);

    container.insertBefore(pre, inputBox);
    this.buffer.length = 0;
  }
}

function pwd(system: System, words: string[]): void {
  const stdout = system.getStdout();

  if (words.length !== 0) {
    stdout.printError("pwd accepts no arguments.");
    return;
  }

  let d = system.getWorkingDirectory();
  const parts = [];
  while (d.parent !== null) {
    parts.push(d.name);
    d = system.getFile(d.parent)!;
  }
  stdout.print("/" + parts.join("/"));
}

function cd(system: System, words: string[]): void {
  const stdout = system.getStdout();

  if (words.length !== 1) {
    stdout.printError("cd requires exactly one argument.");
    return;
  }

  const destination = system.getFileByName(words[0]);
  if (destination === null) {
    stdout.printError(`Directory does not exist: ${words[0]}`);
  } else {
    system.setWorkingDirectory(destination.id);
  }
}

function show(system: System, words: string[]): void {
  const stdout = system.getStdout();

  if (words.length > 1) {
    stdout.printError("show requires zero or one argument.");
    return;
  }

  const file =
    words.length === 0
      ? system.getWorkingDirectory()
      : system.getFileByName(words[0]);
  if (file === null) {
    stdout.printError(`File does not exist: ${words[0]}`);
  } else {
    if (file.directory) {
      for (const childId of file.children!) {
        const childEntry = system.getFile(childId)!;
        stdout.printFileName(childEntry.name);
        stdout.print("\n");
      }
    } else {
      stdout.print(file.contents!);
    }
  }
}

boot();
