// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "solmate/mixins/ERC4626.sol";
import "../interfaces/IProtectionVault.sol";
import "../interfaces/IWFIL.sol";
import "../FilecoinSolidityAPI/MinerActor.sol";

contract ProtectionVault is IProtectionVault, ERC4626 {

    address public owner;
    address public assurageManager;
    uint256 private _locked = 1;

    modifier onlyAssurageManager() {
        require(
            msg.sender == assurageManager,
            "Only callable by AssurageManager"
        );
    
        _;
    }

    modifier nonReentrant() {
        require(_locked == 1, "P:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    constructor(
        IERC20 _asset,
        address _assurageManager,
        address _initialSupply,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset) ERC20(_symbol, _symbol) {
        require(_asset != address(0), "Invalid Owner");
        require((assurageManager =_assurageManager) != address(0), "Invalid Owner");

        if (_initialSupply != 0) {
            deposit(_initialSupply, _delegate);
            // depositWithPermit();
        }
    }

    // ---------------------------------- //
    // Vault Configuretion
    // ---------------------------------- //
    function setAssurageManager(address _assurageManager) public onlyAssurageManager {
        require(_assurageManager != address(0), "Invalid Address");
        assurageManager = _assurageManager;
    }

    // ---------------------------------- //
    // Operations for Insurers
    // ---------------------------------- //

    function deposit(uint _amount, address _insurer) public override nonReentrant returns (uint) {
        require(_amount <= maxDeposit(_insurer), "ERC4626: deposit more than max");
        require(_amount != 0, "Amount Zero");

        uint256 shares = previewDeposit(_amount);
        _deposit(_msgSender(), _insurer, _amount, shares);

        emit Deposit(_insurer, address(this), _amount, shares);
        return shares;
    }

    function mint(uint _shares, address _insurer) public override nonReentrant returns (uint) {
        require(_shares <= maxMint(_insurer), "ERC4626: mint more than max");
        require(_amount != 0, "Amount Zero");

        uint amount = previewMint(_shares);
        _deposit(_msgSender(), _insurer, amount, _shares);

        emit Deposit(_insurer, address(this), amount, _shares);
        return amount;
    }

    function withdraw(uint _amount, address _receiver, address _insurer) public override nonReentrant returns (uint) {
        require(_amount <= maxWithdraw(_insurer), "ERC4626: withdraw more than max");
        require(_amount != 0, "Amount Zero");

        uint shares = previewWithdraw(_amount);
        _withdraw(_msgSender(), _insurer, owner, _amount, shares);

        emit Withdraw(_msgSender(), _receiver, _insurer, _amount, shares);
        return shares;
    }

    function redeem(uint _shares, address _receiver, address _insurer) public override nonReentrant returns(uint) {
        require(_shares <= maxRedeem(_insurer), "ERC4626: redeem more than max");
        require(_amount != 0, "Amount Zero");

        uint256 amount = previewRedeem(_shares);
        _withdraw(_msgSender(), _receiver, owner, amount, _shares);

        emit Withdraw(_msgSender(), _receiver, _insurer, amount, _shares);
        return amount;
    }

    // ---------------------------------- //
    // Operatons for Insured ( Miners )
    // ---------------------------------- // 

    function payPremium(address _miner, uint _premium) external override nonReentrant onlyAssurageManager {
        require(_premium != 0, "Invalid amount");

        MinerActor minerInstance = MinerActor(_miner);

        uint balance = minerInstance.mockGetAvailableBalance();
        require(balance >= _premium, "Insufficient Balance");

        minerInstance.mockWithdrawBalance(address(this), _premium);
        IWFIL(asset()).deposit{ value:_premium }();

    }

    function sendClaimETH(address _miner, uint _compensation) external override payable nonReentrant onlyAssurageManager {
       require(_compensation <= totalAssets(), "Insufficient Vault Balance");
       IWFIL(asset()).withdraw(_compensation);

       assembly {
            if iszero(call(gas(), _miner, _compensation, 0, 0, 0, 0)) {
                mstore(0x00, 0xb12d13eb)
                revert(0x1c, 0x04)
            }
        }

    }

    receive() external payable {
        IWFIL(asset()).deposit{ value:msg.value }();
        deposit(msg.value, msg.sender);
    }
}
