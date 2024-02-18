local util = require("lspconfig.util")

local function root_dir(filename)
  return util.find_git_ancestor(filename)
end

return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@type lspconfig.options
      servers = {
        jsonls = {
          settings = {
            json = {
              format = {
                enable = false,
              },
            },
          },
        },
      },
      ---@type table<string, fun(server:string, opts:_.lspconfig.options):boolean?>
      setup = {
        eslint = function(_, opts)
          opts.root_dir = root_dir

          require("lazyvim.util").on_attach(function(client)
            if client.name == "eslint" then
              client.server_capabilities.documentFormattingProvider = true
            elseif client.name == "tsserver" then
              client.server_capabilities.documentFormattingProvider = false
            end
          end)
        end,
        tsserver = function(_, opts)
          opts.root_dir = root_dir
        end,
      },
    },
  },
}
