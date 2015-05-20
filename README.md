# linter-lua-findglobals

Check global variable access on the fly. Based on the [FindGlobals](http://www.wowace.com/addons/findglobals/) lua script by Mikk.

Due to the way that `luac` works, global variables will only be highlighted while there is not an error found in the file.

###  What do I need to know about globals for?

To optimize performance, you may want to declare `local` versions of commonly used functions and variables rather than make global namespace lookups.

Some global variables you may be okay with being global accesses (or in fact NEED them to because they can be hooked or changed), for those you have two options:

1.  Add one or more `-- GLOBALS: SomeFunc, SomeOtherFunc, SomeGlobalVariable` lines to the source file. This will ignore the variables.
2.  Put a `local _G = _G` at the top of the file, and then access them through `_G.SomeFunc`. This is actually somewhat faster than accessing them directly, believe it or not. Direct global access involves looking up the global variable table first!

Another benefit is finding the odd misspelled variable name or blocks of code that you may have copy/pasted from another source but forgot to update variables used.

## Configuration

Packages -> linter-lua-findglobals -> Settings:

* **level** The error level used for messages. (Note: info messages are hidden by default in Linter's settings)
* **luac** Path to your `luac` executable.

## TODO

* Fix highlighting multiple variables on one line? (maybe a linter limitation)
* Add option to exclude globals from an external list and/or change their error level
* Maybe add back in the options I stripped from the original script (that I never used): separate settings for GETGLOBAL and SETGLOBAL checking in the global and function scopes and allow them to be set per-file in comments
