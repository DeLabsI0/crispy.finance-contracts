const { web3 } = require('@openzeppelin/test-environment')

const decodeAllLogs = (receipt, rawEmitters) => {
  const logs = receipt?.receipt?.rawLogs

  if (logs === undefined) throw new Error('No logs found in receipt')

  const emitters = {}
  for (let { address, abi } of rawEmitters) {
    const events = abi.filter(({ type }) => type === 'event')
    const emitter = { events: {} }
    for (let event of events) {
      emitter.events[event.signature] = event
    }

    emitters[address] = emitter
  }

  return logs
    .filter(({ address, topics: [eventSig] }) => emitters?.[address]?.events?.[eventSig])
    .map(({ logIndex, data, topics: [eventSig, ...topics], address }) => {
      const { inputs, name } = emitters[address].events[eventSig]
      const args = web3.eth.abi.decodeLog(inputs, data, topics)

      return { name, logIndex, args, address }
    })
}

module.exports = { decodeAllLogs }
