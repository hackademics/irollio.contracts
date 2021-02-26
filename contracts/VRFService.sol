// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./IRoll.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract VRFService is Ownable, VRFConsumerBase
{
    using SafeMath for *;
	using Address  for address;

    address vrfLinkToken = 0xa36085F69e2889c224210F603D836748e7dC0088;
    address vrfContract  = 0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9;
    bytes32 vrfKeyHash   = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
    uint256 vrfLinkFee   = 0.1 * 10 ** 18;
    
    address private caller;

    constructor(address _vrfLinkToken, address _vrfContract, bytes32 _vrfKeyHash, uint256 _vrfLinkFee) public VRFConsumerBase(vrfContract, vrfLinkToken) {
        
        vrfLinkToken = _vrfLinkToken;
        vrfContract  = _vrfContract;
        vrfKeyHash   = _vrfKeyHash;
        vrfLinkFee   = _vrfLinkFee;
    }

    function request(uint256 _userSeed) public returns(bytes32) {
        caller = msg.sender;
        return requestRandomness(vrfKeyHash, vrfLinkToken, _userSeed);
    }

    function fulfillRandomness(_requestId, _randomness) internal override {
        IRoll(caller).rollResult(_requestId,_randomness);
    }    

    function mock(uint256 _userSeed) public {
        Roll(caller).rollResult(0xa36085F69e2889c224210F603D836748e7dC0088, 59135454321564579751331643231646432.164679879);        

    }




}
