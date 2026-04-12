-- ~/.config/nvim/lua/plugins/dashboard.lua
return {
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      -- ──────────────────────────────────────────
      --  ASCII mascot
      -- ──────────────────────────────────────────
      local mascot = {
        "                                    ",
        "        ╭────────────────╮          ",
        "        │  ◕          ◕  │          ",
        "        │       ▽        │          ",
        "        │   ╰────────╯   │          ",
        "        ╰────────────────╯          ",
        "           ╱│        │╲             ",
        "         ─╯ └────────┘ ╰─          ",
        "                                    ",
      }

      -- ──────────────────────────────────────────
      --  Dynamic header: mascot + greeting + date/time
      -- ──────────────────────────────────────────
      local function build_header()
        local hour = tonumber(os.date("%H"))
        local greeting
        if     hour < 5  then greeting = "Still hacking?"
        elseif hour < 12 then greeting = "Good morning"
        elseif hour < 17 then greeting = "Good afternoon"
        elseif hour < 21 then greeting = "Good evening"
        else                  greeting = "Burning the midnight oil?"
        end

        local user = os.getenv("USER") or os.getenv("USERNAME") or "dev"
        local date = os.date("%A, %B %d %Y")
        local time = os.date("%H:%M")

        local lines = {}
        for _, l in ipairs(mascot) do
          table.insert(lines, l)
        end
        table.insert(lines, string.format("    %s, %s!    ", greeting, user))
        table.insert(lines, "")
        table.insert(lines, string.format("    %s  ·  %s    ", date, time))
        table.insert(lines, "")
        return lines
      end

      -- ──────────────────────────────────────────
      --  Daily tidbits — rotates once per day
      -- ──────────────────────────────────────────
      local tidbits = {
        "gd → go to definition   gr → references   K → hover docs",
        "<leader>ff → find files     <leader>fg → live grep",
        "<leader>rn renames a symbol across the whole codebase",
        "<leader>ca triggers code actions — try it on red squiggles",
        "gcc comments a line; gc in visual mode comments a selection",
        "]d / [d jumps between diagnostics in the buffer",
        "<leader>gg opens LazyGit — a full git TUI inside Neovim",
        "<F5> starts a debug session;  <F10> step over;  <F11> step in",
        "<leader>cf manually formats the file via conform.nvim",
        ":Lazy update — update plugins;   :MasonUpdate — update LSPs",
        "<leader>sd shows the diagnostic float under the cursor",
        "<Tab> / <S-Tab> navigate LuaSnip snippet placeholders",
        "<A-j> / <A-k> moves lines up and down — works in visual too",
        "<S-l> / <S-h> cycles through open buffers",
        "<C-h/j/k/l> moves between window splits",
        "<leader>gb blames the current line with full commit info",
        "<leader>du toggles the DAP debug panel layout",
        ":checkhealth — your first stop when something goes wrong",
        "<leader>e toggles the neo-tree file explorer sidebar",
        "<leader>fb lists all open buffers in telescope",
        ":TSInstall <lang> installs a treesitter parser on demand",
        ":ConformInfo shows which formatters are active in this buffer",
        "<C-Space> in insert mode manually triggers completion",
        "viw selects a word;   va{ selects a whole brace block",
        ":Lazy profile shows startup time broken down per plugin",
        "=G re-indents the whole file using treesitter",
        "<leader>q sends all diagnostics to the quickfix list",
        ":MasonInstall <pkg> — install any LSP, linter, or formatter",
        "ci' changes inside quotes;   ca( changes around parentheses",
        "<leader>gd opens a side-by-side git diff of the current file",
      }

      local function daily_tidbit()
        local day = tonumber(os.date("%j"))   -- 1–366, changes at midnight
        local tip = tidbits[(day % #tidbits) + 1]
        return "  💡  " .. tip
      end

      -- ──────────────────────────────────────────
      --  Assemble the dashboard
      -- ──────────────────────────────────────────
      dashboard.section.header.val = build_header()
      dashboard.section.header.opts.hl = "AlphaHeader"

      dashboard.section.buttons.val = {
        dashboard.button("f", "  Find file",    "<Cmd>Telescope find_files<CR>"),
        dashboard.button("r", "  Recent files", "<Cmd>Telescope oldfiles<CR>"),
        dashboard.button("g", "  Live grep",    "<Cmd>Telescope live_grep<CR>"),
        dashboard.button("n", "  New file",     "<Cmd>enew<CR>"),
        dashboard.button("s", "  Settings",     "<Cmd>e $MYVIMRC<CR>"),
        dashboard.button("q", "  Quit",         "<Cmd>qa<CR>"),
      }

      dashboard.section.footer.val = daily_tidbit()
      dashboard.section.footer.opts.hl = "Comment"

      -- Tighten the layout
      dashboard.config.layout = {
        { type = "padding", val = 1 },
        dashboard.section.header,
        dashboard.section.buttons,
        { type = "padding", val = 1 },
        dashboard.section.footer,
        { type = "padding", val = 1 },
      }

      alpha.setup(dashboard.config)
    end,
  },
}
