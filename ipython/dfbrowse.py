"""native macos window for browsing polars dataframes.

mouse
- left click a column header to sort by it (ascending, descending, off)
- right click a column header to hide it (this also clears its filter); a
  button in the title bar shows the hidden columns again
- click a cell to select it, and hover one to see its full value

filters
- type under a header to filter that column. the text is cast to the column's
  dtype, optionally after one of >= <= != > < =
- string columns match substrings, ignoring case, or exactly after =
- `null` and `!null` match missing values in any column
- text that doesn't cast outlines the field in red and is ignored

keys, with the table focused
- h j k l or the arrows move the selection; g G 0 $ jump to the first and last
  row and column, and ctrl-d ctrl-u move half a page
- ctrl-, and ctrl-. swap the selected column with the one to its left or right
- s sorts by the selected column, x hides it, u shows the hidden columns
- y or cmd-c copies the selected value, Y the selected row as a dict
- / edits the selected column's filter; return or escape come back to the table
- escape clears every filter, and ? shows this list

needs pyobjc-framework-Cocoa and a running cocoa event loop (`%gui osx`).
the `browse` function in startup/browse.py takes care of the latter.
"""

import operator
from collections.abc import Callable
from functools import cache

import objc
import polars as pl
from AppKit import (
    NSAlert,
    NSApplication,
    NSApplicationActivationPolicyAccessory,
    NSApplicationActivationPolicyProhibited,
    NSAttributedString,
    NSBackingStoreBuffered,
    NSBezelStyleRecessed,
    NSBezierPath,
    NSButton,
    NSCell,
    NSColor,
    NSControlSizeSmall,
    NSDownArrowFunctionKey,
    NSEvent,
    NSEventModifierFlagCommand,
    NSEventModifierFlagControl,
    NSEventModifierFlagOption,
    NSFont,
    NSFontAttributeName,
    NSFontWeightRegular,
    NSForegroundColorAttributeName,
    NSImage,
    NSInsetRect,
    NSIntersectionRect,
    NSLayoutAttributeRight,
    NSLeftArrowFunctionKey,
    NSMenu,
    NSMenuItem,
    NSMutableParagraphStyle,
    NSNotification,
    NSParagraphStyleAttributeName,
    NSPasteboard,
    NSPasteboardTypeString,
    NSRightArrowFunctionKey,
    NSScrollView,
    NSTableColumn,
    NSTableHeaderCell,
    NSTableHeaderView,
    NSTableView,
    NSTableViewNoColumnAutoresizing,
    NSTableViewSelectionHighlightStyleNone,
    NSTableViewSolidVerticalGridLineMask,
    NSTableViewStylePlain,
    NSTextAlignmentRight,
    NSTextField,
    NSTextView,
    NSTitlebarAccessoryViewController,
    NSUpArrowFunctionKey,
    NSView,
    NSWindow,
    NSWindowStyleMaskClosable,
    NSWindowStyleMaskMiniaturizable,
    NSWindowStyleMaskResizable,
    NSWindowStyleMaskTitled,
)
from Foundation import NSMakePoint, NSMakeRect, NSObject, NSPoint, NSRect

type Comparison = Callable[[pl.Expr, pl.Expr], pl.Expr]
type Sort = tuple[str, bool]  # column name, descending
type Browsable = pl.DataFrame | pl.LazyFrame | pl.Series

DEFAULT_TITLE = "dataframe"
TITLE_HEIGHT = 24
FILTER_HEIGHT = 20
FILTER_MARGIN = 3
FILTER_DELAY = 0.25  # seconds of quiet before a typed filter applies
WIDTH_SAMPLE_ROWS = 100  # rows measured to choose the initial column widths
MAX_COLUMN_WIDTH = 240  # longer values are truncated; hover to read them
CELL_PADDING = 24  # room for the cell's margins and the sort arrow
# six significant digits, switching to scientific notation when that is shorter
FLOAT_FORMAT = ".6g"

# two character operators first, so ">=" isn't read as ">"
COMPARISONS: dict[str, Comparison] = {
    ">=": operator.ge,
    "<=": operator.le,
    "!=": operator.ne,
    ">": operator.gt,
    "<": operator.lt,
    "=": operator.eq,
}
STRING_DTYPES = (pl.String, pl.Categorical, pl.Enum)
BOOLEANS = {"true": True, "false": False}

# keys that move the selected cell, as (rows, columns)
FAR = 10**9  # further than any table goes; moves are clamped to the table
MOVES = {
    "j": (1, 0),
    "k": (-1, 0),
    "h": (0, -1),
    "l": (0, 1),
    NSDownArrowFunctionKey: (1, 0),
    NSUpArrowFunctionKey: (-1, 0),
    NSLeftArrowFunctionKey: (0, -1),
    NSRightArrowFunctionKey: (0, 1),
    "g": (-FAR, 0),
    "G": (FAR, 0),
    "0": (0, -FAR),
    "$": (0, FAR),
}
HALF_PAGES = {"d": 1, "u": -1}  # with control held
COLUMN_SWAPS = {",": -1, ".": 1}  # with control held
ESCAPE = "\x1b"
UNBOUND_MODIFIERS = (
    NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption
)

# the mouse, filter and key reference from the top of this file, shown by ?
HELP = __doc__.partition("\n\n")[2].partition("\n\nneeds ")[0]

# appkit holds data sources and delegates weakly, so keep them alive here
_open_browsers: list["FrameBrowser"] = []


def filter_predicate(name: str, dtype: pl.DataType, text: str) -> pl.Expr:
    """Expression keeping the rows of column `name` that match `text`.

    Raises
    ------
    ValueError
        If `text` cannot be cast to `dtype`.

    Examples
    --------
    >>> frame = pl.DataFrame({"a": [1, 2, None], "b": ["Null", "x", None]})
    >>> frame.filter(filter_predicate("a", pl.Int64(), ">= 2"))["a"].to_list()
    [2]
    >>> frame.filter(filter_predicate("a", pl.Int64(), "null")).height
    1
    >>> frame.filter(filter_predicate("b", pl.String(), "NU"))["b"].to_list()
    ['Null']
    >>> frame.filter(filter_predicate("b", pl.String(), "=x"))["b"].to_list()
    ['x']
    """
    column = pl.col(name)

    if text == "null":
        return column.is_null()

    if text == "!null":
        return column.is_not_null()

    if dtype in STRING_DTYPES:
        strings = column.cast(pl.String)

        if text.startswith("="):
            return strings == text.removeprefix("=")

        return strings.str.to_lowercase().str.contains(text.lower(), literal=True)

    symbol = next((symbol for symbol in COMPARISONS if text.startswith(symbol)), "=")
    literal = text.removeprefix(symbol).strip()
    return COMPARISONS[symbol](column, pl.lit(cast_text(literal, dtype), dtype=dtype))


def cast_text(text: str, dtype: pl.DataType) -> object:
    """Python value of `text` read as `dtype`, or a ValueError.

    Examples
    --------
    >>> cast_text("2020-01-01 12:30:00", pl.Datetime("us"))
    datetime.datetime(2020, 1, 1, 12, 30)
    >>> cast_text("TRUE", pl.Boolean())
    True
    """
    # polars doesn't cast strings to booleans
    if dtype == pl.Boolean and text.lower() in BOOLEANS:
        return BOOLEANS[text.lower()]

    if dtype.is_nested() or dtype == pl.Duration:
        raise ValueError(f"{dtype} columns can't be filtered")

    # the temporal parsers accept the text the cells show, which a cast doesn't
    if dtype == pl.Datetime:
        parsed = pl.lit(text).str.to_datetime(
            time_unit=dtype.time_unit, time_zone=dtype.time_zone
        )
    elif dtype == pl.Date:
        parsed = pl.lit(text).str.to_date()
    elif dtype == pl.Time:
        parsed = pl.lit(text).str.to_time()
    else:
        parsed = pl.lit(text).cast(dtype)

    try:
        return pl.select(parsed).item()
    except pl.exceptions.PolarsError as error:
        raise ValueError(f"{text!r} is not a {dtype}") from error


def next_sort(current: Sort | None, clicked: str) -> Sort | None:
    """Cycle a column through ascending, descending and unsorted."""
    if current is None or current[0] != clicked:
        return clicked, False

    return None if current[1] else (clicked, True)


def raw_text(value: object) -> str:
    """Text copied and shown in tooltips: the whole value at full precision."""
    if value is None:
        return "null"

    # polars hands back the cells of list and array columns as series
    return str(value.to_list() if isinstance(value, pl.Series) else value)


def display_text(value: object) -> str:
    """Text shown in a cell: `raw_text`, but with floats rounded."""
    is_float = isinstance(value, float)
    return format(value, FLOAT_FORMAT) if is_float else raw_text(value)


def dtype_label(dtype: pl.DataType) -> str:
    """Short name of a dtype, without time units, time zones or enum categories.

    Examples
    --------
    >>> dtype_label(pl.Datetime("us", "UTC")), dtype_label(pl.List(pl.Int64))
    ('Datetime', 'List(Int64)')
    """
    is_wordy = dtype.is_temporal() or dtype == pl.Enum
    return dtype.base_type().__name__ if is_wordy else str(dtype)


def unused_name(wanted: str, taken: list[str]) -> str:
    """`wanted`, repeated until no column in `taken` has that name."""
    name = wanted

    while name in taken:
        name += wanted

    return name


class TitleCell(NSTableHeaderCell):
    """header cell that draws in the top of the header, above the filter field."""

    def drawWithFrame_inView_(self, frame: NSRect, view: NSView) -> None:
        title_frame = NSMakeRect(
            frame.origin.x, frame.origin.y, frame.size.width, TITLE_HEIGHT
        )
        objc.super(TitleCell, self).drawWithFrame_inView_(title_frame, view)


class FilterField(NSTextField):
    """text field that can outline itself in red."""

    failed = False

    @objc.python_method
    def set_failed(self, failed: bool) -> None:
        self.failed = failed
        self.setNeedsDisplay_(True)

    def drawRect_(self, rect: NSRect) -> None:
        objc.super(FilterField, self).drawRect_(rect)

        if not self.failed:
            return

        outline = NSBezierPath.bezierPathWithRoundedRect_xRadius_yRadius_(
            NSInsetRect(self.bounds(), 1, 1), 3, 3
        )
        outline.setLineWidth_(2)
        NSColor.systemRedColor().setStroke()
        outline.stroke()


class FilterHeaderView(NSTableHeaderView):
    """table header with a filter field under each column title."""

    def initWithFields_(
        self, fields: dict[str, FilterField]
    ) -> "FilterHeaderView | None":
        height = TITLE_HEIGHT + FILTER_HEIGHT + 2 * FILTER_MARGIN
        # objective-c initializers may return a different object
        self = objc.super(FilterHeaderView, self).initWithFrame_(  # noqa: PLW0642
            NSMakeRect(0, 0, 0, height)
        )

        if self is None:
            return None

        self.fields = fields

        for field in fields.values():
            self.addSubview_(field)

        return self

    @objc.python_method
    def layout_fields(self) -> None:
        """Put every field under its column, wherever that column is now."""
        for index, column in enumerate(self.tableView().tableColumns()):
            field = self.fields[column.identifier()]
            field.setHidden_(column.isHidden())
            rect = self.headerRectOfColumn_(index)
            field.setFrame_(
                NSMakeRect(
                    rect.origin.x + FILTER_MARGIN,
                    TITLE_HEIGHT + FILTER_MARGIN,
                    rect.size.width - 2 * FILTER_MARGIN,
                    FILTER_HEIGHT,
                )
            )

    def rightMouseDown_(self, event: NSEvent) -> None:
        point = self.convertPoint_fromView_(event.locationInWindow(), None)
        index = self.columnAtPoint_(point)

        if index >= 0:
            column = self.tableView().tableColumns()[index]
            self.tableView().delegate().hide_column(column)


class CellTableView(NSTableView):
    """table view that selects single cells rather than rows.

    the selected column is tracked by name, so the selection survives columns
    being reordered. the browser is reached as the table's delegate.
    """

    selected_row = None
    selected_name = None

    @objc.python_method
    def visible_names(self) -> list[str]:
        return [
            column.identifier()
            for column in self.tableColumns()
            if not column.isHidden()
        ]

    @objc.python_method
    def select(self, row: int | None, name: str | None) -> None:
        self.selected_row, self.selected_name = row, name
        self.setNeedsDisplay_(True)

        if row is not None:
            self.scrollRowToVisible_(row)
            self.scrollColumnToVisible_(self.columnWithIdentifier_(name))

    @objc.python_method
    def move_selection(self, rows: int, columns: int) -> None:
        names = self.visible_names()

        if not names or self.numberOfRows() == 0:
            return

        if self.selected_row is None or self.selected_name not in names:
            # start at the top left of what is on screen. a single step stops
            # there, and only a jump to an edge carries on
            row, position = self.rowsInRect_(self.visibleRect()).location, 0
            rows, columns = (
                step if abs(step) == FAR else 0 for step in (rows, columns)
            )
        else:
            row, position = self.selected_row, names.index(self.selected_name)

        self.select(
            min(max(row + rows, 0), self.numberOfRows() - 1),
            names[min(max(position + columns, 0), len(names) - 1)],
        )

    @objc.python_method
    def swap_column(self, direction: int) -> None:
        """Swap the selected column with its neighbour that is showing."""
        names = self.visible_names()

        if self.selected_name not in names:
            return

        position = names.index(self.selected_name) + direction

        if 0 <= position < len(names):
            self.moveColumn_toColumn_(
                self.columnWithIdentifier_(self.selected_name),
                self.columnWithIdentifier_(names[position]),
            )
            self.scrollColumnToVisible_(self.columnWithIdentifier_(self.selected_name))

    @objc.python_method
    def leave_hidden_column(self) -> None:
        """Move the selection to the nearest column that is still showing."""
        if self.selected_name is None or self.selected_name in self.visible_names():
            return

        columns = list(self.tableColumns())
        index = self.columnWithIdentifier_(self.selected_name)
        # the columns after the hidden one, then those before it, nearest first
        by_distance = columns[index:] + columns[:index][::-1]
        showing = (c.identifier() for c in by_distance if not c.isHidden())
        nearest = next(showing, None)
        self.select(None if nearest is None else self.selected_row, nearest)

    @objc.python_method
    def half_page(self) -> int:
        row_height = self.rowHeight() + self.intercellSpacing().height
        return int(self.visibleRect().size.height / row_height / 2)

    @objc.python_method
    def copy_text(self, text: str) -> None:
        pasteboard = NSPasteboard.generalPasteboard()
        pasteboard.clearContents()
        pasteboard.setString_forType_(text, NSPasteboardTypeString)

    def mouseDown_(self, event: NSEvent) -> None:
        # not passed on to appkit, which would select the whole row
        point = self.convertPoint_fromView_(event.locationInWindow(), None)
        row, index = self.rowAtPoint_(point), self.columnAtPoint_(point)
        self.window().makeFirstResponder_(self)

        if min(row, index) < 0:
            self.select(None, None)
        else:
            self.select(row, self.tableColumns()[index].identifier())

    def keyDown_(self, event: NSEvent) -> None:
        key = event.charactersIgnoringModifiers()
        modifiers = event.modifierFlags() & UNBOUND_MODIFIERS

        if modifiers == NSEventModifierFlagControl and key in HALF_PAGES:
            self.move_selection(HALF_PAGES[key] * self.half_page(), 0)
        elif modifiers == NSEventModifierFlagControl and key in COLUMN_SWAPS:
            self.swap_column(COLUMN_SWAPS[key])
        elif modifiers:
            objc.super(CellTableView, self).keyDown_(event)
        elif key in MOVES:
            self.move_selection(*MOVES[key])
        elif not self.run_command(key):
            objc.super(CellTableView, self).keyDown_(event)

    @objc.python_method
    def run_command(self, key: str) -> bool:
        """Act on a key that isn't a movement, and say whether it was one of ours."""
        browser = self.delegate()
        selected = self.tableColumnWithIdentifier_(self.selected_name)

        if key == ESCAPE:
            browser.clear_filters()
        elif key == "?":
            browser.show_help()
        elif key == "u":
            browser.showAllColumns_(None)
        elif selected is None or selected.isHidden():
            # everything below acts on the selected cell
            return False
        elif key == "s":
            browser.sort_by(self.selected_name)
        elif key == "x":
            browser.hide_column(selected)
        elif key == "y":
            self.copy_(None)
        elif key == "Y":
            self.copy_text(str(browser.shown_row(self.selected_row)))
        elif key == "/":
            self.window().makeFirstResponder_(
                self.headerView().fields[self.selected_name]
            )
        else:
            return False

        return True

    def copy_(self, sender: object) -> None:
        if self.selected_row is not None:
            value = self.delegate().visible[self.selected_row, self.selected_name]
            self.copy_text(raw_text(value))

    def drawRow_clipRect_(self, row: int, clip: NSRect) -> None:
        index = self.columnWithIdentifier_(self.selected_name)

        # under the text, which the call to super draws
        if row == self.selected_row and index >= 0:
            highlight = NSColor.selectedContentBackgroundColor()
            highlight.colorWithAlphaComponent_(0.4).setFill()
            # the whole grid square, where the cell's own frame leaves margins
            square = NSIntersectionRect(self.rectOfColumn_(index), self.rectOfRow_(row))
            NSBezierPath.fillRect_(square)

        objc.super(CellTableView, self).drawRow_clipRect_(row, clip)


class FrameBrowser(NSObject):
    """data source and delegate for the table, its filter fields and its window."""

    def initWithFrame_title_(
        self, frame: pl.DataFrame, title: str
    ) -> "FrameBrowser | None":
        # objective-c initializers may return a different object
        self = objc.super(FrameBrowser, self).init()  # noqa: PLW0642

        if self is None:
            return None

        # a column that is never shown. it numbers the original rows, which lets
        # the selection follow its row through a sort or filter
        self.index_name = unused_name("#", frame.columns)
        self.source = frame.with_row_index(self.index_name)
        self.visible = self.source  # filtered and sorted
        self.title = title
        self.sort = None
        self.table = _table_view(self)
        self.show_columns_button = _show_columns_button(self)
        self.window = _window(self)
        self.table.headerView().layout_fields()
        self.refresh()
        return self

    # data source

    def numberOfRowsInTableView_(self, table_view: NSTableView) -> int:
        return self.visible.height

    def tableView_objectValueForTableColumn_row_(
        self, table_view: NSTableView, column: NSTableColumn, row: int
    ) -> str | NSAttributedString:
        value = self.visible[row, column.identifier()]

        if value is None:
            return _null_text(column.dataCell().alignment())

        return display_text(value)

    # table delegate

    def tableView_didClickTableColumn_(
        self, table_view: NSTableView, column: NSTableColumn
    ) -> None:
        self.sort_by(column.identifier())

    def tableView_toolTipForCell_rect_tableColumn_row_mouseLocation_(
        self,
        table_view: NSTableView,
        cell: NSCell,
        rect: NSRect,
        column: NSTableColumn,
        row: int,
        location: NSPoint,
    ) -> tuple[str, NSRect]:
        # rect is an in/out argument, so pyobjc wants it handed back
        return raw_text(self.visible[row, column.identifier()]), rect

    def tableViewColumnDidResize_(self, notification: NSNotification) -> None:
        self.table.headerView().layout_fields()

    def tableViewColumnDidMove_(self, notification: NSNotification) -> None:
        self.table.headerView().layout_fields()

    # filter field delegate

    def controlTextDidChange_(self, notification: NSNotification) -> None:
        # debounce: restart the countdown on every keystroke
        self.cancel_pending_refresh()
        self.performSelector_withObject_afterDelay_("applyFilters:", None, FILTER_DELAY)

    def applyFilters_(self, sender: object) -> None:
        self.refresh()

    def control_textView_doCommandBySelector_(
        self, control: NSTextField, text_view: NSTextView, command: str
    ) -> bool:
        # return and escape apply the filter now and hand the keyboard back
        if command not in ("insertNewline:", "cancelOperation:"):
            return False

        self.cancel_pending_refresh()
        self.refresh()
        self.window.makeFirstResponder_(self.table)
        return True

    # window delegate

    def windowWillClose_(self, notification: NSNotification) -> None:
        self.cancel_pending_refresh()
        self.table.setDataSource_(None)
        self.table.setDelegate_(None)
        self.source = self.visible = pl.DataFrame()
        # appkit isn't done with the window yet, so let go of it a moment later
        self.performSelector_withObject_afterDelay_("forget:", None, 0)

    def forget_(self, sender: object) -> None:
        _open_browsers.remove(self)

    def showAllColumns_(self, sender: object) -> None:
        for column in self.table.tableColumns():
            column.setHidden_(False)

        self.hidden_columns_changed()

    @objc.python_method
    def cancel_pending_refresh(self) -> None:
        NSObject.cancelPreviousPerformRequestsWithTarget_(self)

    @objc.python_method
    def sort_by(self, name: str) -> None:
        self.sort = next_sort(self.sort, name)
        self.refresh()

    @objc.python_method
    def hide_column(self, column: NSTableColumn) -> None:
        column.setHidden_(True)
        self.hidden_columns_changed()
        field = self.table.headerView().fields[column.identifier()]

        # a filter that can't be seen shouldn't keep hiding rows
        if field.stringValue():
            field.setStringValue_("")
            self.refresh()

    @objc.python_method
    def hidden_columns_changed(self) -> None:
        hidden = sum(column.isHidden() for column in self.table.tableColumns())
        self.show_columns_button.setTitle_(f"show {hidden} hidden")
        self.show_columns_button.sizeToFit()
        self.show_columns_button.setHidden_(hidden == 0)
        self.table.headerView().layout_fields()
        self.table.leave_hidden_column()

    @objc.python_method
    def show_help(self) -> None:
        reference = NSTextField.labelWithString_(HELP)
        reference.setFont_(_monospaced_font())
        reference.sizeToFit()

        alert = NSAlert.alloc().init()
        alert.setMessageText_("dataframe browser")
        alert.setAccessoryView_(reference)
        # a sheet, since a modal alert would stall ipython's event loop
        alert.beginSheetModalForWindow_completionHandler_(self.window, None)

    @objc.python_method
    def clear_filters(self) -> None:
        for field in self.table.headerView().fields.values():
            field.setStringValue_("")

        self.refresh()

    @objc.python_method
    def filter_predicates(self) -> list[pl.Expr]:
        """Predicates typed into the filter fields; text that doesn't cast turns red."""
        predicates = []

        for name, field in self.table.headerView().fields.items():
            text = field.stringValue().strip()
            field.set_failed(False)

            if not text:
                continue

            try:
                predicates.append(
                    filter_predicate(name, self.source.schema[name], text)
                )
            except ValueError:
                field.set_failed(True)

        return predicates

    @objc.python_method
    def shown_row(self, row: int) -> dict[str, object]:
        values = self.visible.row(row, named=True)
        return {
            name: value for name, value in values.items() if name != self.index_name
        }

    @objc.python_method
    def selected_index(self) -> int | None:
        """Original row number of the selected cell, which outlasts a refresh."""
        row = self.table.selected_row
        return None if row is None else self.visible[row, self.index_name]

    @objc.python_method
    def refresh(self) -> None:
        """Recompute the visible rows from the filter fields and the sort."""
        selected = self.selected_index()
        visible = self.source.filter(*self.filter_predicates())

        if self.sort is not None:
            name, descending = self.sort
            visible = visible.sort(name, descending=descending, nulls_last=True)

        self.visible = visible
        self.show_sort_indicator()
        self.table.reloadData()
        self.window.setTitle_(self.window_title())

        if selected is None or visible.is_empty():
            self.table.select(None, None)
            self.table.scrollRowToVisible_(0)
        else:
            # follow the selected row to its new place, or start over at the top
            row = visible[self.index_name].index_of(selected) or 0
            self.table.select(row, self.table.selected_name)

    @objc.python_method
    def show_sort_indicator(self) -> None:
        for column in self.table.tableColumns():
            image = None

            if self.sort is not None and self.sort[0] == column.identifier():
                direction = "Descending" if self.sort[1] else "Ascending"
                image = NSImage.imageNamed_(f"NS{direction}SortIndicator")

            self.table.setIndicatorImage_inTableColumn_(image, column)

    @objc.python_method
    def window_title(self) -> str:
        total, columns = self.source.shape
        shown = self.visible.height
        rows = f"{total:,}" if shown == total else f"{shown:,} of {total:,}"
        # less the hidden column of row numbers
        return f"{self.title} ({rows} x {columns - 1:,})"


def _monospaced_font() -> NSFont:
    return NSFont.monospacedSystemFontOfSize_weight_(12, NSFontWeightRegular)


@cache
def _null_text(alignment: int) -> NSAttributedString:
    """A dimmed "null", so a missing value doesn't look like the string "null"."""
    # attributed strings ignore the cell's alignment, so they carry their own
    paragraph = NSMutableParagraphStyle.alloc().init()
    paragraph.setAlignment_(alignment)
    attributes = {
        NSFontAttributeName: _monospaced_font(),
        NSForegroundColorAttributeName: NSColor.tertiaryLabelColor(),
        NSParagraphStyleAttributeName: paragraph,
    }
    return NSAttributedString.alloc().initWithString_attributes_("null", attributes)


def _filter_field(placeholder: str, delegate: FrameBrowser) -> FilterField:
    field = FilterField.alloc().init()
    field.setPlaceholderString_(placeholder)
    field.setFont_(_monospaced_font())
    field.setControlSize_(NSControlSizeSmall)
    field.setDelegate_(delegate)
    # long filters scroll inside the field rather than wrapping
    field.cell().setScrollable_(True)
    field.cell().setWraps_(False)
    return field


def _column_width(sample: pl.Series) -> float:
    """Width fitting the column name, its dtype and the sampled values."""
    texts = [sample.name, dtype_label(sample.dtype), *map(display_text, sample)]
    character_width = _monospaced_font().maximumAdvancement().width
    width = max(map(len, texts)) * character_width + CELL_PADDING
    return min(width, MAX_COLUMN_WIDTH)


def _table_column(sample: pl.Series) -> NSTableColumn:
    name, dtype = sample.name, sample.dtype
    column = NSTableColumn.alloc().initWithIdentifier_(name)
    column.setWidth_(_column_width(sample))
    column.setHeaderCell_(TitleCell.alloc().initTextCell_(name))
    column.setHeaderToolTip_(f"{name}: {dtype}")
    column.setEditable_(False)

    cell = column.dataCell()
    cell.setFont_(_monospaced_font())

    if dtype.is_numeric():
        cell.setAlignment_(NSTextAlignmentRight)

    return column


def _table_view(browser: FrameBrowser) -> CellTableView:
    table = CellTableView.alloc().init()

    shown = browser.source.drop(browser.index_name)

    for sample in shown.head(WIDTH_SAMPLE_ROWS):
        table.addTableColumn_(_table_column(sample))

    fields = {
        name: _filter_field(dtype_label(dtype), browser)
        for name, dtype in shown.schema.items()
    }
    table.setHeaderView_(FilterHeaderView.alloc().initWithFields_(fields))
    table.setDataSource_(browser)
    table.setDelegate_(browser)

    table.setStyle_(NSTableViewStylePlain)
    # the table draws its own highlight, for the one selected cell
    table.setSelectionHighlightStyle_(NSTableViewSelectionHighlightStyleNone)
    # typing would otherwise search every row for a value starting with that letter
    table.setAllowsTypeSelect_(False)
    table.setGridStyleMask_(NSTableViewSolidVerticalGridLineMask)
    table.setUsesAlternatingRowBackgroundColors_(True)
    # columns keep their own widths and the scroll view scrolls horizontally
    table.setColumnAutoresizingStyle_(NSTableViewNoColumnAutoresizing)
    return table


def _show_columns_button(browser: FrameBrowser) -> NSButton:
    button = NSButton.buttonWithTitle_target_action_("", browser, "showAllColumns:")
    button.setBezelStyle_(NSBezelStyleRecessed)
    button.setControlSize_(NSControlSizeSmall)
    button.setHidden_(True)
    return button


def _window(browser: FrameBrowser) -> NSWindow:
    style = (
        NSWindowStyleMaskTitled
        | NSWindowStyleMaskClosable
        | NSWindowStyleMaskMiniaturizable
        | NSWindowStyleMaskResizable
    )
    window = NSWindow.alloc().initWithContentRect_styleMask_backing_defer_(
        NSMakeRect(0, 0, 900, 600), style, NSBackingStoreBuffered, False
    )

    scroll = NSScrollView.alloc().init()
    scroll.setHasVerticalScroller_(True)
    scroll.setHasHorizontalScroller_(True)
    scroll.setDocumentView_(browser.table)
    window.setContentView_(scroll)
    # keys reach the table as soon as the window is clicked anywhere
    window.makeFirstResponder_(browser.table)

    # the title bar takes the table's background, so the two read as one surface
    window.setTitlebarAppearsTransparent_(True)
    window.setBackgroundColor_(NSColor.controlBackgroundColor())

    accessory = NSTitlebarAccessoryViewController.alloc().init()
    accessory.setView_(browser.show_columns_button)
    accessory.setLayoutAttribute_(NSLayoutAttributeRight)
    window.addTitlebarAccessoryViewController_(accessory)

    window.setDelegate_(browser)
    # python owns the window through the browser, so appkit must not free it
    window.setReleasedWhenClosed_(False)

    # remember size and position between launches
    if not window.setFrameUsingName_("dfbrowse"):
        window.center()

    if not _open_browsers:
        window.setFrameAutosaveName_("dfbrowse")
    else:
        # step down and right of the newest window, which would otherwise be
        # covered. only the first window saves its place, so this doesn't drift
        newest = _open_browsers[-1].window
        frame = newest.frame()
        top_left = NSMakePoint(frame.origin.x, frame.origin.y + frame.size.height)
        window.setFrameTopLeftPoint_(newest.cascadeTopLeftFromPoint_(top_left))

    return window


def _install_menu(application: NSApplication) -> None:
    """Key equivalents only work through a menu, even one that is never shown."""
    if application.mainMenu() is not None:
        return

    shortcuts = {
        "Close": ("performClose:", "w"),
        "Undo": ("undo:", "z"),
        "Cut": ("cut:", "x"),
        "Copy": ("copy:", "c"),
        "Paste": ("paste:", "v"),
        "Select All": ("selectAll:", "a"),
    }
    item = NSMenuItem.alloc().init()
    item.setSubmenu_(NSMenu.alloc().initWithTitle_("Edit"))

    for title, (action, key) in shortcuts.items():
        item.submenu().addItemWithTitle_action_keyEquivalent_(title, action, key)

    application.setMainMenu_(NSMenu.alloc().init())
    application.mainMenu().addItem_(item)


def browse(frame: Browsable, title: str = DEFAULT_TITLE) -> None:
    """Open a window showing `frame` as a sortable, filterable table.

    Parameters
    ----------
    frame
        The data to show. A lazy frame is collected, and a series becomes a
        frame of one column. The window keeps a reference to the result.
    title
        Window title, to which the shape is appended.
    """
    if isinstance(frame, pl.LazyFrame):
        frame = frame.collect()

    if isinstance(frame, pl.Series):
        frame = frame.to_frame()

    application = NSApplication.sharedApplication()

    # no dock icon or cmd-tab entry, like macos/webview.swift. a process that is
    # already an app, say through matplotlib's macosx backend, is left as it is
    if application.activationPolicy() == NSApplicationActivationPolicyProhibited:
        application.setActivationPolicy_(NSApplicationActivationPolicyAccessory)

    _install_menu(application)

    browser = FrameBrowser.alloc().initWithFrame_title_(frame, title)
    _open_browsers.append(browser)

    # show without activating so focus stays in the terminal
    browser.window.orderFrontRegardless()
