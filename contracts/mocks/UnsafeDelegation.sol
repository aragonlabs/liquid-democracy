pragma solidity 0.4.18;


import "../Delegation.sol";
import "@aragon/os/contracts/apps/UnsafeAragonApp.sol";

contract UnsafeDelegation is UnsafeAragonApp, Delegation {}
