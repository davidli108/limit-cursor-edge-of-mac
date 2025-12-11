# Mouse Limiter for macOS

A Swift script that prevents the mouse cursor from entering the top pixels of your screen using CGEventTap.

## Compile the Swift script

In the same folder:

```bash
swiftc MouseLimiter.swift -framework Cocoa -framework CoreGraphics -o MouseLimiter
```

This creates an executable file called `MouseLimiter` in the same directory.

## Give Terminal accessibility permission

Because this app moves your mouse, macOS blocks it unless you allow it.

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Make sure **Terminal** is listed and checked
3. If it's not there, click "+", add `Terminal.app`, then enable it
4. You might need to quit and reopen Terminal once

> If later you run this via another app, like iTerm or a compiled .app, that app will also need permission.

## Run the mouse limiter

Back in the `mouse-limit` folder:

```bash
./MouseLimiter
```

### What happens now

- The program is running, watching your mouse
- As soon as the cursor tries to go into the top `blockedTopHeight` pixels, it gets snapped back down
- Press `Ctrl+C` to stop the program
