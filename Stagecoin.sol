// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract StageCoin is Initializable, ERC20Burnable, ERC20Pausable, Ownable, UUPSUpgradeable {
    uint256 private constant TOTAL_SUPPLY = 2_000_000_000 * 10 ** 18;
    uint256 public constant MAX_TX_PERCENT = 1; // 1% max transaction
    uint256 public constant BURN_FEE = 1; // 1%
    uint256 public constant REFLECTION_FEE = 1; // 1%
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcludedFromMaxTx;
    mapping(address => uint256) private _reflectionBalance;
    uint256 private _totalReflection;
    uint256 private _totalReflected;

    event ReflectionDistributed(uint256 amount);
    event FeesTaken(uint256 burnAmount, uint256 reflectionAmount);

    constructor() initializer {}

    function initialize(address initialOwner) public initializer {
        __ERC20_init("Stage Coin", "STG");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        _mint(initialOwner, TOTAL_SUPPLY);
        _isExcludedFromFee[initialOwner] = true;
        _isExcludedFromMaxTx[initialOwner] = true;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        if (paused()) revert("Token transfer while paused");

        if (!_isExcludedFromMaxTx[from] && !_isExcludedFromMaxTx[to]) {
            uint256 maxTxAmount = (TOTAL_SUPPLY * MAX_TX_PERCENT) / 100;
            require(value <= maxTxAmount, "Transfer exceeds max tx amount");
        }

        if (!_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            uint256 burnAmount = (value * BURN_FEE) / 100;
            uint256 reflectionAmount = (value * REFLECTION_FEE) / 100;
            uint256 totalFee = burnAmount + reflectionAmount;
            uint256 sendAmount = value - totalFee;

            super._update(from, address(this), reflectionAmount);
            super._burn(from, burnAmount);
            super._update(from, to, sendAmount);

            _distributeReflection(reflectionAmount);

            emit FeesTaken(burnAmount, reflectionAmount);
        } else {
            super._update(from, to, value);
        }
    }

    function _distributeReflection(uint256 reflectionAmount) private {
        uint256 supply = totalSupply();
        if (supply == 0) return;
        _totalReflected += reflectionAmount;
        _totalReflection += reflectionAmount;
        emit ReflectionDistributed(reflectionAmount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function excludeFromFee(address account, bool excluded) public onlyOwner {
        _isExcludedFromFee[account] = excluded;
    }

    function excludeFromMaxTx(address account, bool excluded) public onlyOwner {
        _isExcludedFromMaxTx[account] = excluded;
    }

    function totalReflection() external view returns (uint256) {
        return _totalReflection;
    }

    function totalReflected() external view returns (uint256) {
        return _totalReflected;
    }

    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function isExcludedFromMaxTx(address account) external view returns (bool) {
        return _isExcludedFromMaxTx[account];
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
