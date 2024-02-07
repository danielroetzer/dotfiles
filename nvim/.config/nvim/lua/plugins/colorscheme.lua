-- https://github.com/catppuccin/nvim
return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  --@class CatppuccinOptions
  config = function()
    require("catppuccin").setup({
      flavour = "mocha", -- latte, frappe, macchiato, mocha
      transparent_background = true,
      styles = {
         sidebars = "transparent",
         floats = "transparent",
      },
    })

    vim.cmd.colorscheme "catppuccin-mocha"
  end,
}
