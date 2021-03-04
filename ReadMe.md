IROLL.IO

IRoll Contract Description
    ** Admin interface to offchain services to manage Pots

PAYOUT ARRAY
    ** 0  : 66666 : JACKPOT
    ** 1  : 11111 : FIVE OF A KIND
    ** 2  : x1111 : FOUR OF A KIND
    ** 3  : 11122 : FULL HOUSE
    ** 4  : 12345 : LARGE STRAIGHT
    ** 5  : 23456 : LARGE STRAIGHT
    ** 6  : x1234 : SMALL STRAIGHT
    ** 7  : x2345 : SMALL STRAIGHT
    ** 8  : x3456 : SMALL STRAIGHT
    ** 9  : xx111 : THREE OF A KIND
    ** 10 : x1122 : TWO PAIR


Pot Contract Description
    **  Holds the balance of ether that players are trying to win (pot)
    **  Pot Owner is address responsible for Seeding and Opening the contract (benefactor)
    **  buy() is the payable call that accepts player entry fee and adds to balance (entry)
    **  Request for a random uint256 number is made to LINK Verified Random Function (VRFService.sol wrapper) (shake)
    **  Upon response of VRF number creation, number is converted to represent randomness as five six sided dice (roll)
    **  Dice representation result is inspected for Jack Pot or other winning combos (score) 
    **  Winning Combos cascade JACKPOT, FIVE OF A KIND, FOUR OF A KIND, FULL HOUSE, LARGE STRAIGHT(2), SMALL STRAIGHT(3), THREE OF A KIND, TWO PAIR
    **  Player winnings are a percentage of the contract balance and Jack Pot payouts should always leave ten percent (win)
    **  Pot Owners can set a custom payout at creation but these cannont be changed once Pot is opened.
    **  Inspired by the tavern Shake A Day dice game, Pots can be created with an interval set between shakes(once per day, or tender shift)(DOS)

Pot TODOS
    **  Implement dynamic interval time between rolls
    **  Harden balance deposit, withdraw, tranfer
    **  Initializable and Reentrance guard
    **  Library for Scoring methods
    **  ECR20 Token deposit/swap
    **  Compound or AAVE integration for pot balance interest
    **  Allow Pot Owner to recover seed payment when applicable
    **  Pot Owner receives percent of fees, winnings, interest
    **  White listing of address for entry 
    **  bit shifting to compact stored data

VRFService Contract Description
     ** Wraps the VRF service to handle to request and response of random number requests
     ** Returns the Request Id and Random Number generated to calling contract

 VRFService TODO
    ** Harden security and callbacks (addresses)
    ** Intializable and Reentracy Guard inategration
    ** Put payment on the Pot entry fee
    ** Pass Link VRF params in constructor
