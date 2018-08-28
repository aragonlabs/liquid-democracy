pragma solidity 0.4.18;

import "@aragon/apps-staking/contracts/StakingHistory.sol";
import "@aragon/os/contracts/apps/UnsafeAragonApp.sol";


contract StakingHistoryMock is UnsafeAragonApp, StakingHistory {
  function StakingHistoryMock() {
    initialize();
  }

  function initialize() onlyInit public {
    initialized();
  }

  function addFakeStake(address acct, uint256 value) public {
    modifyStakeBalance(acct, value, true);
    updateFakeTotalStaked(value, true);
  }

  function removeFakeStake(address acct, uint256 value) public {
    modifyStakeBalance(acct, value, false);
    updateFakeTotalStaked(value, false);
  }

  function updateFakeTotalStaked(uint256 value, bool add) internal {
    uint256 currentStaked = totalStakedHistory.get(getBlocknumber());
    uint256 newStaked = add ? currentStaked.add(value) : currentStaked.sub(value);
    totalStakedHistory.add(newStaked, getBlocknumber());
  }

  function isfake() public pure returns (bool) { return true; }
}