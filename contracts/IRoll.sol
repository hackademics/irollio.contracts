// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Pot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/** IRoll Contract Description
    Admin interface to offchain services to manage Pots
 
    POT PAYOUT ARRAY
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
*/

contract IRoll is Ownable {
    
    using SafeMath for *;
	using Address  for address;
    using Strings  for string;

    uint8[11] public pp;
    bool      public lck;
    Pot[]     public pots;

    /** Pot Created */
    event EVPC(address indexed usr, address indexed pa, Pot p);

    constructor() public {
        pp = [90,0,0,0,0,0,0,0];
    }

    /** create() Creates new Pot contract 
        @param _po  Pot Owner
        @param _pp  Array of pot prizes
        @param _pf  Pot Entry Fee
        @param _pn  Pot friendly name
        @param _pfs Pot Forces five 6s for jackpot
        @param _pri Pot Interval between rolls
     */
    function create(address payable _po, uint8[11] calldata _pp, uint256 _pf, string calldata _pn, bool _pfs, uint256 _pri) public onlyOwner returns(address) {
        lck = true;
            Pot p = new Pot(_po, _pp, _pf, _pn, _pfs, _pri);
            pots[pots.length -1] = p;
            emit EVPC(msg.sender, address(p), p);
        lck = false;
        return(address(p));
    }    

    /** list() Returns all the pots
        @return Array of all Pots
     */
    function list() external view onlyOwner returns(Pot[] memory){
        return pots;
    }   
}