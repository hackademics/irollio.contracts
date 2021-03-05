## IROLL.IO__
__
IRoll Contract Description__
Admin interface to offchain services to manage Pots__
__
## PAYOUT ARRAY__
__
0  : 66666 : JACKPOT__
1  : 11111 : FIVE OF A KIND__
2  : x1111 : FOUR OF A KIND__
3  : 11122 : FULL HOUSE__
4  : 12345 : LARGE STRAIGHT__
5  : 23456 : LARGE STRAIGHT__
6  : x1234 : SMALL STRAIGHT__
7  : x2345 : SMALL STRAIGHT__
8  : x3456 : SMALL STRAIGHT__
9  : xx111 : THREE OF A KIND__
10 : x1122 : TWO PAIR__
__
__
## Pot Contract Description__
__
Holds the balance of ether that players are trying to win (pot)__
Pot Owner is address responsible for Seeding and Opening the contract (benefactor)__
buy() is the payable call that accepts player entry fee and adds to balance (entry)__
Request for a random uint256 number is made to LINK Verified Random Function (VRFService.sol wrapper) (shake)__
Upon response of VRF number creation, number is converted to represent randomness as five six sided dice (roll)__
Dice representation result is inspected for Jack Pot or other winning combos (score) __
Winning Combos cascade JACKPOT, FIVE OF A KIND, FOUR OF A KIND, FULL HOUSE, LARGE STRAIGHT(2), SMALL STRAIGHT(3), THREE OF A KIND, TWO PAIR__
Player winnings are a percentage of the contract balance and Jack Pot payouts should always leave ten percent (win)__
Pot Owners can set a custom payout at creation but these cannont be changed once Pot is opened.__
Inspired by the tavern Shake A Day dice game, Pots can be created with an interval set between shakes(once per day, or tender shift)(DOS)__
__
## Pot TODOS__
__
Implement dynamic interval time between rolls__
Harden balance deposit, withdraw, tranfer__
Initializable and Reentrance guard__
Library for Scoring methods__
ECR20 Token deposit/swap__
Compound or AAVE integration for pot balance interest__
Allow Pot Owner to recover seed payment when applicable__
Pot Owner receives percent of fees, winnings, interest__
White listing of address for entry __
bit shifting to compact stored data__
__
## VRFService Contract Description__
__
Wraps the VRF service to handle to request and response of random number requests__
Returns the Request Id and Random Number generated to calling contract__
__
## VRFService TODO
__
Harden security and callbacks (addresses)__
Intializable and Reentracy Guard inategration__
Put payment on the Pot entry fee__
Pass Link VRF params in constructor__
__