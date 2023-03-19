import { ethers } from "hardhat";
import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import snapshotGasCost from "@uniswap/snapshot-gas-cost";
import { BigNumber } from "ethers";

describe("Token", () => {
  const wbtcBet = BigNumber.from(10).pow(18); // 1 WBTC
  const usdcBet = BigNumber.from(10).pow(6).pow(2); // 1 million USDC

  async function deployContracts() {
    const [deployer, btcMaxi, btcMini] = await ethers.getSigners();
    const betFactory = await ethers.getContractFactory("TotallySafeBet");
    const betContract = await betFactory.deploy();

    // Deploy two mock tokens
    const tokenFactory = await ethers.getContractFactory("MockERC20");
    const mockBtc = await tokenFactory.deploy("Mock BTC", "MBTC");
    const mockUsdc = await tokenFactory.deploy("Mock ETH", "METH");

    // Give betters the correct amount of tokens
    await mockBtc.mint(btcMini.address, wbtcBet);
    await mockUsdc.mint(btcMaxi.address, usdcBet);

    return { deployer, btcMaxi, btcMini, betContract, mockBtc, mockUsdc };
  }
  describe("Run a bet!", async () => {
    it("Can definitely be trusted with $1 million", async () => {
      const { deployer, btcMaxi, btcMini, betContract, mockBtc, mockUsdc  } = await loadFixture(deployContracts);

      const currentTimestamp = await ethers.provider.getBlock("latest").then((block) => block.timestamp);

      // Initialize contract!
      await betContract.initialize(
        mockBtc.address, 
        mockUsdc.address, 
        wbtcBet,
        usdcBet,
        currentTimestamp
      );

      // Have btcMini bet on usdc
      await mockBtc.connect(btcMini).approve(betContract.address, wbtcBet);
      await betContract.connect(btcMini).makeBet(btcMini.address, false);

      // Have btcMaxi bet on btc
      await mockUsdc.connect(btcMaxi).approve(betContract.address, usdcBet);
      await betContract.connect(btcMaxi).makeBet(btcMaxi.address, true);

      // Fast forward to end of betting period
      await ethers.provider.send("evm_increaseTime", [86400 * 91]);

      // btcMaxi wins of course! Have them claim winnings!
      await betContract.connect(btcMaxi).claimBet([btcMaxi.address], [btcMini.address]);

      expect(await mockBtc.balanceOf(btcMaxi.address)).to.equal(wbtcBet);  // btc maxi should have winnings
    });
  });
});
