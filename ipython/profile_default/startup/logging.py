from IPython.core.magic import register_line_magic
import logging


@register_line_magic
def loglevel(line):
    logging.root.setLevel(line.strip().upper())
