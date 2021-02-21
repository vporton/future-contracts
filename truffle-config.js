const HDWalletProvider = require("@truffle/hdwallet-provider");

const config = {
  networks: {
    mainnet: {
      provider: function() {
        return new HDWalletProvider({
          privateKeys: [process.env.TESTNET_PRIVATE_KEY],
          providerOrUrl:
            "https://mainnet.infura.io/v3/" + process.env.INFURA_KEY
        });
      },
      host: "localhost",
      port: 8545,
      network_id: "1"
    },
    ropsten: {
      provider: function() {
        return new HDWalletProvider({
          privateKeys: [process.env.TESTNET_PRIVATE_KEY],
          providerOrUrl:
            "https://ropsten.infura.io/v3/" + process.env.INFURA_KEY
        });
      },
      host: "localhost",
      port: 8545,
      network_id: "3"
    },
    kovan: {
      provider: function() {
        return new HDWalletProvider({
          privateKeys: [process.env.TESTNET_PRIVATE_KEY],
          providerOrUrl: "https://kovan.infura.io/v3/" + process.env.INFURA_KEY
        });
      },
      host: "localhost",
      port: 8545,
      network_id: "42"
    },
    rinkeby: {
      provider: function() {
        return new HDWalletProvider({
          privateKeys: [process.env.TESTNET_PRIVATE_KEY],
          providerOrUrl:
            "https://rinkeby.infura.io/v3/" + process.env.INFURA_KEY
        });
      },
      host: "localhost",
      port: 8545,
      network_id: "4"
    },
    bsc: {
      provider: function() {
        return new HDWalletProvider({
          privateKeys: [process.env.MAINNET_PRIVATE_KEY],
          providerOrUrl: `https://bsc-dataseed1.binance.org`
        });
      },
      host: "localhost",
      port: 8545,
      network_id: "56"
    },
    bsctestnet: {
      provider: function() {
        return new HDWalletProvider({
          privateKeys: [process.env.TESTNET_PRIVATE_KEY],
          providerOrUrl: `https://data-seed-prebsc-1-s1.binance.org:8545`
        });
      },
      host: "localhost",
      port: 8545,
      network_id: "97"
    },
    mumbai: {
      provider: function() {
        return new HDWalletProvider({
          privateKeys: [process.env.TESTNET_PRIVATE_KEY],
          providerOrUrl:
            "https://rpc-mumbai.maticvigil.com/v1/" + process.env.MATIC_KEY
        });
      },
      accounts: process.env.TESTNET_PRIVATE_KEY
        ? [process.env.TESTNET_PRIVATE_KEY]
        : [],
      gasPrice: 1000000000, // 1 Gwei
      network_id: 80001
    },
    xdai: {
      host: "localhost",
      port: 8545,
      network_id: "100"
    },
    local: {
      host: "localhost",
      port: 8545,
      network_id: "*"
    }
  },
  mocha: {
    enableTimeouts: false,
    grep: process.env.TEST_GREP,
    reporter: "eth-gas-reporter",
    reporterOptions: {
      currency: "USD",
      excludeContracts: ["Migrations"]
    }
  },
  compilers: {
    solc: {
      version: "0.7.6",
      settings: {
        optimizer: {
          enabled: true,
          runs: 1000000
        }
      }
    }
  }
};

try {
  require("chai/register-should");
  require("chai").use(require("chai-as-promised"));
} catch (e) {
  // eslint-disable-next-line no-console
  console.log("Skip setting up testing utilities");
}

try {
  const _ = require("lodash");
  _.merge(config, require("./truffle-local"));
} catch (e) {
  if (e.code === "MODULE_NOT_FOUND" && e.message.includes("truffle-local")) {
    // eslint-disable-next-line no-console
    console.log("No local truffle config found. Using all defaults...");
  } else {
    // eslint-disable-next-line no-console
    console.warn("Tried processing local config but got error:", e);
  }
}

module.exports = config;
