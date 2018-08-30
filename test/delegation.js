const { promisify } = require('util')
const { assertRevert } = require('@aragon/test-helpers/assertThrow')

const Delegation = artifacts.require('UnsafeDelegation')
const StakingHistory = artifacts.require('StakingHistoryMock')


contract('Delegation app', accounts => {
  let staking, delegation

  const A = accounts[1]
  const B = accounts[2]
  const C = accounts[3]
  const D = accounts[4]
  const E = accounts[5]
  const F = accounts[6]

  const STAKES = {
    [A]: 100,
    [B]: 200,
    [C]: 300,
    [D]: 400,
    [E]: 1000,
    [F]: 1000,
  }

  const TOTAL_STAKED = 3000

  beforeEach(async () => {
    staking = await StakingHistory.new()
    delegation = await Delegation.new() 

    await delegation.initialize(staking.address)

    for (let addr in STAKES) {
      await staking.addFakeStake(addr, STAKES[addr])
    }
  })

  const getBlockNumber = promisify(web3.eth.getBlockNumber)

  it('has correct initial state', async () => {
    const fs = ['power', 'totalDelegatedBalance']

    for (let f of fs) {
      for (let addr in STAKES) {
        const balance = await delegation[f](addr)
        assert.equal(balance, STAKES[addr], 'should have correct balance in '+f)
      }
    }
  })

  const delegate = (from, to) => delegation.delegate(to, { from })
  const undelegate = (who) => delegation.undelegate({ from: who })

  const assertDelegatedBalance = async (who, expected) => {
    const balance = await delegation.delegatedBalance(who)
    assert.equal(balance.toNumber(), expected, 'delegated balance should be correct')
  }

  const assertTotalDelegatedBalance = async (who, expected) => {
    const balance = await delegation.totalDelegatedBalance(who)
    assert.equal(balance.toNumber(), expected, 'total delegated balance should be correct')
  }

  const assertPower = async (who, expected) => {
    const balance = await delegation.power(who)
    assert.equal(balance.toNumber(), expected, 'power balance should be correct')
  }

  it('delegates', async () => {
    await delegate(A, B)

    await assertDelegatedBalance(A, 0)
    await assertDelegatedBalance(B, STAKES[A])
   
    await assertTotalDelegatedBalance(A, STAKES[A])
    await assertTotalDelegatedBalance(B, STAKES[A] + STAKES[B])

    await assertPower(A, 0)
    await assertPower(B, STAKES[A] + STAKES[B])
  })

  it('delegates multi-chain', async () => {
    await delegate(B, C)
    await delegate(A, B)

    await assertPower(C, STAKES[A] + STAKES[B] + STAKES[C])

    await assertTotalDelegatedBalance(A, STAKES[A])
    await assertTotalDelegatedBalance(B, STAKES[A] + STAKES[B])
    await assertTotalDelegatedBalance(C, STAKES[A] + STAKES[B] + STAKES[C])
  })

  it('can undelegate', async () => {
    await delegate(A, B)
    await undelegate(A)

    await assertPower(A, STAKES[A])
    await assertPower(B, STAKES[B])
  })

  it('can undelegate multi-chain', async () => {
    await delegate(A, B)
    await delegate(B, C)

    await undelegate(A)

    await assertPower(A, STAKES[A])
    await assertPower(C, STAKES[B] + STAKES[C])
  })

  it('delegates multi-chain with undelegations', async () => {
    await delegate(A, B)
    await undelegate(A)
    await delegate(B, C)
    await delegate(C, D)
    await delegate(D, E)
    await delegate(E, F)
    await delegate(A, B)
    await undelegate(A)

    await assertPower(F, TOTAL_STAKED - STAKES[A])
  })

  it('detects chain circles', async () => {
    await delegate(A, B)
    await delegate(B, C)
    await delegate(D, A)

    return assertRevert(() => delegate(C, D))
  })  
})
