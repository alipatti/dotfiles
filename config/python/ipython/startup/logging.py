from IPython.core.magic import register_line_magic


@register_line_magic
def loglevel(line: str):
    import logging

    if not line:
        level = logging._levelToName.get(logging.root.getEffectiveLevel())
        print("Current log level is", level)
        return

    level = line.strip().upper()
    print(f"Setting log level to {level}")
    logging.root.setLevel(level)
