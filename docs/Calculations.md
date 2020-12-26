## Calculations

Let `C` be an amount of some collateral on our contract, and `M` be the size of a market (that is the sum of all conditional tokens of this market).

So, a user with `m` conditional with `s` score would receive `C*s*m/M` collateral after the oracle finishes.

The amount of collateral a user can withdraw is determined by the formula `(C-C')*s*m/M` where `C'` is the amount of the collateral on our contract at the moment of previous withdrawal of the user (or zero if there was no previous withdrawal).

But `M` should not be the entire supply of relevant tokens but instead the supply in circulation. So we follow this algorithm: Give users a short time (like a week) to withdraw their collateral. Who didn't do on time was too late. (The task would be delegated to an external reliable service like a bank.) Let the total amount of the conditionals withdrawn during the grace period be `D`. Then allow "second chance" to withdraw the collateral in amount `(C-C')*s*m/(M-D)`. The payment limit should be `m`.

Remark: It would be wrong to allow anyone to withdraw the maximum amount for their account at the "second chance", because conditional funds may be locked on a shared smart contract, making the available amount less than that leading to a wrong calculation of the supply in circulation.
