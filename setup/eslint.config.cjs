const globals = require("globals");
const js = require("@eslint/js");

module.exports = [
  {
    languageOptions: {
      globals: {
        ...globals.node,
      },
    },
    ...js.configs.recommended,
  }
];
