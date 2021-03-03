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

    event EVAD(address indexed usr, address indexed pa, Pot p);

    constructor() public {
        pp = [90,0,0,0,0,0,0,0];
    }

    function add(address payable _po, uint8[11] calldata _pp, uint256 _pf, string calldata _pn) public onlyOwner returns(address) {
        lck = true;
            Pot p = new Pot(_po, _pp, _pf, _pn);
            pots[pots.length -1] = p;
            emit EVAD(msg.sender, address(p), p);
        lck = false;
        return(address(p));
    }    

    function list() external view onlyOwner returns(Pot[] memory){
        return pots;
    }   
}