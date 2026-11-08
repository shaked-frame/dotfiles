; inherits: typescript

; Replace the plugin's TSX query: color braces, not JSX tag names.
(jsx_expression
  "{" @delimiter
  "}" @delimiter) @container
