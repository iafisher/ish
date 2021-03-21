const container = document.getElementById("container");
const input = document.getElementById("input");
const terminal = document.getElementById("terminal");
const inputBox = document.getElementById("input-box");

function onload() {
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

function autocomplete(system, text) {
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

  console.log(word, d.name);

  for (const childId of d.children) {
    const childEntry = system.getFile(childId);
    if (childEntry.name.startsWith(word)) {
      return childEntry.name.slice(word.length);
    }
  }

  return null;
}

function getParentPath(path) {
  const slashIndex = path.lastIndexOf("/");
  if (slashIndex === 0) {
    return "/";
  } else if (slashIndex !== -1) {
    return path.slice(0, slashIndex);
  } else {
    return "";
  }
}

class System {
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

  run(command) {
    this.stdout.printPrompt("> " + command, "prompt");
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

  getWorkingDirectory() {
    return this.files.get(this.workingDirectory);
  }

  setWorkingDirectory(id) {
    const entry = this.getFile(id);
    if (entry && entry.directory) {
      this.workingDirectory = id;
    }
  }

  getFile(id) {
    const r = this.files.get(id);
    return r === undefined ? null : r;
  }

  getFileByName(name) {
    if (name === ".") {
      return this.getWorkingDirectory();
    }

    let d = name.startsWith("/") ? this.getFile(0) : this.getWorkingDirectory();

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
          d = this.getFile(d.parent);
        }
      } else {
        let found = false;
        for (const childId of d.children) {
          const child = this.getFile(childId);
          if (child.name === part) {
            d = child;
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

  getStdout() {
    return this.stdout;
  }
}

class Shell {
  constructor() {
    this.buffer = [];
  }

  print(text) {
    this.printWithCssClass(text);
  }

  printPrompt(prompt) {
    this.printWithCssClass(prompt, "prompt");
    this.print("\n");
  }

  printFileName(name) {
    this.printWithCssClass(name, "cartouche");
  }

  printError(text) {
    this.printWithCssClass(text, "error");
  }

  printWithCssClass(text, cssClass) {
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

function pwd(system, words) {
  let d = system.getWorkingDirectory();
  const parts = [];
  while (d.parent !== null) {
    parts.push(d.name);
    d = system.getFile(d.parent);
  }
  system.getStdout().print("/" + parts.join("/"));
}

function cd(system, words) {
  const stdout = system.getStdout();

  if (words.length !== 1) {
    stdout.printError("cd requires exactly one argument.");
    return;
  }

  const destination = system.getFileByName(words[0]);
  if (destination === null) {
    stdout.printError(`Directory does not exist: ${words[0]}`);
  } else {
    stdout.setWorkingDirectory(destination.id);
  }
}

function show(system, words) {
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
      for (const childId of file.children) {
        const childEntry = system.getFile(childId);
        stdout.printFileName(childEntry.name);
        stdout.print("\n");
      }
    } else {
      stdout.print(file.contents);
    }
  }
}

onload();
