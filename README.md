# Insurance For Fiecoin Storagte Provider -- Assurage

## Introduction

## What is Sector Fault

Sector fault fee is paid per sector per day while the sector is in a faulty state but not paid the first day the system detects the fault allowing a one day grace period for recovery without fee. The size of the sector fault fee is slightly more than the amount the sector is expected to earn per day in block rewards. More concretely, it is 1.5 days Fault Detection Fee and 2.4 days worth of block reward for Sector Fault Fee which is a little higher than the former's since undeclared fault could be seen malicious and more harmful to the network. Additionally, the fee imposed on miners who are terminated by the network for being in a faulty state for too long ( more than 42 days capped up at 90 days ) is called termination fee which also charges a miner the amount that a sector would have earned per day for the period of the time.

- [Storage Provider's Sector Fault](https://spec.filecoin.io/#section-systems.filecoin_mining.sector.sector-faults)

## Insurance for Sector faults

Fault insurance is the cover for those honest miners are unwillingly slashed for being faulty on the network, paid by the protection providers through protection vault on Assurage protoocl. The size of the insurance payment of sector fault is expected to be the amount a punished miner would have earned if it had not been faulty for the period of time so that it can maintain its business minimizing the loss of slashing.

Miners should be assesed by the assessors and pay premium for the protection to join the insurance. The premium cost differs for each indiviudual miner and its sector and is determined by each miner's reliability historical performance of covered sectors as well as the cover amount and period that it wants to be protected from slashing. The equation to define premium is below.

```shell
Premium = (Amount * Period) * premiumFactor / Score
premiumFactor = 0.00007
Score(denominator) = {1 ~ 100}
```

The equation for determining the premium cost is inspired by Nexus Mutual. The cost of premiums increases linearly depending on each factor in the equation.

For the sake of the prototype, the score values are taken from Filecoin Plus website(https://filfox.info/en/ranks/power) where the scores of top miners mostly range from 90 - 100. According to the website, this value is constructed based on Online Reachability Score, Commited Sectors Proofs Score and Storage Deals Score. In production, however, it can be calculated based on more various factors, such as the performance metrics(the number of sector and deals), financial metrics ( balance, average daily rewards, and culmulative rewards), and the record of histrical fault cases.

### Example

Here is an example case of a sector fault that one of the top miners mistakenly makes a sector stay off-line for three consecutive days. Suppose a miner that has been operating as a Storage Provider with a quite solid performance and a daily average earning of 1,000 FIL per day wants to join the Assurage to be covered. It requests protection whose coverage is 10,000 FIL and lasts for the next 90 days, which will cost approximately 64.28 FIL ( it's assumed that the score of the miner is 98).

After the assessors carefully review the application and approve it after diligent assessment, the protection contract will be successfully activated by paying the premium. One day before the protection expires, the miner is slashed for being off-line for three consecutive days and charged 3,000 FIL in total. Then, it submits the claim for protection that can cover the loss of slashing to the Assurage and fully gets compensated if the claim is considered valid. The net loss the miner incurred is just 64.28 FIL which is the fee to join the protection, although the miner would have lost 2935.72 FIL without the protection.

### Invalid Applications

Applications that are likely dismissed by assessors are...

- for a improper-tier pVault.
- from malicious SPs
-

### Invalid Claims

Below is a few types of claims where assessors shouldn't consider valid because the claim is to compensate the shashing funds due to...

- Consensus Fault
- Termination Penalty

## Architecture

###
