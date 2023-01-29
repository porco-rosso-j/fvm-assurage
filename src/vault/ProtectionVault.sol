// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.7;

import {ERC4626, ERC20} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IProtectionVault} from "../interfaces/IProtectionVault.sol";
import {IAssurageManager} from "../interfaces/IAssurageManager.sol";
import {IWFIL} from "../interfaces/IWFIL.sol";
import {IMinerActor} from "../interfaces/IMinerActor.sol";

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
        address _asset,
        address _assurageManager,
        address _migrationAdmin,
        uint256 _bootstrapMint,
        uint _initialSupply,
        string memory _name,
        string memory _symbol
    ) ERC4626(ERC20(_asset), _name, _symbol) {
        require(_asset != address(0), "Invalid Owner");
        require((assurageManager =_assurageManager) != address(0), "Invalid Owner");

        if (_initialSupply != 0) {
            _mint(_migrationAdmin, _initialSupply);
        }

        BOOTSTRAP_MINT = _bootstrapMint;

        SafeTransferLib.safeApprove(ERC20(_asset), _assurageManager, type(uint256).max);
    }

    // ---------------------------------- //
    // Vault Configuretion
    // ---------------------------------- //
    function setAssurageManager(address _assurageManager) public override onlyAssurageManager {
        require(_assurageManager != address(0), "Invalid Address");
        assurageManager = _assurageManager;
    }

    // ---------------------------------- //
    // Operations for Insurers
    // ---------------------------------- //

    function deposit(uint256 assets, address receiver) public virtual override nonReentrant returns (uint256 shares) {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        // afterDeposit(assets, shares);
    }

    function depositWithPermit(
        uint256 assets,
        address receiver,
        uint256 deadline,
        uint8   v,
        bytes32 r,
        bytes32 s
    )
        external override nonReentrant returns (uint256 shares)
    {
        asset.permit(msg.sender, address(this), assets, deadline, v, r, s);
        shares = deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public virtual override nonReentrant returns (uint256 assets) {
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        // afterDeposit(assets, shares);
    }

    function mintWithPermit(
        uint256 shares,
        address receiver,
        uint256 maxAssets,
        uint256 deadline,
        uint8   v,
        bytes32 r,
        bytes32 s
    )
        external override nonReentrant returns (uint256 assets)
    {
        require((assets = previewMint(shares)) <= maxAssets, "P:MWP:INSUFFICIENT_PERMIT");

        asset.permit(msg.sender, address(this), maxAssets, deadline, v, r, s);
        assets = mint(shares, receiver);
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

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        // beforeWithdraw(assets, shares);

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

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        // beforeWithdraw(assets, shares);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }
    // ---------------------------------- //
    // Operatons for Insured ( Miners )
    // ---------------------------------- // 

    function sendClaimedFIL(address _miner, uint _compensation) external override payable nonReentrant onlyAssurageManager {
       IWFIL(address(asset)).withdraw(_compensation);
       SafeTransferLib.safeTransferETH(_miner, _compensation);
    }

    // ---------------------------------- //
    // ERC4626 Implementations ( Miners )
    // ---------------------------------- // 

    function totalAssets() public view virtual override returns (uint256) {
        return IAssurageManager(assurageManager).totalAssets();
    }

    receive() external payable {
        IWFIL(address(asset)).deposit{ value:msg.value }();
        deposit(msg.value, msg.sender);
    }
}

