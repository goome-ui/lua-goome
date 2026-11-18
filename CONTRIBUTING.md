<h1 align="center">🛠 Contributing to lua-goome 🛠</h1>

<p align="center">
Thanks for wanting to help! Small PRs that fix one thing are the easiest for me to check and merge, so keep them small and theyll get in way faster.<br>
This repo is only the Lua side. If the bug is in goome itself (drawing, a backend, the ui kit) it goes to <a href="https://github.com/goome-ui/c-goome">c-goome</a> instead, docs fixes go to <a href="https://github.com/goome-ui/docs">goome-ui/docs</a> (thats <a href="https://goome.wtf/docs/">goome.wtf/docs</a>) and new example projects to <a href="https://github.com/goome-ui/examples">goome-ui/examples</a>.
</p>

<details>
<summary align="center"><b>📋 The short version 📋</b></summary>

<p align="center">
• One thing per PR. One fix or one feature, if it does two things it gets closed<br>
• Open your PR against the <b>dev</b> branch, not main<br>
• Never touch <code>native/</code>, goome.h in there is copied from c-goome<br>
• Dont touch the protected files, a bot closes the PR if you do<br>
• Test it and say how you tested it, and on which OS<br>
• CI has to pass<br>
• AI is fine, but say you used it, and you need to know what every line does
</p>
</details>

<details>
<summary align="center"><b>💬 Before you start 💬</b></summary>

<p align="center">
Small fixes can go straight to a PR.<br>
For a new feature or anything big, <a href="https://github.com/goome-ui/lua-goome/issues">open an issue</a> first so we can talk about it before you spend a weekend on it.<br> <br>
Same if you want to rename something or change what a function takes or returns, people already use this so I want to talk that through first.
</p>
</details>

<details>
<summary align="center"><b>🌿 Branches 🌿</b></summary>

<p align="center">
Stuff goes dev, then beta, then main. I move it along, you only ever PR into <b>dev</b>.
</p>
</details>

<details>
<summary align="center"><b>🚫 What gets closed automatically 🚫</b></summary>

<p align="center">
A bot checks every PR and closes it with a comment if it hits any of these, fix it and open a new one.<br> <br>
It has to be against <b>dev</b>, main and beta only get stuff that already sat on dev for a while.<br> <br>
It cant touch <code>.github/</code>, since thats CI and these rules and a PR could just turn them off for itself. <code>native/</code> is off limits too, <code>goome.h</code> in there gets copied from c-goome by <code>tools/update_native.sh</code> and built on everyones computer. Same for <code>build.sh</code>, a <code>Makefile</code>, the rockspec and <code>tools/</code>, they all run on peoples computers when they build or install it. The <code>LICENSE</code> and the logo stay mine to change.<br> <br>
• <b>More than 3000 changed files</b> - way too big to check<br> <br>
Renaming or moving any of those files counts too. Think one of them is wrong? <a href="https://github.com/goome-ui/lua-goome/issues">Open an issue</a> and I'll fix it.
</p>
</details>

<details>
<summary align="center"><b>🤖 Using AI 🤖</b></summary>

<p align="center">
Using AI to help write your PR is allowed, as long as you say so in the PR and you know what your code does. If you get asked about something you should be able to answer without going back to the AI.<br> <br>
And test it yourself. Untested AI dumps get closed
</p>
</details>

<details>
<summary align="center"><b>🧪 Testing 🧪</b></summary>

<p align="center">
Build the module and run the tests, on Lua 5.4 and on LuaJIT. They all run on goome's test backend, so nothing shows up on your screen:
</p>

```sh
LUA_INC=/usr/include/lua5.4 ./build.sh test
LUA_INC=/usr/include/luajit-2.1 LUA=luajit ./build.sh test

# or by hand
LUA_CPATH="./?.so" lua tests/run.lua
```

<p align="center">
On Windows run <code>./build.sh</code> from git bash with mingw gcc on your PATH and <code>LUA_LIB</code> pointing at lua54.dll or lua51.dll. <code>tools/lua.sh lua-dist</code> builds both interpreters from source if you dont have them.<br> <br>
The layout test compiles <code>tests/layout.c</code> with your C compiler and checks the struct sizes and offsets the module was built with match, and another one checks every function in goome.h gets called somewhere in <code>src/lgoome.c</code>. Without a compiler the layout one skips, set <code>GOOME_STRICT=1</code> to make that a fail like CI does.<br> <br>
The drawing and ui tests check the same pixel hashes as the <code>tests/unit.c</code> in c-goome. Those come from the C code, so if one moves something in the binding is passing the wrong thing. Dont just update the number.<br> <br>
<code>examples/love/main.lua</code> doesnt run in CI, if you touch it run it in LÖVE yourself.<br> <br>
In the PR write a few lines on what you ran and on which OS and Lua. If it changes something you can see (an example, how something draws) add a before and after screenshot.<br> <br>
CI runs on linux, windows and both macs with Lua 5.4 and LuaJIT when you open the PR, plus a luarocks build. It has to be green before I merge.
</p>
</details>

<details>
<summary align="center"><b>✏️ Code style ✏️</b></summary>

<p align="center">
• C99 for <code>src/lgoome.c</code>, and only the Lua C API that Lua 5.1 already had (LuaJIT is 5.1). The few newer things go through the <code>LG_</code> macros at the top<br>
• Lua code has to run on both 5.4 and LuaJIT, so no <code>//</code>, no <code>&amp;</code> <code>|</code> <code>~</code> <code>&lt;&lt;</code>, no <code>goto</code>, no <code>&lt;close&gt;</code> in the examples or tests<br>
• No dependencies. Only goome.h and the Lua headers<br>
• Every function in goome.h stays reachable, the tests check that. New struct fields go in <code>src/layout.h</code> too<br>
• Anything that holds native memory gets a <code>close()</code> and a <code>__gc</code>, and closing twice is fine<br>
• If goome keeps a pointer you hand it past the call (like the window spot until <code>window_end</code>), that memory has to stay alive that long. Plain C locals wont<br>
• Match the code around it. snake_case, short names are fine inside functions<br>
• No comments unless something really isnt obvious<br>
• Dont reformat whole files, it makes the diff impossible to read
</p>
</details>

<details>
<summary align="center"><b>💬 Discussions and first issues 💬</b></summary>
<p align="center">
Questions and stuff you made with goome go in <a href="https://github.com/goome-ui/c-goome/discussions">Discussions</a>.<br>
If you want something to work on, the <a href="https://github.com/goome-ui/lua-goome/labels/good%20first%20issue">good first issue</a> ones are small. Comment on one before you start.
</p>
</details>

<p align="center">
Found a security hole? Dont open a public issue or PR for it, read <a href="https://github.com/goome-ui/.github/blob/main/SECURITY.md">SECURITY.md</a> and tell me privately first.<br> <br>
By sending a PR you agree your code goes out under the same <a href="LICENSE">GPL-3.0 license</a> as the rest of lua-goome.
</p>
