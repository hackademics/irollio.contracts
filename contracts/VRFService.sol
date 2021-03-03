// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Pot.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract VRFService is Ownable, VRFConsumerBase
{
    using SafeMath for *;
	using Address  for address;

    address private vrCO;
    address private vrLT;  
    address private caller;  
    bytes32 private vrKH;   
    bytes32 private vrID;
    uint256 private vrLF;

    constructor() public VRFConsumerBase(vrCO, vrLT) {
        vrCO = 0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9;
        vrLT = 0xa36085F69e2889c224210F603D836748e7dC0088;
        vrKH = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        vrLF = uint256(0.1 * 10 ** 18);
    }

    function request(uint256 _s) public returns(bytes32) {
        require(LINK.balanceOf(address(this)) > vrLF, "vrlnkbal");
        caller = msg.sender;
        vrID = requestRandomness(vrKH, vrLF, _s);
        return vrID;
    }

    function fulfillRandomness(bytes32 _id, uint256 _n) internal override {
        require(msg.sender == vrCO, "vffsndr");
        require(_id == vrID, "vffid");
        Pot(caller).vrfR(_id, _n);
    }    

    function setCO(address _v) public onlyOwner returns(address) {
        vrCO = _v;
        return vrCO;
    }
    
    function setLT(address _v) public onlyOwner returns(address) {
        vrLT = _v;
        return vrLT;
    }

    function setLF(uint256 _v) public onlyOwner returns(uint256) {
        vrLF = _v;
        return vrLF;
    }   
    
    function setKH(bytes32 _v) public onlyOwner returns(bytes32) {
        vrKH = _v;
        return vrKH;
    }  

    function info() public view onlyOwner returns(address, address, bytes32, uint256){
        return(vrCO, vrLT, vrKH, vrLF);
    }
}
