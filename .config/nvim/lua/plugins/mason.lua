return {
    "williamboman/mason.nvim",
    lazy = true,
    opts = {
        ui = {
            icons = {
                package_installed   = "✓",
                package_pending     = "➜",
                package_uninstalled = "✗",
            },
        },
    },
}
