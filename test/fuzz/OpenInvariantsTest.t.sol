// 1. the total supply of DSC should alwasys be less than the total value of collateral
// 2. getter functions should never revert (evergreen)

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract OpenInvariantsTest is StdInvariant, Test {
    DSCEngine dscEngine;
    HelperConfig helperConfig;
    DeployDSC deployDSC;
    DecentralizedStableCoin dsc;
    address weth;
    address wbtc;

    function setUp() public {
        // setup state
        deployDSC = new DeployDSC();
        (dsc, dscEngine, helperConfig) = deployDSC.run();
        (,, weth, wbtc,) = helperConfig.activeNetworkConfig();
        Handler handler = new Handler(dscEngine, dsc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsc));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dsc));

        uint256 wethTotalValue = dscEngine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcTotalValue = dscEngine.getUsdValue(wbtc, totalWbtcDeposited);
        assert(wethTotalValue + wbtcTotalValue >= totalSupply);
    }

    function invariant_getterFunctionsShouldNeverRevert() public view {
        dscEngine.getCollateraltokens();
        dscEngine.getUsdValue(weth, 1e18);
        dscEngine.getUsdValue(wbtc, 1e18);
    }
}
