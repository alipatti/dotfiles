"""Convert a PDF to markdown plus images, then fix its math and other errors.

A source makes the first draft: marker, which gets layout, tables, figures, and display
math mostly right but garbles inline math, or pdftotext, which is much faster but keeps
only the text. Rule-based steps then rewrite garbled math as LaTeX, and an OpenAI model
(run through `codex exec` with no tools) compares each chunk of pages against their images
and returns replacements for wrong line ranges as structured output, along with short
descriptions of each figure that make it findable by search.
"""
