// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title Decentralized Stable Coin Engine
 * @author Manaan Ansari
 * the system that governs the decentralized stable coin and maintains a 1:1 peg with the USD
 * this stable coin has the properties of being algorithmic, collateralized by exogenous assets (ETH, BTC)
 * its similar to DAI if it had no governance no fees and was only backed by wETH and wBTC
 * our DSC system should be always overcollateralized
 * @notice this contract is the core od DSC system.
 */

contract DSCEngine is ReentrancyGuard {
    // errors
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesLengthMismatch();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor();
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    // State variables
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% collateralization needed
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant LIQUIDATION_BONUS_PRECISION = 100;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256) private s_dscMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    // Events
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    // Modifiers

    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address _tokenAddress) {
        // check if token is allowed
        if (s_priceFeeds[_tokenAddress] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    // Functions

    constructor(address[] memory _tokenAddresses, address[] memory _priceFeedAddresses, address _dscAddress) {
        if (_tokenAddresses.length != _priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesLengthMismatch();
        }
        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            s_priceFeeds[_tokenAddresses[i]] = _priceFeedAddresses[i];
        }
        i_dsc = DecentralizedStableCoin(_dscAddress);
        s_collateralTokens = _tokenAddresses;
    }

    // external functions

    /*
     * @notice follows CEI (check effects interactions) pattern
     * @param _tokenCollateralAddress 
     * @param _amountCollateral 
     * @param _amountDscToMint 
     */
    function depositCollateralAndMintDsc(
        address _tokenCollateralAddress,
        uint256 _amountCollateral,
        uint256 _amountDscToMint
    ) external {
        depositColateral(_tokenCollateralAddress, _amountCollateral);
        mintDsc(_amountDscToMint);
    }

    /*
     * @notice follows CEI (check effects interactions) pattern
     * @param _tokenCollateralAddress 
     * @param _amount 
     */
    function depositColateral(address _tokenCollateralAddress, uint256 _amount)
        public
        moreThanZero(_amount)
        isAllowedToken(_tokenCollateralAddress)
        nonReentrant
    {
        // deposit collateral
        s_collateralDeposited[msg.sender][_tokenCollateralAddress] += _amount;

        emit CollateralDeposited(msg.sender, _tokenCollateralAddress, _amount);

        bool success = IERC20(_tokenCollateralAddress).transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /*
     * @notice follows CEI (check effects interactions) pattern
     * @param _tokenCollateral 
     * @param _amountCollateral 
     * @param _amountDSCToBurn 
     * @notice this function burns DSC and redeems underlaying collateral in one transaction 
     * @notice this is knda the main function
     */

    function redeemCollateralForDsc(address _tokenCollateral, uint256 _amountCollateral, uint256 _amountDSCToBurn)
        external
    {
        // redeem collateral
        // this is the main function
        // we redeeem the collateral and burn the DSC
        burnDsc(_amountDSCToBurn);
        redeemCollateral(_tokenCollateral, _amountCollateral);
        // redeem colateral already checks for health factor
    }

    //inorder to redeem colateral
    // 1. healith factor must be greater than 1 after removing colateral
    // DRY: Don't Repeat Yourself
    function redeemCollateral(address _collateralAddress, uint256 _amount) public moreThanZero(_amount) nonReentrant {
        _redeemCollateral(_collateralAddress, _amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @notice follows CEI (check effects interactions) pattern
     * @param _amountDscToMint  
     * @notice they must have more collateral than the minimum threshold
     */
    function mintDsc(uint256 _amountDscToMint) public {
        // mint DSC
        s_dscMinted[msg.sender] += _amountDscToMint;
        //if they minted too much
        _revertIfHealthFactorIsBroken(msg.sender);
        bool success = i_dsc.mint(msg.sender, _amountDscToMint);
        if (!success) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDsc(uint256 _amount) public moreThanZero(_amount) {
        _burnDsc(_amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // probably we dont need this
    }

    // if someone is almost under collateralized, we will pay you to liquidate them
    /*
     * 
     * @param _tokenCollateral 
     * @param _user 
     * @param debtToCover 
     * @notice you can partially liquidate the user
     * you will get the liquidation bonus for taking the users funds
     * @notice IMP : a known bug would be if the protocol were 100% or less colateralized the we wouldnt be able to incentive the liquidator
     * for example if the price drops before anyone could be liquidated
     */
    function liquidate(address _tokenCollateral, address _user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        // check if helth factor is broken
        uint256 startingHealthFactor = _healthFactor(_user);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }
        // we want to burn their dsc "debt"
        // and take their collateral
        // bad user : 140$ ETH and minted 100 DSC
        // 100$ DSC == ?? ETH
        // 0.05ETH
        uint256 collateralToTake = gettokenAmountFromUsd(_tokenCollateral, debtToCover);
        // and give them a bonus 10%
        // so we are giving the liquidator 110$ worth of ETH for 100DSC
        //0.055ETH

        uint256 bonus = (collateralToTake * LIQUIDATION_BONUS) / LIQUIDATION_BONUS_PRECISION;

        uint256 totalCollateralToRedeem = collateralToTake + bonus;
        _redeemCollateral(_tokenCollateral, totalCollateralToRedeem, _user, msg.sender);
        _burnDsc(debtToCover, _user, msg.sender);

        uint256 endingHealthFactor = _healthFactor(_user);

        if (endingHealthFactor <= startingHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view returns (uint256) {
        // get health factor
    }

    // private & internal functions

    function _burnDsc(uint256 _amount, address _onBehalfOf, address dscFrom) internal {
        // burn DSC
        s_dscMinted[_onBehalfOf] -= _amount;
        bool success = i_dsc.transferFrom(dscFrom, address(this), _amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(_amount);
    }

    function _redeemCollateral(address _collateralAddress, uint256 _amount, address _from, address _to) internal {
        // redeem collateral
        s_collateralDeposited[_from][_collateralAddress] -= _amount;
        emit CollateralRedeemed(_from, _to, _collateralAddress, _amount);
        bool success = IERC20(_collateralAddress).transfer(_to, _amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address _user)
        internal
        view
        returns (uint256 totalDscMinted, uint256 totalCollateralDeposited)
    {
        // get account information
        totalDscMinted = s_dscMinted[_user];
        totalCollateralDeposited = getAccountCollateralValue(_user);
    }

    /*
     * returns how close to liquidation a user is
     * @notice if the health factor is less than 1, then they can be liquidated
     */
    function _healthFactor(address _user) internal view returns (uint256) {
        // calculate health factor
        (uint256 totalDscMinted, uint256 totalCollateralDeposited) = _getAccountInformation(_user);
        if (totalDscMinted == 0) {
            return type(uint256).max;
        }
        uint256 collateralAdjustedForThreshold =
            (totalCollateralDeposited * LIQUIDATION_PRECISION) / LIQUIDATION_THRESHOLD;

        // 100$ , 200$
        // 200 * 50 / 100 = 100 which is fine cz 100 is only minted

        // 100$ , 100$
        // 100 * 50 / 100 = 50 which is not fine cz 100 is minted

        // now
        // 100/100 = 1 which is fine (1st example)
        // 50/100 = 0.5 which is less than 1 the user can be liquidated (2nd example)
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address _user) internal view {
        // check health factor (do they have enough collateral?)
        // revert if they don't
        uint256 healthFactor = _healthFactor(_user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor();
        }
    }

    // public external view & pure functions

    function getAccountCollateralValue(address _user) public view returns (uint256) {
        // get account collateral value
        uint256 totalCollateralValue = 0;
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            totalCollateralValue +=
                getUsdValue(s_collateralTokens[i], s_collateralDeposited[_user][s_collateralTokens[i]]);
        }
        return totalCollateralValue;
    }

    function getUsdValue(address _tokenAddress, uint256 _amount) public view returns (uint256) {
        // get USD value
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[_tokenAddress]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        // 1 Eth = 1000 USD
        // the return value will be 1000 * 1e8
        // so what will do is we will multiply by 1e10 and the amount
        // note that amount also has 1e18 decimals
        // so that we can get the value in 1e18
        // and then we will divide by 1e18
        // so its like (1000 * 1e8 * 1e10 * amount18dec ) / 1e18
        // so the 1e18 will cancel out
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * _amount) / PRECISION;
    }

    function gettokenAmountFromUsd(address _tokenAddress, uint256 _usdAmountInWei) public view returns (uint256) {
        // get token amount from USD
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[_tokenAddress]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (_usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountInformation(address _user) external view returns (uint256, uint256) {
        // get account information
        return _getAccountInformation(_user);
    }

    function getCollateraltokens() external view returns (address[] memory) {
        // get collateral tokens
        return s_collateralTokens;
    }

    function getCollateralBalanceOfUser(address _user, address _token) external view returns (uint256) {
        // get collateral balance of user
        return s_collateralDeposited[_user][_token];
    }
}
