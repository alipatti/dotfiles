# type: ignore

import os

from IPython.terminal.prompts import Prompts

c = get_config()  # noqa: F821 (injected by ipython)

# ipython >= 9.13 draws image/png output inline in kitty by itself, so figures
# only need the inline backend. setting it through the environment is lazy:
# nothing is imported until matplotlib is, and envs without matplotlib still work
os.environ.setdefault("MPLBACKEND", "module://matplotlib_inline.backend_inline")

# kitty draws pngs at physical pixel size, so render at 2x for retina
c.InlineBackend.figure_formats = {"retina"}

IMAGE_COLUMNS = 80  # width of inline images, in terminal cells


def _kitty_png(png, metadata):
    """ipython's kitty renderer, but every image is IMAGE_COLUMNS wide."""
    import shutil
    from base64 import b64decode

    from IPython.core.getipython import get_ipython
    from IPython.core.kitty import png_to_kitty_ansi

    if isinstance(png, str):
        png = b64decode(png)

    # one short of the full width: kitty wraps the cursor to the next line after
    # an image that reaches the right edge, which adds a second blank line
    columns = min(IMAGE_COLUMNS, shutil.get_terminal_size().columns - 1)

    if not get_ipython().displayhook.is_active:
        print()  # newline for visual space

    print(png_to_kitty_ansi(png).replace("a=T,", f"a=T,c={columns},", 1))


if "KITTY_WINDOW_ID" in os.environ:
    c.TerminalInteractiveShell.mime_renderers = {"image/png": _kitty_png}


class _NoOutPrompts(Prompts):
    """no "Out[n]: " prefix, so results (and images) start at the left margin."""

    def out_prompt_tokens(self):
        return []


c.TerminalInteractiveShell.prompts_class = _NoOutPrompts
# blank line between the input and its result, like the one before each prompt
c.TerminalInteractiveShell.separate_out = "\n"

c.InteractiveShellApp.exec_lines = [
    "%load_ext autoreload",
    "%autoreload complete",
]
c.TerminalInteractiveShell.confirm_exit = False
c.TerminalIPythonApp.display_banner = False
