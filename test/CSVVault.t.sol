// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {PRBTest} from "prb-test/PRBTest.sol";
import {CSVVault} from "../src/CSVVault.sol";
import {MockVotingToken} from "./mocks/MockVotingToken.sol";
import {MinimalProxyFactory} from "solidstate-solidity/factory/MinimalProxyFactory.sol";

contract CSVVaultTest is PRBTest, MinimalProxyFactory {
    struct vaultInitializeParams {
        string name;
        string symbol;
        address asset;
    }
    MockVotingToken asset;
    vaultInitializeParams defaultParams;
    CSVVault vault;
    CSVVault proxyVault;

    function setUp() public {
        asset = new MockVotingToken();
        vault = new CSVVault();
        defaultParams = vaultInitializeParams(
            "CSVVault",
            "CSV",
            address(asset)
        );
        proxyVault = CSVVault(_deployMinimalProxy(address(vault)));
        proxyVault.initialize(
            defaultParams.name,
            defaultParams.symbol,
            defaultParams.asset
        );
    }

    function testVaultCannotInitialize() public {
        vm.expectRevert("Initializable: contract is already initialized");
        vault.initialize(
            defaultParams.name,
            defaultParams.symbol,
            defaultParams.asset
        );
    }

    function testProxyVaultwasInitialized() public {
        assertEq(proxyVault.name(), defaultParams.name);
        assertEq(proxyVault.symbol(), defaultParams.symbol);
        assertEq(proxyVault.asset(), defaultParams.asset);
    }

    function testVaultwasNotInitialized() public {
        assertEq(vault.name(), "");
        assertEq(vault.symbol(), "");
        assertEq(vault.asset(), address(0));
    }
}
