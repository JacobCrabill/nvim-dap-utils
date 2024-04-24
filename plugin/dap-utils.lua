local dap_utils = require('dap-utils')

-- Expose relevant functions as user commands
vim.api.nvim_create_user_command('DebugCMake', dap_utils.cmake_binary_picker, {})
vim.api.nvim_create_user_command('DebugZig', dap_utils.zig_picker, {})
vim.api.nvim_create_user_command("LoadDAPConfig", dap_utils.load_local_config, {})
vim.api.nvim_create_user_command("ShowDAPConfigs", dap_utils.show_dap_configs, {})
vim.api.nvim_create_user_command("ShowDAPAdapters", dap_utils.show_dap_adapters, {})
