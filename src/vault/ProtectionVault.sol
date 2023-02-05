// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.17;

import {ERC4626, ERC20} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IProtectionVault} from "../interfaces/IProtectionVault.sol";
import {IAssurageManager, AssurageManagerStorage} from "./AssurageManager.sol";
import {IWFIL} from "../interfaces/IWFIL.sol";

contract ProtectionVault is IProtectionVault, ERC4626 {
    using SafeTransferLib for ERC20;

    uint256 public immutable BOOTSTRAP_MINT;

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
        address _assurageManager,
        address _asset,
        address _migrationAdmin,
        uint256 _bootstrapMint,
        uint256 _initialSupply,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC4626(ERC20(_asset), _name, _symbol, _decimals) {
        require(_asset != address(0), "Invalid Owner");
        require(
            (assurageManager = _assurageManager) != address(0),
            "Invalid Owner"
        );

        if (_initialSupply != 0) {
            _mint(_migrationAdmin, _initialSupply);
        }

        BOOTSTRAP_MINT = _bootstrapMint;
        IWFIL(_asset).approve(assurageManager, type(uint256).max);
    }

    // ---------------------------------- //
    // Vault Configuretion
    // ---------------------------------- //
    function setAssurageManager(address _assurageManager)
        public
        override
        onlyAssurageManager
    {
        require(_assurageManager != address(0), "Invalid Address");
        assurageManager = _assurageManager;
    }

    function setApproval() public override {
        AssurageManagerStorage aStrorage = AssurageManagerStorage(
            assurageManager
        );
        require(aStrorage.assurageDelegate() == msg.sender, "INVALID_CALLER");
        asset.safeApprove(assurageManager, type(uint256).max);
    }

    // ---------------------------------- //
    // Operations for Insurers
    // ---------------------------------- //

    function deposit(uint256 assets, address receiver)
        public
        virtual
        override
        nonReentrant
        returns (uint256 shares)
    {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        // afterDeposit(assets, shares);
    }

    function mint(uint256 shares, address receiver)
        public
        virtual
        override
        nonReentrant
        returns (uint256 assets)
    {
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    // TODO: withdrawal interval
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override nonReentrant returns (uint256 shares) {
        shares = previewWithdraw(assets); // No need to check for rounding error, previewWithdraw rounds up.

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max)
                allowance[owner][msg.sender] = allowed - shares;
        }

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    // TODO: withdrawal interval
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override nonReentrant returns (uint256 assets) {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max)
                allowance[owner][msg.sender] = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    function withdrawFromAssurageManager(uint256 _amount)
        external
        onlyAssurageManager
    {
        IWFIL(address(asset)).transfer(assurageManager, _amount);
    }

    // ---------------------------------- //
    // ERC4626 Implementations ( Miners )
    // ---------------------------------- //

    function totalAssets() public view virtual override returns (uint256) {
        return IAssurageManager(assurageManager).totalAssets();
    }

    // receive() external payable {
    //     IWFIL(address(asset)).deposit{value: msg.value}();
    //     deposit(msg.value, msg.sender);
    // }
}
