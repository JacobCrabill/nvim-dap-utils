-- The 'nvim-dap' plugin is required
local dap = require("dap")

-- TODO: Allow these to be unloaded; just remove functionality if they don't exist
local tel_actions_state = require("telescope.actions.state")
local tel_actions = require("telescope.actions")
local telescope = require('telescope')

telescope.load_extension('dap')

-- We'll store the default configs in this table for merging with local configs
local default_configs = { configurations = {}, adapters = {}, }

-- Our Plugin Module Table
local M = {}
M.opts = {}

--- Setup the plugin with user-provided options
function M.setup(opts)
  M.opts = opts or {}

  -- If the user specified a GDB path, set it up as an adapter
  if M.opts.gdb_path ~= nil then
    dap.adapters.gdb = {
      type = "executable",
      command = M.opts.gdb_path,
      args = { "-i", "dap", "-iex", "set auto-load safe-path " .. vim.fn.getcwd() },
      name = 'gdb'
    }
  end

  -- If the user specified an LLDB path, set it up as an adapter
  if M.opts.lldb_path ~= nil then
    dap.adapters.lldb = {
      type = 'executable',
      command = M.opts.lldb_path,
      name = 'lldb',
    }
  end

  -- If a preferred adapter is not specified, use LLDB
  if M.opts.default_adapter == nil then
    M.opts.default_adapter = 'lldb'
  end
end

-- Create a "deep" copy of the given config
-- This allows configs to be added/removed from the new table
-- without modifying the original
function M.copy_dap_config(dap_config)
  local copy = { configurations = {}, adapters = {}, }
  for lang, configs in pairs(dap_config.configurations) do
    copy.configurations[lang] = {}
    for _, config in ipairs(configs) do
      table.insert(copy.configurations[lang], config)
    end
  end
  for name, config in pairs(dap_config.adapters) do
    copy.adapters[name] = config
  end
  return copy
end

-----------------------------------------------------------------------------------------
-- Create a (placeholder) local dap-config.lua file from the current global config
-- Any configurations and adapters placed in this file will be shown in the Telescope
-- picker in addition to those defined in this file
-- See the bottom of this file for a complete example config file
-----------------------------------------------------------------------------------------
function M.create_starter_local_config()
  local conf = vim.fn.getcwd() .. '/dap-config.lua'
  local f = io.open(conf, 'w')
  if f == nil then
    print("ERROR: Could not create file: " .. conf)
    return
  end

  local dap_config = [[--Placehodler config - edit as needed
local dap = {
  configurations = {
    cpp = {
      -- List of config tables here
      -- Each config needs at least a name, type, and program
      -- Optional entries are args, stopOnEntry, and cwd
      -- Example:
      {
        name = 'test',
        type = 'lldb',
        request = 'launch',
        cwd = '${workspaceFolder}',
        program = 'build/bin/foo',
        args = {},
      },
    },
  },
  adapters = {
    -- List of adapter tables here
    -- The name of each table becomes the 'type' used in the config
    -- Example: lldb = { name = 'lldb', type = 'executable', command = '/path/to/lldb-vscode' }
  },
}
return dap
]]
  f:write(dap_config)
  f:close()
end

-----------------------------------------------------------------------------------------
-- Try loading a local "dap-config.lua" file from the current working directory
-- A template file can be created with the ':CreateLocalDAPConfig' command above
-- See the "default" configurations in this file for reference
-----------------------------------------------------------------------------------------
function M.load_local_config()
  local conf = vim.fn.getcwd() .. '/dap-config.lua'
  local f = io.open(conf)
  if f == nil then
    print("No dap-config.lua found in current working directory")
    return
  end
  f:close()

  -- Load the configs from the Lua file and append its configurations to
  -- the global DAP configurations specified here
  print("Loading dap-config file at: " .. conf)
  local dap_config = dofile(conf)
  if dap_config == nil then
    print("ERROR: file " .. conf .. " did not return a config table")
    return
  end

  -- Reset our DAP config table to the defaults
  local defaults = M.copy_dap_config(default_configs)
  dap.configurations = defaults.configurations

  -- Append any new adapters to the table, keeping pre-existing adapters
  for name, adapter in pairs(defaults.adapters) do
    dap.adapters[name] = adapter
  end

  -- Load debug configurations
  if dap_config.configurations ~= nil then
    -- Append the local configurations into the table
    for lang, configs in pairs(dap_config.configurations) do
      if dap.configurations[lang] == nil then
        dap.configurations[lang] = {}
      end
      for _, c in ipairs(configs) do
        table.insert(dap.configurations[lang], c)
      end
    end
  else
    print("No configurations found in file")
  end

  -- Load adapter definitions
  if dap_config.adapters ~= nil then
    -- Append the local adapter configs into the table
    for name, config in pairs(dap_config.adapters) do
      dap.adapters[name] = config
    end
  else
    print("No adapters found in file")
  end
end

-- Show all available DAP configurations
function M.show_dap_configs()
  vim.print(dap.configurations)
end

-- Show all available DAP adapters
function M.show_dap_adapters()
  vim.print(dap.adapters)
end

-- Get a Telescope list of all DAP configurations, including any which are
-- locally defined in a 'dap-config.lua' file.
-- Filter the list by the current filetype.
function M.telescope_dap_configs()
  M.load_local_config()
  return telescope.extensions.dap.configurations({
    language_filter = function(lang)
      return lang == vim.bo.filetype
    end
  })
end

-- Helper Function: Prompt for user input for command arguments
function M.prompt_for_args()
  return vim.split(vim.fn.input('Command Arguments: '), " ")
end

-- Helper Function: Prompt for binary to debug
-- The prompt defaults to the given path, e.g.: "vim.fn.getcwd() .. '/build/bin/'"
function M.prompt_for_binary(default_path)
  return function()
    return vim.fn.input({
      prompt = 'Path to executable: ',
      default = vim.fn.getcwd() .. default_path,
      copmletion ='file',
    })
  end
end

-- Create a .gdbinit file setting all environment variables in the 'env' table
function M.create_gdbinit(env, cwd)
  local gdbinit = cwd or vim.fn.getcwd()
  gdbinit = gdbinit .. "/.gdbinit"
  local f = io.open(gdbinit, 'w')
  if f ~= nil then
    for key, value in pairs(env) do
      f:write('set env ' .. key .. '="' .. value .. '"\n')
    end
    f:close()
  end
end

--- Create a generic DAP config consisting of a name, adapter, and command
--- Prompts for user input if no args are given
function M.create_config(name, adapter, command, args)
  args = args or M.prompt_for_args
  return {
    name = name,
    type = adapter,
    request = 'launch',
    cwd = '${workspaceFolder}',
    stopOnEntry = false,
    program = command,
    args = args,
  }
end

--- Setup Telescope as a binary picker for CMake-based repos
---
--- Show a picker for all executables at <cwd>/build/bin, then run DAP using the default_adapter
--- configuration on the chosen binary.
--- Start a DAP session using the output from the Telescope prompt buffer
function M.start_cmake_dap(prompt_bufnr)
  local cmd = tel_actions_state.get_selected_entry()[1]
  tel_actions.close(prompt_bufnr)
  dap.run(M.create_config("Custom CMake binary", M.opts.default_adapter, cmd))
end

-- Launch a Telescope picker for binary files at <cwd>/build/bin
-- Once selected, launch a DAP configuration using that binary
function M.cmake_binary_picker()
  require("telescope.builtin").find_files({
    find_command = {'find', vim.fn.getcwd() .. '/build/bin/', '-type', 'f', '-executable'},
    attach_mappings = function(_, map)
      map("n", "<cr>", M.start_cmake_dap)
      map("i", "<cr>", M.start_cmake_dap)
      return true
    end,
  })
end

-- Create a Zig binary config
-- Start a DAP session using the output from the Telescope prompt buffer using the default_adapter
function M.start_zig_dap(prompt_bufnr)
  local cmd = tel_actions_state.get_selected_entry()[1]
  tel_actions.close(prompt_bufnr)
  dap.run(M.create_config("Zig exe", M.opts.default_adapter, cmd))
end

-- Launch a Telescope picker for binary files at <cwd>/zig-out/bin/
function M.zig_picker()
  require("telescope.builtin").find_files({
    find_command = {'find', vim.fn.getcwd() .. '/zig-out/bin/', '-type', 'f', '-executable'},
    attach_mappings = function(_, map)
      map("n", "<cr>", M.start_zig_dap)
      map("i", "<cr>", M.start_zig_dap)
      return true
    end,
  })
end

-- Create a generic DAP config using the given name, adapter, and prompt path.
-- Defaults to the default_adapter provided in 'setup()'
-- Prompts for both the binary file and the command-line arguments
-- The optional default_path specifies the prompt path relative to the current working directory
function M.default_dap_config(name, adapter, default_path)
  adapter = adapter or M.opts.default_adapter
  default_path = default_path or ''
  default_path = vim.fn.getcwd() .. '/' .. default_path
  return M.create_config(name, adapter, M.prompt_for_binary(default_path), M.prompt_for_args)
end

-- Create a deep copy of the configurations defined above
-- This allows us to reset the dap config tables to these defaults later
default_configs = M.copy_dap_config(dap)

return M
