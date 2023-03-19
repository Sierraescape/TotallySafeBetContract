// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice A mintable ERC20
 */
contract TotallySafeBet {
    IERC20 public wbtc;
    IERC20 public usdc;

    uint256 public betStart;
    uint256 public constant betDuration = 90 days;

    mapping(address => bool) public bets;   // address(user) => bool(willWbtcWin)

    uint256 public wbtcBetAmount;
    uint256 public usdcBetAmount;

    // Set up ERC20s and bet period
    function initialize(IERC20 _wbtc, IERC20 _usdc, uint256 _wbtcBetAmount, uint256 _usdcBetAmount, uint256 _betStart) public {
        wbtc = _wbtc;
        usdc = _usdc;
        wbtcBetAmount = _wbtcBetAmount;
        usdcBetAmount = _usdcBetAmount;
        betStart = _betStart;
    }

    function makeBet(address better, bool _willWbtcWin) public {
        require (block.timestamp < betStart + betDuration, "Bet is closed");

        // Bet is still open
        bets[better] = _willWbtcWin;

        if (_willWbtcWin) {
            // Check that they've approved, we don't want anyone cheating!
            require(usdc.allowance(better, address(this)) >= usdcBetAmount, "Please approve USDC bet amount");
        } else {
            require(wbtc.allowance(better, address(this)) >= wbtcBetAmount, "Please approve WBTC bet amount");
            bets[better] = _willWbtcWin;
        }
    }

    // Claim bet for all winners at once! Batch claiming is really helpful for gas efficiency.
    // Also, little-known fact, you can use calldata for arrays to save even more gas!
    function claimBet(address[] calldata winners, address[] calldata losers) public {
        bool _wbtcWon = _checkWinner();
        IERC20 _loserToken = _wbtcWon ? wbtc : usdc;

        uint256 totalWinnings;  // No need to initialize, this saves gas!
        for (uint256 i = 0; i < losers.length; i++) {
            // Check that this is a loser
            require(bets[losers[i]] != _wbtcWon, "This is not a loser");

            uint256 forfeitAmount = _loserToken == wbtc ? wbtcBetAmount : usdcBetAmount;

            // Claim all losers' bets
            _loserToken.transferFrom(losers[i], address(this), forfeitAmount);
            totalWinnings += forfeitAmount;
        }

        for (uint256 i = 0; i < winners.length; i++) {
            // Send funds to winners! But first make sure they really are winners.
            require(bets[winners[i]] == _wbtcWon, "This is not a winner");

            _loserToken.transfer(winners[i], totalWinnings / winners.length);
            // Congrats winners!
        }
    }

    // If the value of WBTC is higher than $1 million, return true
    function _checkWinner() internal view returns (bool) {
        uint256 _wbtcValue = wbtc.totalSupply();
        return _wbtcValue > 1_000_000;
    }
}
