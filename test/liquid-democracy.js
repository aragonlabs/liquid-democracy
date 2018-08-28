const { promisify } = require('util')
const { assertRevert } = require('@aragon/test-helpers/assertThrow')
const { encodeCallScript, EMPTY_SCRIPT } = require('@aragon/test-helpers/evmScript')

const LiquidDemocracy = artifacts.require('UnsafeLiquidDemocracy')
const StakingHistory = artifacts.require('StakingHistoryMock')

const pct16 = x => new web3.BigNumber(x).times(new web3.BigNumber(10).toPower(16))
const createdVoteId = receipt => receipt.logs.filter(x => x.event == 'StartVote')[0].args.voteId

contract('Liquid Democracy', accounts => {
  let staking, ld

  const A = accounts[1]
  const B = accounts[2]
  const C = accounts[3]

  const STAKES = {
    [A]: 100,
    [B]: 200,
    [C]: 300,
  }

  const neededSupport = pct16(50)
  const minimumAcceptanceQuorum = pct16(20)
  const votingTime = 500

  const delegate = (from, to) => ld.delegate(to, { from })
  const vote = (from, voteId, supports) => ld.vote(voteId, supports, false, { from })

  beforeEach(async () => {
    staking = await StakingHistory.new()
    ld = await LiquidDemocracy.new() 

    await ld.initialize(staking.address, neededSupport, minimumAcceptanceQuorum, votingTime)

    for (let addr in STAKES) {
      await staking.addFakeStake(addr, STAKES[addr])
    }
  })

  context.only('on vote', () => {
    const createVote = async (from = A) => (
      createdVoteId(await ld.newVote(EMPTY_SCRIPT, '', false, { from }))
    )

    const assertVoteResult = async (voteId, yea, nay, stage) => {
      const voteInfo = await ld.getVote(voteId)

      assert.equal(voteInfo[6], yea, 'yea count should have been correct' + stage ? ` for ${stage}` : '')
      assert.equal(voteInfo[7], nay, 'nay count should have been correct' + stage ? ` for ${stage}` : '')
    }

    it('simple vote count', async () => {
      await delegate(A, B)

      const voteId = await createVote()

      await vote(B, voteId, true)
      await vote(C, voteId, false)

      await assertVoteResult(voteId, STAKES[A] + STAKES[B], STAKES[C])
    })

    it('allows overruling', async () => {
      await delegate(A, B)
      await delegate(B, C)

      const voteId = await createVote()

      await vote(C, voteId, true)
      await assertVoteResult(voteId, STAKES[A] + STAKES[B] + STAKES[C], 0, 'after C votes')

      await vote(B, voteId, false)
      await assertVoteResult(voteId, STAKES[C], STAKES[A] + STAKES[B], 'after B overrules C')

      await vote(A, voteId, true)
      await assertVoteResult(voteId, STAKES[A] + STAKES[C], STAKES[B], 'after A overrules B')
    })

    it('avoids delegate vote by overruling early', async () => {
      await delegate(A, B)
      await delegate(B, C)

      const voteId = await createVote()

      await vote(A, voteId, true)
      await assertVoteResult(voteId, STAKES[A], 0, 'after A votes')

      await vote(B, voteId, false)
      await assertVoteResult(voteId, STAKES[A], STAKES[B], 'after B votes')

      await vote(C, voteId, false)
      await assertVoteResult(voteId, STAKES[A], STAKES[B] + STAKES[C], 0, 'after C votes')
    })

    it('delegate can change vote after overruling', async () => {
      await delegate(A, B)

      const voteId = await createVote()

      await vote(B, voteId, true)
      await vote(A, voteId, false)
      await assertVoteResult(voteId, STAKES[B], STAKES[A], 'after A overrules')
      
      await vote(B, voteId, false)
      await assertVoteResult(voteId, 0, STAKES[A] + STAKES[B], 'after B changes vote')
      
      await vote(A, voteId, true)
      await assertVoteResult(voteId, STAKES[A], STAKES[B], 'after A changes vote')
    })
  })
})
