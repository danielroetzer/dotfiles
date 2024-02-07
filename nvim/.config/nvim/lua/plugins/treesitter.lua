-- https://github.com/nvim-treesitter/nvim-treesitter
return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function () 
    require("nvim-treesitter.configs").setup({
      ensure_installed = {
        "lua",
        "javascript",
        "typescript",
        "tsx",
        "graphql",
        "html",
        "css",
        -- "yaml", currently broken
        "json",
        "toml",
        "gitignore",
        "dockerfile",
      },
      sync_install = false,
      highlight = { enable = true },
      indent = { enable = true },  
    })
  end
}
