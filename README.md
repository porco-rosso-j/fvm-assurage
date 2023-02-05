# Assurage: Insurance Market For Storage Providers on Fiecoin

This is the submission for the ongoing [ETHGlobal](https://ethglobal.com/) Hackathon: [Filecoin Space Warp](https://ethglobal.com/events/spacewarp).

## Introduction

Assurage is an insurance app built on top of Filecoin EVM, which helps Storage Providers minimize their business risks. It enables SPs to obtain insurance that protects them from slashing penalties, so-called sector fault fees, which are imposed when they unexpectedly fail to maintain their operational requirements for providing storage on the Filecoin network.

## FEVM: Filecoin EVM

> The Filecoin EVM (FEVM) is the Ethereum Virtual Machine virtualized as a runtime on top of the Filecoin Virtual Machine. It will allow developers to port any existing EVM-based smart contracts straight onto the FVM (where we call them actors).

- [Filecoin EVM](https://docs.filecoin.io/developers/smart-contracts/concepts/filecoin-evm/)

## Sector and  Sector Fault 

Sectors are the basic, standardized units of storage on Filecoin, and the sector fault is the financial penalty imposed on SPs who fail to maintain their operational requirements. The penalty payment is performed by slashing SP's FIL deposit. Besides malicious activities and operational mistakes, faults could occur when infrastructure issues and natural disasters disable their operations and damage their hardware. So. not all the fault is caused by bad actors but by honest SPs who should be able to recover from their failures.

More details:
- [How providing storage works](https://docs.filecoin.io/storage-provider/basics/how-providing-storage-works/)
- [Sector](https://spec.filecoin.io/#section-systems.filecoin_mining.sector)
- [Sector Fault](https://spec.filecoin.io/#section-systems.filecoin_mining.sector.sector-faults)

## Assurage's Insurance for Sector Fault

Fault insurance that Assurage provides is the financial protection for SPs who agree on an insurance contract on Assurage and pay the premium for it. It compensates affected SPs when they are unwillingly slashed for being faulty on the network. After insurance market creater called Assurage Delegate have completed reviewing and approving filed claims submitted by SP, the cover is paid from the capital supplied by insurers, those who deposit funds to Assurage's Protection vault. 

## Protocol Overview

Assurage is an insurance platform for Storage Providers, which primarily consists of three parties: The Assurage Delegates/Managers, the insurers and the insured. 

- _Assurage Delegates_, who create and manage insurance markets(Assurage Manager + Protection Vault) on Assurage.
- The insurers: _Liquidity Providers_, who provide insurance capital and generate profits. 
- The insured: _Storage Providers_, who pay premiums and purchase protections to be protected from sector fault penalties. 

On Assurage, there are bunch of insurance markets created by a number of Assurage Delegates. So, both SPs and LPs need to carefully choose a protection vault they either deposit their funds to or have a protection contract. Below is the more detailed descriptions of the three parties.

#### Assurage Delegate

Assurage Delegates can create insurance markets by deploying and managing both `AssurageManager.sol` and `ProtectionVault.sol` contracts to attract liquidity from LPs and provide SPs with protections. Although they are responsible for assessing and approving/rejecting SPs' applications and filed claims, it's possible to delegate the assessment role to another entity called Assessor if needed. Additionally, it's recommended to set strategy contracts inheriting `IStrategy.sol`, where idol deposited capital is invested into other DeFi protocols to generate additional income for the vault so that it can attract more LPs and SPs.

#### Storage Providers

Storage Providers or Miners choose active insurance markets that fit their growth stages and preferences and decide to submit applications that contain the information about the contracts: insurance amount and duration. If approved, they activate the policy and can be compensated when punished for sector faults. SPs who agree the contract should register the `AssurageManager.sol` contract as a `beneficiary` before the policy activation in order for the Assurage to be able to withdraw premium payment from them, which will be sent to `ProtectionVault.sol` contract.

#### Liquidity Providers

Liquidity Providers invest in preferable protection vaults to make profits by allocating their funds based on vaults' APY and the performance and reputation of both Assurage Delegates and insured Storage Providers. The protection vault is ERC4626-standard tokenized vault. Hence, they will receive LP tokens representing their share of deposits and flexibly change their vault positions via the `AR4626Router.sol` contract.

## Technical Architecture

<img width="1017" alt="Screen Shot 2023-01-30 at 18 47 56" src="https://user-images.githubusercontent.com/88586592/215509844-4afd0590-6d18-4cbe-b54e-532a5b4f29b4.png">

The whole smart contract architecture and ERC4626-centric implementation are highly inspired by Maple Finance and Fei protocol's ERC4626 Implementation. Specifically, it can be said that the base in codebase is a modified fork of Maple, such as `AssurageGlobal.sol` and its Proxy design. And the `ProtectionVault.sol` and `AR4626Router.sol` are the forks of Fei's ERC4626 implementation examples except Assurage-specific configurations. 

- [Maple Finance](https://github.com/maple-labs)
- [Fei Protocol/ERC4626](https://github.com/fei-protocol/ERC4626)

However, `AssurageManager.sol`, which serves Storage Providers as a single interface, is unique and indispensable in the way that it stores all the relevant variables and handles most of the insurance procedures, especially policy applications/activations, claim filings, and payment operations. As the architecture diagram shows, except for Liquidity providers, other components and participants work and interact with each other through this contract.

As one of the most important modules for `AssurageManager.sol`, Zondax's Solidity API helps it seamlessly interact with Miner Actors on FEVM. [`src/filecoin-api/MienrAPIHelper.sol`](https://github.com/porco-rosso-j/fvm-assurage/blob/main/src/filecoin-api/MinerAPIHepler.sol) that integrates the API allows Assurage to fetch the data of Miners to check their available balance and validate that the setting of beneficiary, such as `beneficiary` address, allowance amount and expiration time is correctly configured set before miners pay premiums.

- [Zondax Filecoin Solidity API](https://github.com/Zondax/filecoin-solidity)

### Overview of smart contract source code

| ./src/(folder) | Description |
| -------- | ------- |
| [`core`](https://github.com/porco-rosso-j/fvm-assurage/tree/main/src/core) | Contains a global contract called `AsssurageGlobal.sol` that configures crucial parameters and manages the entire protocol. |
| [`filecoin-api`](https://github.com/porco-rosso-j/fvm-assurage/tree/main/src/filecoin-api) | Imports Zondax soldiity API contracts and `MinerAPIHelper.sol` that interacts with MinerActor on FEVM and validates the returned information. |
| [`proxy`](https://github.com/porco-rosso-j/fvm-assurage/tree/main/src/proxy) | Assurage's proxy and proxy factory contracts that inherits EIP1967 proxy contracts. |
| [`strategies`](https://github.com/porco-rosso-j/fvm-assurage/tree/main/src/strategies) | Holds strategy contracts that AssurageManager contract allocate its idol funds. As an example, it has `LidoStrategy.sol`. |
| [`vault`](https://github.com/porco-rosso-j/fvm-assurage/tree/main/src/vault) | Contains crucial contracts for Assurage: `ProtectionVault.sol`, `AR4626Router.sol` and `AssurageManager.sol`. |

## Constrains and Solutions 

Assurage's insurance scheme is not processed entirely on-chain but needs the Assurage Delegate or Assessor as an intermediary, since, at this stage, there is no oracle that provides FVM data with contracts on FEVM in a trustless manner, it seems technically infeasible to fetch and store all data on SPs on-chain and algorithmically determine the validity of applications and claims. Hence, Assurage Delegates can be seen as centralized entities that could misbehave and corrupt.

That said, Assurage is designed to minimalize such risks by incentivizing the Delegates to be honest and dilligent due to the market force: They have to show integrity continuously to compete with other delegates. Also, they can delegate their assessment work to another trusted entity called Assessor, which can be a multi-sig controlled address, instead of one person/entity, requiring N-of-M signatures(agreements) by a group of people consisting of well-known experts.

## Premium payment

The premium cost varies for each individual miner and its sector. It is determined based on a couple of factors: the cover amount and period it wants to be protected from slashing, as well as the miner's reliability and the covered sector's historical performance.

The mock equation to define premium cost is below.

```shell
Premium = (Amount * Period) * premiumFactor / Score

Amount = token amount
Period = the number of days
premiumFactor = 0.00007
Score(%) = {1 ~ 100}
```

[`_quotePremium`](https://github.com/porco-rosso-j/fvm-assurage/blob/40e04e2f2850dd8634ca11851a1c96b0004a853d/src/vault/AssurageManager.sol#L199) function in the codebase.

The equation for determining the premium cost is inspired by Nexus Mutual, where the premium cost increases linearly depending on each variable in the equation.

For the sake of the prototype, the score values are taken from [Filecoin Plus](https://filfox.info/en/ranks/power) where the scores of top miners mostly range from 90 - 100. According to the website, this value is constructed based on Online Reachability Score, Committed Sectors Proofs Score and Storage Deals Score. In production, however, it can be calculated based on various factors, such as the performance metrics(the number of sectors and deals), financial metrics ( balance, average daily rewards, and cumulative rewards), and the record of historical fault cases.

## Example: A SP's user story

Here is an example scenario of a sector fault where one of the top miners mistakenly makes a sector stay offline for three consecutive days. Suppose a SP who has been operating as a Storage Provider with a quite solid performance and a daily average earning of 1,000 FIL per day decides to join a protection. He got a protection whose coverage is 10,000 FIL and the duration is 90 days, costing approximately 64.28 FIL ( it's assumed that the SP's score is 98).

After either the delegate or assessor carefully reviewed the application and approved it, the protection contract was successfully activated, and the premium the SP paid was sent to the vault. Afterwards, the SP was slashed for being offline for three days and charged 3,000 FIL before the contract expiration. Then, the SP submitted a claim filing for cover that can fully make up the loss. Again, the delegate or assessor diligently assessed the claim's validity by examining the event on-chain. Then, finally, they approved and compensated the SP because the claim is considered valid. The net loss the SP incurred was only 64.28 FIL which is the fee to join the protection and he saved 3,000 FIL. 

## Test
`AssurageSetup.t.sol` deploys the whole contracts, and `PolicyOperations.t.sol` simulates and tests the core logic in `AssurageManager.sol`, such as insurance applications/activation, claim filings and payments.

```shell
git clone git@github.com:porco-rosso-j/fvm-assurage.git
cd fvm-assurage
forge build
forge test   
```
