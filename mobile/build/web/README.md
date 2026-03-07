# Flutter Web

## Source map warnings in DevTools

When running the app in the browser you may see many **"No sources are declared in this source map"** messages in the console. These come from Flutter’s Dart Dev Compiler (DDC): it emits `.map` files for `packages/*.dart.lib.js` with empty `sources`, which is a [known Flutter web issue](https://github.com/flutter/flutter/issues/87734). They do **not** affect how the app runs.

**To hide these warnings in Chrome:**

1. Open DevTools (F12).
2. Open **Settings** (gear icon or `Ctrl+,` / `Cmd+,`).
3. Under **Preferences → Sources**, uncheck **Enable JavaScript source maps**.

Your own app code can still be debugged; only the framework/package source map warnings will stop appearing.
