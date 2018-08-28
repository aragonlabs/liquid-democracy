pragma solidity 0.4.18;


import "../LiquidDemocracy.sol";
import "@aragon/os/contracts/apps/UnsafeAragonApp.sol";

contract UnsafeACLAllowAll {
  modifier auth(bytes32 role) {
    _; // allow all
  }

  modifier authP(bytes32 role, uint256[] params) {
    _; // allow all
  }
}

contract UnsafeLiquidDemocracy is UnsafeAragonApp, UnsafeACLAllowAll, LiquidDemocracy {
}
