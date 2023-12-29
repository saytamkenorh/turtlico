Turtlico
========

Turtlico is a graphical tool designed for learning programming.

[➡️Open Turtlico Web⬅️](https://saytamkenorh.github.io/turtlico/)

Building
========

**Turtlico Editor**

```cargo run --package turtlico_editor```

**Build for WASM**

See the [turtlico-web](./.github/workflows/turtlico-web.yml) workflow.

**Standalone turtlicoscript**

```cargo test --package turtlicoscript```

```cargo run --package turtlicoscript_cli ./examples/turtle.tcsf```