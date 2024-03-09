// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    address[] public priceFeeds;
    address[] public tokens;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc,) =
            helperConfig.activeNetworkConfig();
        priceFeeds = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        tokens = [weth, wbtc];
        vm.startBroadcast();
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine dscEngine = new DSCEngine(tokens, priceFeeds, address(dsc));

        dsc.transferOwnership(address(dscEngine));

        vm.stopBroadcast();
        return (dsc, dscEngine, helperConfig);
    }
}
