---
name: nvim-peer
description: "Load when the user refers to code by pointing at it in their editor ('this', 'here', 'this function', 'the selection', 'where my cursor is'), or when you want to show them code in their editor: jump to or select lines you are discussing, or walk them through code or changes with annotations. The user often has nvim open in another kitty window in the same tab."
---

# nvim peer

`_nvim_peer` inspects and drives the nvim open in another kitty window of
the same tab.
It fails unless exactly one nvim is running there.

- Run `_nvim_peer info` to see their file, cursor, visible lines,
  and selection, e.g. when they say "this" or "here".
- Run `_nvim_peer goto path:L[-L2]` to select code in their editor
  that you are discussing.
  The file must be inside the current repository.
- Pipe json to `_nvim_peer annotate` to walk the user through code
  or changes (see `_nvim_peer annotate --help` for the format).
  Each call replaces the previous annotations.
  Do not annotate unless the user asks for it.

The script is `nvim_peer.py` in this folder.
