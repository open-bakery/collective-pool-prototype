import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Token is ERC20 {
  constructor(
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    uint256 supply_
  ) public ERC20(name, ticker) {
    _decimals = decimals_;
    _mint(msg.sender, supply_);
  }
}
