local ls = require("luasnip")

-- luasnip abbreviations
local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local d = ls.dynamic_node
local fmt = require("luasnip.extras.fmt").fmt
local fmta = require("luasnip.extras.fmt").fmta
local rep = require("luasnip.extras").rep

-- little helper to return the `index`th capture group
local c = function(index)
  return f(function(_, snip) return snip.captures[index] end)
end

-- helper functions to determine where to expand snippets
local tex = {}

tex.in_math = function() -- math context detection
  return vim.fn['vimtex#syntax#in_mathzone']() == 1
end

tex.in_text = function()
  return not tex.in_math()
end

tex.in_comment = function() -- comment detection
  return vim.fn['vimtex#syntax#in_comment']() == 1
end

tex.in_env = function(name) -- generic environment detection
  local is_inside = vim.fn['vimtex#env#is_inside'](name)
  return (is_inside[1] > 0 and is_inside[2] > 0)
end

tex.in_eq = function() -- equation environment detection
  return tex.in_env('equation')
end

tex.in_itemize = function() -- itemize environment detection
  return tex.in_env('itemize')
end

tex.in_tikz = function() -- TikZ picture environment detection
  return tex.in_env('tikzpicture')
end

-- define the snippets themselves
return {
  -- fraction
  s({ trig = "ff", snippetType = "autosnippet", },
    fmta(
      "\\frac{<>}{<>}",
      { i(1), i(2), }
    ),
    { condition = tex.in_math }
  ),

  -- simple integer fractions
  s({ trig = "f(%d)(%d)", snippetType = "autosnippet", regTrig = true, },
    fmta(
      "\\frac<><>",
      { c(1), c(2) }
    ),
    { condition = tex.in_math }
  ),


  -- sum
  s({ trig = "ss", snippetType = "autosnippet", },
    fmta(
      "\\sum_{<>}",
      { i(1), }
    ),
    { condition = tex.in_math }
  ),

  -- product
  s({ trig = "pp", snippetType = "autosnippet", },
    fmta(
      "\\prod_{<>}",
      { i(1), }
    ),
    { condition = tex.in_math }
  ),

  -- integral
  s({ trig = "ii", snippetType = "autosnippet", },
    fmta(
      "\\int_{<>}^{<>}",
      { i(1), i(2) }
    ),
    { condition = tex.in_math }
  ),

  -- environments
  -- TODO: make this programatic
  s({ trig = "\\beq%s", snippetType = "autosnippet", regTrig = true },
    fmta(
      [[
      \begin{equation}
          <>
      \end{equation}
      ]],
      { i(1) }
    )
  ),

  s({ trig = "\\bit\\s", snippetType = "autosnippet", regTrig = true },
    fmta(
      [[
      \begin{itemize}
          <>
      \end{itemize}
      ]],
      { i(1) }
    )
  ),


  s({ trig = "\\ben\\s", snippetType = "autosnippet", regTrig = true },
    fmta(
      [[
      \begin{enumerate}
          <>
      \end{enumerate}
      ]],
      { i(1) }
    )
  ),

  s({ trig = "\\baled\\s", snippetType = "autosnippet", regTrig = true },
    fmta(
      [[
      \begin{aligned}
          <>
      \end{aligned}
      ]],
      { i(1) }
    )
  ),
}
