# Assurage: Insurance Market For Storagte Providers on Fiecoin

This is the submission for the ongoing [ETHGlobal](https://ethglobal.com/) Hackathon: [Filecoin Space Warp](https://ethglobal.com/events/spacewarp). 

## Introduction
Assurage is an insurance app built on top of Filecoin EVM, which helps Storage Providers minimize their business risks. It enables SPs to obtain insurance that protects them from slashing penalties, so-called sector fault fees, which are imposed when they fail to maintain their operational requirements for providing storage on the Filecoin network. 

## FEVM: Filecoin EVM 
>The Filecoin EVM (FEVM) is the Ethereum Virtual Machine virtualized as a runtime on top of the Filecoin Virtual Machine. It will allow developers to port any existing EVM-based smart contracts straight onto the FVM (where we call them actors). 

*Documentation*
- [Filecoin EVM](https://docs.filecoin.io/developers/smart-contracts/concepts/filecoin-evm/)

## Sector and Sector Fault

Sectors are the basic, standardized units of storage on Filecoin and the sector fault fee is the penalty for SPs not maintaining their operational requirements. This is paid per sector per day while the sector is in a faulty state but not paid the first day the system detects the fault allowing a one day grace period for recovery without fee. 

The size of the sector fault fee is slightly more than the amount the sector is expected to earn per day in block rewards. More concretely, it is 1.5 days Fault Detection Fee and 2.4 days worth of block reward for Sector Fault Fee which is a little higher than the former's since undeclared fault could be seen malicious and more harmful to the network. Additionally, A penalty, which is imposed on miners who are terminated by the network for being in a faulty state for too long ( more than 42 days capped up at 90 days ), is called termination fault in which the amount is defined based on the estimation that a sector would have earned per day for the period of the time.

*Documentation*
- [How providing storage works](https://docs.filecoin.io/storage-provider/basics/how-providing-storage-works/)
- [Sector](https://spec.filecoin.io/#section-systems.filecoin_mining.sector)
- [Sector Fault](https://spec.filecoin.io/#section-systems.filecoin_mining.sector.sector-faults)

## Insurance for Sector faults

Fault insurance that Assurage provides is the financial protection for those miners who agree the insurance contract and are unwillingly slashed for being faulty on the network. The cover is compensated from the capital supplied by insurers, those who deposit funds to Assurage's Protection vault. The premium cost varies for each individual miner and its sector. It is determined by the miner's reliability and historical performance of covered sectors, as well as the cover amount and period it wants to be protected from slashing. 

## Architecture 

Assurage is an insurance platform for Storage Providers, which is primarily consisted of three parties: The inured, the insurers and Assurage Managers. The first is Storage Providers who pay premium and purchase protections for sector fault penalties, and the second is Liquidity Providers who provide insurance capital and generate profits (from SPs' premium payments and investments), and the last one is independent third-party agents, called Assurage Delegates, that create and manage insurance markets(Assurage Manager + Protection Vault) on Assurage. 

![Screen Shot 2023-01-30 at 5 12 20](https://user-images.githubusercontent.com/88586592/215368064-bf8a6c2b-893d-4efe-a606-503c3ea64e3a.png)

### Assurage Delegate
Permissioned Assurage Delegates can create insurance markets by deploying and managing both AssurageManager and ProtectionVault contracts and attract liquidity from LPs and provide insurance policies that SPs purchase. Although they are responsible for assessing and approving/rejecting SPs' applications and claim filings, it's possible to delegate the assessing role to another entity called Assessor if needed. Additionally, it's vital to create strategy contracts where idol deposited capital is invested into other DeFi protocols to generate additional incomes for the vault so that it can attract more LPs and SPs.

### Storage Providers
Storage Providers or Miners choose active insurance markets that fit their growth stages and preferences, and decide to submit applications that contains the information about the contracts: insurance amount and duration.If approved, they activate the policy and will be able to be compensated when being punished for sector faults. SPs who agree the contract should add the `AssurageManager` contract to `beneficiary` before the policy activation in order for the Assurage to be able to proceed premium payments which will be sent to ProtectionVault contract.

### Liquidity Providers
Liquidity Providers invest in preferable protection vaults to make profits by allocating their funds based on vaults' APY and the performance and reputation of both Assurage Delegates and insured Storage Providers. The protection vault is ERC4626-standard tokenized vault. Hence, they will receive LP tokens which represent their share of deposits and flexibly change their vault positions via the ERC4626Router contract.

The whole smart contract architecture and ERC4626-centric implementation are inspired by Maple Finance and Yearn Finance. Moreover, the intergration of FVM's Miner Actor is powered by Zondax's API

- [Maple Finance](https://github.com/maple-labs)
- [Yearn ERC4626 Router](https://github.com/Schlagonia/Yearn-ERC4626-Router)
- [Zondax Filecoin Solidity API](https://github.com/Zondax/filecoin-solidity)

## Insurance Policy Details

#### Premium 

The equation to define premium is below.

```shell
Premium = (Amount * Period) * premiumFactor / Score
premiumFactor = 0.00007
Score(%) = {1 ~ 100}
```

The equation for determining the premium cost is inspired by Nexus Mutual, where the premium cost increases linearly depending on each factor in the equation.

For the sake of the prototype, the score values are taken from [Filecoin Plus](https://filfox.info/en/ranks/power) where the scores of top miners mostly range from 90 - 100. According to the website, this value is constructed based on Online Reachability Score, Commited Sectors Proofs Score and Storage Deals Score. In production, however, it can be calculated based on more various factors, such as the performance metrics(the number of sector and deals), financial metrics ( balance, average daily rewards, and culmulative rewards), and the record of histrical fault cases.

*Example*

Here is an example case of a sector fault that one of the top miners mistakenly makes a sector stay off-line for three consecutive days. Suppose a miner that has been operating as a Storage Provider with a quite solid performance and a daily average earning of 1,000 FIL per day wants to join the Assurage to be covered. It requests protection whose coverage is 10,000 FIL and lasts for the next 90 days, which will cost approximately 64.28 FIL ( it's assumed that the score of the miner is 98).

After the assessors carefully review the application and approve it after diligent assessment, the protection contract will be successfully activated by paying the premium. One day before the protection expires, the miner is slashed for being off-line for three consecutive days and charged 3,000 FIL in total. Then, it submits the claim for protection that can cover the loss of slashing to the Assurage and fully gets compensated if the claim is considered valid. The net loss the miner incurred is just 64.28 FIL which is the fee to join the protection, although the miner would have lost 2935.72 FIL without the protection.

#### Invalid Applications

Applications that are likely dismissed:
-
-

#### Invalid Claims

Claims that are likely dismissed:
- Consensus Fault
- Termination Penalty

