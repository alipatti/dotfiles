from IPython.core.magic import register_line_magic


@register_line_magic
def loglevel(line):
    import logging
    logging.root.setLevel(line.strip().upper())
