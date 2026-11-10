"""Convert a PDF to markdown plus images with marker, then have an LLM fix each chunk of pages.

Marker gets layout, tables, figures, and display math mostly right but garbles inline math.
Lines that look garbled are flagged, and an OpenAI model (run through `codex exec` with no
tools) returns replacements for wrong line ranges as structured output, along with short
descriptions of each figure that make it findable by search.
"""
