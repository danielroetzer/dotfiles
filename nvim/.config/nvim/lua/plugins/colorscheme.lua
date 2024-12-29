-- https://www.lazyvim.org/plugins/colorscheme#catppuccin
-- https://github.com/catppuccin/nvim
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-mocha",
    },
  },
}
