// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract BUSD is ERC20 {
    constructor() ERC20("Binance USD", "BUSD") {
        _mint(msg.sender, 10_000_000 * 1e18);
    }
}
