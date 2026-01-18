// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// BEP-20 Token (BSC Compatible)
contract IcingCoin is ERC20, Ownable {
    uint256 private constant TOTAL_SUPPLY = 2_000_000_000 * 10**18;
    
    uint256 public burnFee = 100;
    uint256 public reflectionFee = 100;
    
    uint256 public maxTxAmount = TOTAL_SUPPLY / 200;
    uint256 public maxWalletAmount = TOTAL_SUPPLY / 50;
    
    mapping(address => bool) public isExcludedFromFees;
    
    uint256 public totalReflectionCollected;
    bool public tradingEnabled;
    
    event TradingEnabled(uint256 timestamp);
    event TokensBurned(address indexed from, uint256 amount);
    
    constructor() ERC20("Icing Coin", "ICG") Ownable(msg.sender) {
        isExcludedFromFees[msg.sender] = true;
        isExcludedFromFees[address(this)] = true;
        
        _mint(msg.sender, TOTAL_SUPPLY);
    }
    
    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "Trading already enabled");
        tradingEnabled = true;
        emit TradingEnabled(block.timestamp);
    }
    
    function _update(address from, address to, uint256 amount) internal override {
        // Skip all checks if minting (from == address(0))
        if (from == address(0)) {
            super._update(from, to, amount);
            return;
        }
        
        // Check trading enabled
        if (from != owner() && to != owner()) {
            require(tradingEnabled, "Trading not enabled");
        }
        
        // Check limits only if fees apply
        if (!isExcludedFromFees[from] && !isExcludedFromFees[to]) {
            require(amount <= maxTxAmount, "Exceeds max transaction");
            
            if (to != address(this) && to != address(0)) {
                require(balanceOf(to) + amount <= maxWalletAmount, "Exceeds max wallet");
            }
        }
        
        // Calculate fees
        bool takeFee = !isExcludedFromFees[from] && !isExcludedFromFees[to];
        
        if (takeFee && tradingEnabled) {
            uint256 burnAmount = (amount * burnFee) / 10000;
            uint256 reflectionAmount = (amount * reflectionFee) / 10000;
            uint256 netAmount = amount - burnAmount - reflectionAmount;
            
            if (burnAmount > 0) {
                super._update(from, address(0), burnAmount);
                emit TokensBurned(from, burnAmount);
            }
            
            if (reflectionAmount > 0) {
                super._update(from, address(this), reflectionAmount);
                totalReflectionCollected += reflectionAmount;
            }
            
            super._update(from, to, netAmount);
        } else {
            super._update(from, to, amount);
        }
    }
    
    function excludeFromFees(address account, bool excluded) external onlyOwner {
        isExcludedFromFees[account] = excluded;
    }
    
    function updateFees(uint256 _burnFee, uint256 _reflectionFee) external onlyOwner {
        require(_burnFee + _reflectionFee <= 1000, "Fees too high");
        burnFee = _burnFee;
        reflectionFee = _reflectionFee;
    }
    
    function withdrawReflections(address to) external onlyOwner {
        uint256 amount = balanceOf(address(this));
        require(amount > 0, "Nothing to withdraw");
        _transfer(address(this), to, amount);
    }
    
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }
    
    // BEP-20 specific: Returns the token owner (for BSC compatibility)
    function getOwner() external view returns (address) {
        return owner();
    }
}
