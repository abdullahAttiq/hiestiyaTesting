// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20 {
    constructor() ERC20("TokenName", "TKN") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}