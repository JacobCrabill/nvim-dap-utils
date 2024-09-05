-- Expose relevant functions as user commands
vim.api.nvim_create_user_command('DebugCMake', function() require('dap_utils').cmake_binary_picker() end, {})
vim.api.nvim_create_user_command('DebugZig', function() require('dap_utils').zig_picker() end, {})
vim.api.nvim_create_user_command("LoadDAPConfig", function() require('dap_utils').load_local_config() end, {})
vim.api.nvim_create_user_command("ShowDAPConfigs", function() require('dap_utils').show_dap_configs() end, {})
vim.api.nvim_create_user_command("ShowDAPAdapters", function() require('dap_utils').show_dap_adapters() end, {})
vim.api.nvim_create_user_command("CreateLocalDAPConfig", function() require('dap_utils').create_starter_local_config() end, {})
