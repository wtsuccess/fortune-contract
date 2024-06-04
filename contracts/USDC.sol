// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20 {
    constructor() ERC20("USDC Token", "USDC") {}

    function mint(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }
}
