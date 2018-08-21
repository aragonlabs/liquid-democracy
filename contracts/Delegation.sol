pragma solidity 0.4.18;

import "@aragon/apps-staking/contracts/StakingHistory.sol";

import "@aragon/os/contracts/lib/zeppelin/math/SafeMath.sol";
import "@aragon/os/contracts/lib/zeppelin/math/SafeMath8.sol";
import "@aragon/os/contracts/lib/misc/Migrations.sol";

contract Delegation is AragonApp {
  using Checkpointing for Checkpointing.History;
  using SafeMath for uint256;
  using SafeMath8 for uint8;

  struct DelegateAccount {
    Checkpointing.History delegatedToBalance; // checkpointed tokens delegated to account
    Checkpointing.History delegateHistory;    // checkpointed addr of the delegate 
    uint64 delegationTime;                    // can be used to 
    uint8 chainDepth;                         // incoming chain depth (not reset on undelegations)
    uint8 allowedDepth;                       // max allowed depth by delegate
  }

  StakingHistory staking;
  mapping (address => DelegateAccount) accounts;

  address constant NO_DELEGATE = address(0);
  uint8 public constant MAX_CHAIN_DEPTH = 20; // TODO: compute actual max given gas analysis
  uint8 public constant DEFAULT_ALLOWED_DEPTH = MAX_CHAIN_DEPTH / 2;

  function delegate(address to) public {
    require(to != msg.sender);  // avoid direct circular delegation chains
    require(to != NO_DELEGATE);

    if (delegateOf(msg.sender) != NO_DELEGATE) {
      undelegate();
    }

    DelegateAccount storage delegator = accounts[msg.sender];
    delegator.delegationTime = uint64(getBlockNumber());
    uint256 delegatingBalance = totalDelegatedBalance(msg.sender);
    
    uint8 initialDepth = delegator.chainDepth;
    uint8 currentDepth = 0;

    // array big enough so the worse possible chain would fit
    address[] memory chain = new address[](MAX_CHAIN_DEPTH.sub(initialDepth));

    address delegateAddr = delegateOf(to);

    while (delegateAddr != NO_DELEGATE) {
      DelegateAccount storage del = accounts[delegateAddr];

      // avoid indirect circular delegation chains
      for (uint8 j = 0; j < currentDepth; j = j.add(1)) {
        require(chain[j] != delegateAddr);
      }

      chain[currentDepth] = delegateAddr;

      currentDepth = currentDepth.add(1);
      uint8 delegateDepth = initialDepth.add(currentDepth);
      require(delegateDepth <= allowedChainDepth(delegateAddr));

      del.chainDepth = max8(del.chainDepth, delegateDepth);

      uint256 currentlyDelegated = delegatedBalance(delegateAddr);
      uint256 newBalance = currentlyDelegated.add(delegatingBalance);

      del.delegatedToBalance.add(newBalance, getBlockNumber());

      delegateAddr = delegateOf(delegateAddr);
    }

    setDelegate(msg.sender, to);
  }

  function undelegate() public {
    DelegateAccount storage delegator = accounts[msg.sender];
    require(delegator.delegationTime < getBlockNumber()); // avoid double delegations

    uint256 undelegatingBalance = totalDelegatedBalance(msg.sender);
    delegator.delegationTime = 0;

    address delegateAddr = delegateOf(msg.sender);

    while (delegateAddr != NO_DELEGATE) {
      DelegateAccount storage del = accounts[delegateAddr];

      // NOTE: chain depth cannot be decreased with the data we store

      uint256 currentlyDelegated = delegatedBalance(delegateAddr);
      uint256 newBalance = currentlyDelegated.sub(undelegatingBalance);

      del.delegatedToBalance.add(newBalance, getBlockNumber());

      delegateAddr = delegateOf(delegateAddr);
    }

    setDelegate(msg.sender, NO_DELEGATE);
  }

  function setAllowedDepth(uint8 _allowedDepth) public {
    require(_allowedDepth <= MAX_CHAIN_DEPTH);

    // decreasing below its current depth cannot be enforced unless forcing undelegations
    require(_allowedDepth >= accounts[msg.sender].chainDepth);

    accounts[msg.sender].allowedDepth = _allowedDepth;
  }

  function allowedChainDepth(address addr) public view returns (uint8) {
    uint8 allowedDepth = accounts[addr].allowedDepth;
    return allowedDepth == 0 ? DEFAULT_ALLOWED_DEPTH : allowedDepth;
  }

  function setDelegate(address addr, address delegateAddr) internal {
    accounts[addr].delegateHistory.add(uint256(delegateAddr), getBlockNumber());
  }

  /**
  * @dev Delegated tokens + own tokens that haven't been delegated
  */
  function powerAt(address addr, uint256 time) public view returns (uint256) {
    DelegateAccount storage account = accounts[addr];
    return delegateOfAt(addr, time) != NO_DELEGATE ? 0 : totalDelegatedBalanceAt(addr, time);
  }

  function power(address addr) public view returns (uint256) {
    return powerAt(addr, getBlockNumber());
  }

  /**
  * @dev Delegated tokens + own tokens at delegation time
  */
  function totalDelegatedBalanceAt(address addr, uint256 time) public view returns (uint256) {
    DelegateAccount storage delegated = accounts[addr];

    uint256 balanceSnapshotTime = delegated.delegationTime > 0 ? delegated.delegationTime : time;
    uint256 holderBalance = stakedBalanceAt(addr, balanceSnapshotTime);
    uint256 delegatedBalance = delegatedBalanceAt(addr, time);

    return delegatedBalance.add(holderBalance);
  }

  function totalDelegatedBalance(address addr) public view returns (uint256) {
    return totalDelegatedBalanceAt(addr, getBlockNumber());
  }

  /**
  * @dev Total delegated tokens regardless of delegation status. 
  */
  function delegatedBalanceAt(address addr, uint256 time) public view returns (uint256) {
    DelegateAccount storage delegated = accounts[addr];

    return delegated.delegatedToBalance.get(time);
  }

  function delegatedBalance(address addr) public view returns (uint256) {
    return delegatedBalanceAt(addr, getBlockNumber());
  }

  function delegateOf(address addr) public view returns (address) {
    return delegateOfAt(addr, getBlockNumber());
  }

  function delegateOfAt(address addr, uint256 time) public view returns (address) {
    return address(accounts[addr].delegateHistory.get(time));
  }

  function stakedBalance(address addr) internal view returns (uint256) {
    return staking.totalStakedFor(addr);
  }

  function stakedBalanceAt(address addr, uint256 time) internal view returns (uint256) {
    return staking.totalStakedForAt(addr, time);
  }

  function max8(uint8 a, uint8 b) internal pure returns (uint8) {
    return a >= b ? a : b;
  }
}