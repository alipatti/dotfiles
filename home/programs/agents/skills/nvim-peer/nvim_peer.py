#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["cyclopts", "pydantic", "pynvim"]
# ///
"""Inspect and drive the nvim open in another window of this kitty tab.

Each nvim inside kitty listens at ~/.cache/nvim/kitty/<kitty pid>-<window id>.sock,
with `ssh` for the pid over kitten ssh (see home/programs/nvim/runtime/init.lua).
Commands fail unless exactly one is running in the tab.
"""

import json
import os
import re
import socket
import subprocess
import sys
from pathlib import Path
from typing import Annotated, Any, Self

import pynvim
from cyclopts import App
from pydantic import (
    BaseModel,
    BeforeValidator,
    ConfigDict,
    PositiveInt,
    ValidationError,
    field_validator,
    model_validator,
)
from pynvim.api import NvimError

SOCKET_DIR = Path.home() / ".cache/nvim/kitty"

# path:L or path:L1-L2
SPAN = re.compile(r"(?P<path>.+?):(?P<start>\d+)(?:-(?P<stop>\d+))?")

# each snippet is a lua chunk run inside nvim over rpc. it gets its argument
# as `...`, and what it returns comes back as python values

INFO_LUA = r"""
local mode = vim.fn.mode()
local info = {
    file = vim.api.nvim_buf_get_name(0),
    modified = vim.bo.modified,
    cursor = vim.api.nvim_win_get_cursor(0),
    visible = { vim.fn.line("w0"), vim.fn.line("w$") },
}
local kind = mode:sub(1, 1)
if kind == "v" or kind == "V" or kind == "\22" then
    local a, b = vim.fn.getpos("v"), vim.fn.getpos(".")
    info.selection = {
        kind = kind,
        lines = { math.min(a[2], b[2]), math.max(a[2], b[2]) },
        text = table.concat(vim.fn.getregion(a, b, { type = kind }), "\n"),
    }
end
return info
"""

GOTO_LUA = r"""
local a = ...
vim.api.nvim_feedkeys(vim.keycode("<C-\\><C-n>"), "nx", false)
vim.cmd.normal({ "m'", bang = true })
local buf = vim.fn.bufadd(a.path)
if buf ~= vim.api.nvim_get_current_buf() then
    vim.cmd.buffer(buf)
end
local last = vim.api.nvim_buf_line_count(0)
vim.api.nvim_win_set_cursor(0, { math.min(a.start, last), 0 })
if a.stop then
    vim.cmd.normal({ "V", bang = true })
    vim.api.nvim_win_set_cursor(0, { math.min(a.stop, last), 0 })
end
vim.cmd.normal({ "zz", bang = true })
return ""
"""

# scheduled so the call returns before any "file changed" prompt blocks it
RELOAD_LUA = """
vim.schedule(function() vim.cmd.checktime() end)
return ""
"""

# replaces all annotations. holds no state between calls: notes are extmarks
# wrapped once to the code window's width, and the outline's keymaps and
# autocmds belong to its buffer, so they go when it closes
ANNOTATE_LUA = r"""
local annotations = ...
local ns = vim.api.nvim_create_namespace("claude_peer")
local selected_ns = vim.api.nvim_create_namespace("claude_peer_selected")
local OUTLINE = "claude_outline"

-- colors: the todo-comments CLAUDE keyword, tinted into the background
local function hl(name)
    return vim.api.nvim_get_hl(0, { name = name, link = false })
end
local function blend(fg, bg, alpha)
    local out = 0
    for _, shift in ipairs({ 16, 8, 0 }) do
        local f, b = math.floor(fg / 2 ^ shift) % 256, math.floor(bg / 2 ^ shift) % 256
        out = out * 256 + math.floor(f * alpha + b * (1 - alpha) + 0.5)
    end
    return out
end
local accent = hl("TodoFgCLAUDE").fg or hl("DiagnosticInfo").fg
local background = hl("Normal").bg
local tint = blend(accent, background, 0.08)
vim.api.nvim_set_hl(0, "ClaudeNote", { fg = accent, bg = tint, italic = true })
vim.api.nvim_set_hl(0, "ClaudeRange", { bg = tint })
vim.api.nvim_set_hl(0, "ClaudeRule", { fg = blend(accent, background, 0.35), bg = tint })
vim.api.nvim_set_hl(0, "ClaudeNumber", { fg = accent, bold = true })

local function clear_notes()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype ~= OUTLINE then
            vim.api.nvim_buf_clear_namespace(b, ns, 0, -1)
        end
    end
end
local function clear()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.bo[b].filetype == OUTLINE then
            vim.api.nvim_buf_delete(b, { force = true })
        end
    end
    clear_notes()
end
vim.api.nvim_create_user_command("ClearAnnotations", clear, { desc = "Clear Claude's annotations" })

clear()
if #annotations == 0 then
    return ""
end

-- the window to show code in: the current one, unless that's a float or special
local function is_code_window(w)
    local b = vim.api.nvim_win_get_buf(w)
    return vim.api.nvim_win_get_config(w).relative == "" and vim.bo[b].buftype == ""
end
local main = vim.api.nvim_get_current_win()
if not is_code_window(main) then
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if is_code_window(w) then
            main = w
            break
        end
    end
end

local function word_wrap(text, width)
    local out = {}
    for paragraph in (text .. "\n"):gmatch("(.-)\n") do
        local line = ""
        for word in paragraph:gmatch("%S+") do
            local candidate = line == "" and word or line .. " " .. word
            if line ~= "" and vim.api.nvim_strwidth(candidate) > width then
                table.insert(out, line)
                line = word
            else
                line = candidate
            end
        end
        table.insert(out, line)
    end
    return out
end

-- a note is a band across the whole code window, its text indented like the
-- code under it
local info = vim.fn.getwininfo(main)[1]
local width = info.width - info.textoff
for _, a in ipairs(annotations) do
    a.buf = vim.fn.bufadd(a.path)
    vim.fn.bufload(a.buf)
    -- pick up edits made on disk. a modified buffer would prompt, blocking the call
    if not vim.bo[a.buf].modified then
        vim.cmd("silent! checktime " .. a.buf)
    end
    local last = vim.api.nvim_buf_line_count(a.buf)
    a.row = math.min(a.start, last) - 1

    if a.stop then
        vim.api.nvim_buf_set_extmark(a.buf, ns, a.row, 0, {
            end_row = math.min(a.stop, last),
            hl_group = "ClaudeRange",
            hl_eol = true,
            strict = false,
        })
    end

    a.height = 0
    if a.text then
        local depth = vim.api.nvim_buf_call(a.buf, function() return vim.fn.indent(a.row + 1) end)
        local indent = string.rep(" ", depth)
        -- the note sits between two rules
        local rule = { { string.rep("─", width), "ClaudeRule" } }
        local virt = { rule }
        for _, line in ipairs(word_wrap(a.text, math.max(20, width - #indent - 1))) do
            local text = indent .. line
            text = text .. string.rep(" ", math.max(0, width - vim.api.nvim_strwidth(text)))
            table.insert(virt, { { text, "ClaudeNote" } })
        end
        table.insert(virt, rule)
        a.height = #virt
        vim.api.nvim_buf_set_extmark(a.buf, ns, a.row, 0, { virt_lines = virt, virt_lines_above = true })
    end
end

local entries = vim.tbl_filter(function(a) return a.outline end, annotations)
if #entries == 0 then
    return ""
end

-- the outline: a header per entry, then its summary or text, wrapped by the window
local lines, starts = {}, {}
for i, a in ipairs(entries) do
    table.insert(starts, #lines + 1)
    local span = a.stop and ("%d-%d"):format(a.start, a.stop) or tostring(a.start)
    table.insert(lines, ("%d  %s:%s"):format(i, vim.fn.fnamemodify(a.path, ":~:."), span))
    -- a long note can give a short summary to list instead
    local shown = a.summary or a.text
    if shown then
        for paragraph in (shown .. "\n"):gmatch("(.-)\n") do
            table.insert(lines, "   " .. paragraph)
        end
    end
    table.insert(lines, "")
end

-- a split across the bottom of the tab, at most 30% of its height
local outline_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(outline_buf, "Annotations")
vim.bo[outline_buf].filetype = OUTLINE
vim.bo[outline_buf].bufhidden = "wipe"
vim.api.nvim_buf_set_lines(outline_buf, 0, -1, false, lines)
vim.bo[outline_buf].modifiable = false

local height = math.min(#lines, math.max(5, math.floor(vim.o.lines * 0.3)))
local outline_win = vim.api.nvim_open_win(outline_buf, false, { split = "below", win = -1, height = height })
for option, value in pairs({
    number = false,
    relativenumber = false,
    signcolumn = "no",
    foldcolumn = "0",
    cursorline = false,
    spell = false,
    list = false,
    wrap = true,
    linebreak = true,
    breakindent = true,
    winfixheight = true,
}) do
    vim.wo[outline_win][option] = value
end

for i, start in ipairs(starts) do
    local digits = #tostring(i)
    vim.api.nvim_buf_set_extmark(outline_buf, ns, start - 1, 0, { end_col = digits, hl_group = "ClaudeNumber" })
    vim.api.nvim_buf_set_extmark(outline_buf, ns, start - 1, digits, {
        end_col = #lines[start],
        hl_group = "Comment",
    })
end

local function entry_at(line)
    local found = 1
    for i, start in ipairs(starts) do
        if start <= line then
            found = i
        end
    end
    return found
end

local current
local function select(i)
    current = i
    local a = entries[i]
    vim.api.nvim_buf_clear_namespace(outline_buf, selected_ns, 0, -1)
    local stop = (starts[i + 1] or #lines + 1) - 2
    vim.api.nvim_buf_set_extmark(outline_buf, selected_ns, starts[i] - 1, 0, {
        end_row = stop,
        hl_group = "ClaudeRange",
        hl_eol = true,
        strict = false,
    })

    -- center the note and its lines in the code window. a block taller than
    -- the window starts at the top instead, so its beginning stays visible
    if vim.api.nvim_win_is_valid(main) then
        vim.api.nvim_win_set_buf(main, a.buf)
        vim.api.nvim_win_set_cursor(main, { a.row + 1, 0 })
        local count = vim.api.nvim_buf_line_count(a.buf)
        local block = a.height + (a.stop and math.min(a.stop, count) - a.row or 1)
        local gap = math.floor((vim.api.nvim_win_get_height(main) - block) / 2)
        vim.api.nvim_win_call(main, function()
            if gap > 0 then
                local top = math.max(1, a.row + 1 - gap)
                -- a note above the first line only shows as filler
                vim.fn.winrestview({ topline = top, topfill = top == a.row + 1 and a.height or 0 })
            else
                vim.cmd("normal! zt")
                vim.fn.winrestview({ topfill = a.height })
            end
        end)
    end
end

local function jump(step)
    return function()
        local i = math.max(1, math.min(#entries, entry_at(vim.fn.line(".")) + step))
        vim.api.nvim_win_set_cursor(0, { starts[i], 0 })
    end
end

local map = function(lhs, rhs) vim.keymap.set("n", lhs, rhs, { buffer = outline_buf, nowait = true }) end
map("j", jump(1))
map("k", jump(-1))
map("q", "<cmd>close<cr>")
map("<cr>", function()
    if vim.api.nvim_win_is_valid(main) then
        vim.api.nvim_set_current_win(main)
    end
end)

-- closing the outline wipes it (bufhidden), taking the notes with it. this
-- runs synchronously so a new annotate call clears before it places its own
vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = outline_buf,
    once = true,
    callback = clear_notes,
})

vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = outline_buf,
    callback = function()
        local i = entry_at(vim.fn.line("."))
        if i ~= current then
            select(i)
        end
    end,
})

vim.api.nvim_set_current_win(outline_win)
vim.api.nvim_win_set_cursor(outline_win, { 1, 0 })
select(1)
return ""
"""

SELECTION_KINDS = {"v": "charwise", "V": "linewise", "\x16": "blockwise"}

app = App(name="_nvim_peer", help=__doc__)


def allowed_root() -> Path:
    """The caller's git repository, or its working directory outside one."""
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=False,
    )
    return Path(
        result.stdout.strip() if result.returncode == 0 else Path.cwd()
    ).resolve()


class Span(BaseModel):
    """Lines start..stop of a file, or just line start when stop is None."""

    path: Path
    start: PositiveInt
    stop: PositiveInt | None = None

    # _nvim_peer runs outside claude's sandbox, and info returns the selected
    # text, so files outside the caller's repo would get around the sandbox
    @field_validator("path")
    @classmethod
    def inside_root(cls, path: Path) -> Path:
        resolved = path.expanduser().resolve()
        root = allowed_root()

        if not resolved.is_relative_to(root):
            raise ValueError(f"{resolved} is outside {root}")

        if not resolved.is_file():
            raise ValueError(f"No such file: {resolved}")

        return resolved

    @model_validator(mode="after")
    def ordered(self) -> Self:
        if self.stop is not None and self.stop < self.start:
            raise ValueError(f"Range ends before it starts: {self.start}-{self.stop}")

        return self


def parse_span(location: object) -> object:
    """Split a path:L or path:L1-L2 string into Span fields."""
    if not isinstance(location, str):
        return location

    if not (match := SPAN.fullmatch(location)):
        raise ValueError(f"Expected path:L or path:L1-L2, got {location!r}")

    return match.groupdict()


class Annotation(BaseModel):
    model_config = ConfigDict(extra="forbid")

    location: Annotated[Span, BeforeValidator(parse_span)]
    text: str | None = None
    summary: str | None = None
    outline: bool = True

    @model_validator(mode="after")
    def shows_something(self) -> Self:
        if self.text is None and self.location.stop is None:
            raise ValueError(
                "An annotation without text needs a range (path:L1-L2) to highlight"
            )

        return self


class Annotations(BaseModel):
    model_config = ConfigDict(extra="forbid")

    annotations: list[Annotation]


def is_live(path: Path) -> bool:
    with socket.socket(socket.AF_UNIX) as sock:
        try:
            sock.connect(str(path))
        except OSError:
            return False

    return True


def lua(server: Path, code: str, arg: object = None) -> Any:
    """Run the lua chunk `code` in the nvim at `server`, passing it `arg`, and return its result."""
    try:
        with pynvim.attach("socket", path=str(server)) as nvim:
            return nvim.exec_lua(code, arg)
    except NvimError as error:
        sys.exit(f"nvim at {server} failed:\n{error}")


def live_servers() -> list[Path]:
    """Sockets of the nvims running in this kitty."""
    pattern = f"{os.environ.get('KITTY_PID', '*')}-*.sock"
    return [s for s in sorted(SOCKET_DIR.glob(pattern)) if is_live(s)]


def tab_window_ids() -> set[str] | None:
    """Ids of the windows in the caller's kitty tab, or None outside a kitty window."""
    if not (window := os.environ.get("KITTY_WINDOW_ID")):
        return None

    result = subprocess.run(
        ["kitten", "@", "ls", "--match-tab", f"window_id:{window}"],
        capture_output=True,
        text=True,
        check=False,
    )

    if result.returncode:
        sys.exit(f"kitten @ ls failed:\n{result.stderr}")

    return {
        str(w["id"])
        for os_window in json.loads(result.stdout)
        for tab in os_window["tabs"]
        for w in tab["windows"]
    }


def the_nvim() -> Path:
    """The socket of the one nvim in this kitty tab (or kitty, outside a window).

    Exits if there isn't exactly one.
    """
    tab = tab_window_ids()
    servers = [s for s in live_servers() if tab is None or s.stem.split("-")[-1] in tab]

    if not servers:
        sys.exit("No nvim is running in this kitty tab.")

    if len(servers) > 1:
        files = [
            lua(s, "return vim.api.nvim_buf_get_name(0)") or "[no name]"
            for s in servers
        ]
        listing = "\n".join(
            f"  window {s.stem.split('-')[-1]}: {f}" for s, f in zip(servers, files)
        )
        sys.exit(f"More than one nvim is running in this kitty tab:\n{listing}")

    return servers[0]


@app.command
def info():
    """Print the file, cursor, visible lines, and selection in nvim as json.

    Lines and columns start at 1. file is null for an unnamed buffer, and
    selection is null outside visual mode.
    """
    state = lua(the_nvim(), INFO_LUA)
    row, col = state["cursor"]
    first, last = state["visible"]
    selection = state.get("selection")

    print(
        json.dumps(
            {
                "file": state["file"] or None,
                "modified": state["modified"],
                "cursor": {"line": row, "column": col + 1},
                "visible": {"start": first, "stop": last},
                "selection": selection
                and {
                    "kind": SELECTION_KINDS[selection["kind"]],
                    "start": selection["lines"][0],
                    "stop": selection["lines"][1],
                    "text": selection["text"],
                },
            },
            indent=2,
        )
    )


@app.command
def goto(location: str):
    """Open a file in nvim at path:L, or select lines path:L1-L2.

    The file must be inside the current git repository (or directory).
    """
    try:
        span = Span.model_validate(parse_span(location))
    except (ValidationError, ValueError) as error:
        sys.exit(f"Invalid location:\n{error}")

    # None arrives in lua as vim.NIL, which is truthy, so leave stop out
    lua(the_nvim(), GOTO_LUA, span.model_dump(mode="json", exclude_none=True))


@app.command
def annotate():
    """Replace the notes in nvim with the annotations given as json on stdin.

    {"annotations": [{"location": "path:L1-L2", "text": "...", "summary": "...", "outline": true}]}

    Each annotation shows its text above its location. A range (even 10-10)
    also highlights those lines; a single line (10) doesn't. Without text, an
    annotation only highlights, so it needs a range. Annotations with outline
    (the default) are listed in a split that steps through them, by their
    summary if given and their text otherwise; give a summary when the text is
    long. Closing the outline clears all notes, and so does an empty list.
    """
    try:
        annotations = Annotations.model_validate_json(sys.stdin.read()).annotations
    except ValidationError as error:
        sys.exit(f"Invalid annotations:\n{error}")

    # absent keys rather than Nones, which arrive in lua as the truthy vim.NIL
    payload = [
        a.location.model_dump(mode="json", exclude_none=True)
        | a.model_dump(include={"text", "summary", "outline"}, exclude_none=True)
        for a in annotations
    ]
    lua(the_nvim(), ANNOTATE_LUA, payload)


@app.command
def reload():
    """Reload buffers changed on disk in every nvim in this kitty."""
    for server in live_servers():
        lua(server, RELOAD_LUA)


if __name__ == "__main__":
    app()
