// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDCE is ERC20 {
    constructor() ERC20("USDCE Token", "USDCE") {}

    function mint(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }

    function burn(uint256 _amount) public {
        _burn(msg.sender, _amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
