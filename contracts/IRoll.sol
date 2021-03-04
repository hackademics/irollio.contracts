// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Pot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

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