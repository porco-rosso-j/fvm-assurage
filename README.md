# Assurage: Insurance Market For Storagte Providers on Fiecoin

This is the submission for the ongoing [ETHGlobal](https://ethglobal.com/) Hackathon: [Filecoin Space Warp](https://ethglobal.com/events/spacewarp).

## Introduction

Assurage is an insurance app built on top of Filecoin EVM, which helps Storage Providers minimize their business risks. It enables SPs to obtain insurance that protects them from slashing penalties, so-called sector fault fees, which are imposed when they unexpectedly fail to maintain their operational requirements for providing storage on the Filecoin network.

## FEVM: Filecoin EVM

> The Filecoin EVM (FEVM) is the Ethereum Virtual Machine virtualized as a runtime on top of the Filecoin Virtual Machine. It will allow developers to port any existing EVM-based smart contracts straight onto the FVM (where we call them actors).

- [Filecoin EVM](https://docs.filecoin.io/developers/smart-contracts/concepts/filecoin-evm/)

## Sector and  Sector Fault 

Sectors are the basic, standardized units of storage on Filecoin and the sector fault fee is the penalty for SPs not maintaining their operational requirements. Besides malicious activites and operational mistakes, faults could occur when infrastructure issues and natural disasters harm their operations and hardware. This is paid per sector per day while the sector is in a faulty state but not paid the first day the system detects the fault allowing a one day grace period for recovery without fee.

The size of the sector fault fee is slightly more than the amount the sector is expected to earn per day in block rewards. More concretely, it is 1.5 days Fault Detection Fee and 2.4 days worth of block reward for Sector Fault Fee which is a little higher than the former's since undeclared fault could be seen malicious and more harmful to the network.

- [How providing storage works](https://docs.filecoin.io/storage-provider/basics/how-providing-storage-works/)
- [Sector](https://spec.filecoin.io/#section-systems.filecoin_mining.sector)
- [Sector Fault](https://spec.filecoin.io/#section-systems.filecoin_mining.sector.sector-faults)

## Assurage's Insurance for Sector Fault

Fault insurance that Assurage provides is the financial protection for SPs who agree insurance contracts and are unwillingly slashed for being faulty on the network. The cover is compensated from the capital supplied by insurers, those who deposit funds to Assurage's Protection vault. The premium cost varies for each individual miner and its sector. It is determined based on various factors: the cover amount and period it wants to be protected from slashing, as well as the miner and the covered sector's reliability and historical performance.

Assurage's insurance scheme is not processed entirely on-chain but needs an intermediary called Assurage Delegate (see below), since at this stage where there is no oracle that provides FVM data with contracts on FEVM in a trustless manner, it seems technically infeasible to fetch and store all data on SPs on-chain, e.g. the basic SP's information and past performance for reviewing their applications for protection and the occurrence of fault events to conduct claim assessments and decide to proceed payment. 

Hence, there needs to be centralized actors that assess the information and proceed the vital procedures off-chain. That said, Assurage Delegates are well-incentivized to carry out honest and fair works. This is because they have to show integrity continuously to compete with other delegates. Also, they can delegate their assessing work to another trusted entity called Assessor, which can be a multi-sig controlled address instead of one person/entity, controlled by a group of people consisted of well-known experts.

## Protocol Overview

Assurage is an insurance platform for Storage Providers, which is primarily consisted of three parties: The inured, the insurers and Assurage Managers. The first is Storage Providers who pay premium and purchase protections for sector fault penalties, and the second is Liquidity Providers who provide insurance capital and generate profits (from SPs' premium payments and investments), and the last one is independent third-party agents, called Assurage Delegates, that create and manage insurance markets(Assurage Manager + Protection Vault) on Assurage.

#### Assurage Delegate

Assurage Delegates can create insurance markets by deploying and managing both `AssurageManager.sol` and `ProtectionVault.sol` contracts to attract liquidity from LPs and provide SPs with protections. Although they are responsible for assessing and approving/rejecting SPs' applications and claim filings, it's possible to delegate the assessing role to another entity called Assessor if needed. Additionally, it's recommended to set strategy contracts inheriting `IStrategy.sol`, where idol deposited capital is invested into other DeFi protocols to generate additional incomes for the vault so that it can attract more LPs and SPs.

#### Storage Providers

Storage Providers or Miners choose active insurance markets that fit their growth stages and preferences, and decide to submit applications that contains the information about the contracts: insurance amount and duration.If approved, they activate the policy and will be able to be compensated when being punished for sector faults. SPs who agree the contract should register the `AssurageManager.sol` contract as a `beneficiary` before the policy activation in order for the Assurage to be able to withdraw premium payment from them, which will be sent to `ProtectionVault.sol` contract.

#### Liquidity Providers

Liquidity Providers invest in preferable protection vaults to make profits by allocating their funds based on vaults' APY and the performance and reputation of both Assurage Delegates and insured Storage Providers. The protection vault is ERC4626-standard tokenized vault. Hence, they will receive LP tokens which represent their share of deposits and flexibly change their vault positions via the `AR4626Router.sol` contract.

## Technical Architecture

<img width="1017" alt="Screen Shot 2023-01-30 at 18 47 56" src="https://user-images.githubusercontent.com/88586592/215509844-4afd0590-6d18-4cbe-b54e-532a5b4f29b4.png">

The whole smart contract architecture and ERC4626-centric implementation are highly inspired by Maple Finance and Fei protocol's ERC4626 Implementation. Specifically, it can be said that the base in codebase is a modified fork of Maple, such as `AssurageGlobal.sol` and its Proxy design, and the `ProtectionVault.sol` and `AR4626Router.sol` contracts are mostly forked from Fei's ERC4626 implementation. 

- [Maple Finance](https://github.com/maple-labs)
- [Fei Protocol/ERC4626](https://github.com/fei-protocol/ERC4626)

However, `AssurageManager.sol`, which serves Storage Providers as a single interface, is unique and indispensable in the way that it stores all the relevant variables and handles most of the insurance procedures, especially policy applications/activations, claim filings, and payment operations. As the architecture diagram shows, except for Liquidity providers, other components and participants work and interact with each other through this contract.

As one of the most immportant modules for `AssurageManager.sol`, Zondax's Solidity API helps it seemlessly interact with Miner Actors on FEVM. [`src/filecoin-api/MienrAPIHelper.sol`](https://github.com/porco-rosso-j/fvm-assurage/blob/main/src/filecoin-api/MinerAPIHepler.sol) that integrates the API allows Assurage to fetch the data of Miners to check their available balance and validate that the setting of beneficiary, such as `beneficiary` address, allowance amount and expiration time is correctly configured set before miners pay premium.

- [Zondax Filecoin Solidity API](https://github.com/Zondax/filecoin-solidity)

## Insurance Policy Details

#### Premium

The equation to define premium is below.

```shell
Premium = (Amount * Period) * premiumFactor / Score
premiumFactor = 0.00007
Score(%) = {1 ~ 100}
```

The equation for determining the premium cost is inspired by Nexus Mutual, where the premium cost increases linearly depending on each variable in the equation.

For the sake of the prototype, the score values are taken from [Filecoin Plus](https://filfox.info/en/ranks/power) where the scores of top miners mostly range from 90 - 100. According to the website, this value is constructed based on Online Reachability Score, Commited Sectors Proofs Score and Storage Deals Score. In production, however, it can be calculated based on more various factors, such as the performance metrics(the number of sector and deals), financial metrics ( balance, average daily rewards, and culmulative rewards), and the record of histrical fault cases.

_Example_

Here is an example scnerio of a sector fault that one of the top miners mistakenly makes a sector stay off-line for three consecutive days. Suppose a miner that has been operating as a Storage Provider with a quite solid performance and a daily average earning of 1,000 FIL per day wants to join the Assurage to be covered. It requests protection whose coverage is 10,000 FIL and lasts for the next 90 days, which will cost approximately 64.28 FIL ( it's assumed that the score of the miner is 98).

After the assessors carefully review the application and approve it after diligent assessment, the protection contract will be successfully activated by paying the premium. One day before the protection expires, the miner is slashed for being off-line for three consecutive days and charged 3,000 FIL in total. Then, it submits the claim for protection that can cover the loss of slashing to the Assurage and fully gets compensated if the claim is considered valid. The net loss the miner incurred is just 64.28 FIL which is the fee to join the protection, although the miner would have lost 2935.72 FIL without the protection.

#### Invalid Applications

SPs whose applications are likely dismissed

- Malicious SPs
- SPs currently in sector faults
-

#### Invalid Claims

Claims that are likely dismissed:

- Consensus Fault
- Termination Penalty

## Test
`AssurageSetup.t.sol` deploys the whole contracts and `PolicyOperations.t.sol` simulates and tests the core logics in `AssurageManager.sol`, such as insurance applications/activation, claim filings and payments.

`forge build`   
`forge test`   
