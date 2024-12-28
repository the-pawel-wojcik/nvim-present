# `nvim-present`
A tutorial on how to build an nvim plugin.

# Lua
The plugin is written in Lua.

# Features 
Execues code in codeblocks.

Works with lua
```lua
print("Lua code inside a codeblock")
```
mapped to `<space>e`.

## Now it also works with python 

```python
import sys
print("Running python version")
print(sys.version)
```
Extends to other interpreted languages by `opts.executors`

# Usage 

```Lua
require("present").start_presentation {} 
```

Use `n`, `p`, and `q` for navigation.

# Credits
[teej_dv](https://github.com/tjdevries/present.nvim)
