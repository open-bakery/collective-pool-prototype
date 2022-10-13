module.exports = {
  resources: ['http://127.0.0.1:8545'],
  validateStatus: (status) => status >= 200 && status < 500,
};
