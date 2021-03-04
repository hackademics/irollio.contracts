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

    /** @dev Coordinator, LINK token, Callback to, Key Hash, Request Id, Link Token Fee */
    address private vrCO;
    address private vrLT;  
    address private caller;  
    bytes32 private vrKH;   
    bytes32 private vrID;
    uint256 private vrLF;

    /** @dev Request Randomness called, Request Fullfilled */
    event EVRQ(address indexed usr, bytes32 id, uint256 us);
    event EVRF(address indexed usr, bytes32 id, uint256 rand);
    event EVIF(address indexed usr, address indexed lt, uint256 b, uint256 lf);

    /** @dev INITIALIZE contract and set defaults */
    constructor() public VRFConsumerBase(vrCO, vrLT) {
        vrCO = 0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9;
        vrLT = 0xa36085F69e2889c224210F603D836748e7dC0088;
        vrKH = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        vrLF = uint256(0.1*10**18);
    }

    /** @dev request() Makes a request for random number from VRF 
        @dev Checks LINK token balance to ensure enough balance for request
        @param _s User Seed uint256 provided by the User
        @return bytes32
     */
    function request(uint256 _s) public returns(bytes32) {
        require(hasLink(), "vrfbal");
        caller = msg.sender;
        vrID = requestRandomness(vrKH, vrLF, _s);
        emit EVRQ(msg.sender, vrID, _s);
        return vrID;
    }

    /** @dev fullfillRandomness() Callback from VRF with Id and Random Number
        @param _id VRF Request Id (should match id created in request)
        @param _n  VRF Random Number generated
     */
    function fulfillRandomness(bytes32 _id, uint256 _n) internal override {
        require(msg.sender == vrCO, "vffsndr");
        require(_id == vrID, "vffid");
        emit EVRF(msg.sender, _id, _n);
        //callback
        Pot(caller).vrfR(_id, _n);
    }    

    /** @dev hasLink() Checks the contracts balance for Link Balance
        return bool
     */
    function hasLink() public returns(bool){
        uint256 b = LINK.balanceOf(address(this));
        if(b > vrLF) {return true;} else { emit EVIF(msg.sender, vrLT, b, vrLF); return false; }
    }

    /** @dev setCO() Update Address of LINK VRF Coordinator
        @param _v Address to change to
        @return address
     */
    function setCO(address _v) public onlyOwner returns(address) {
        vrCO = _v;
        return vrCO;
    }
    
    /** @dev setLT() Update Address of LINK TOKEN
        @param _v Address to change to
        @return address
     */    
    function setLT(address _v) public onlyOwner returns(address) {
        vrLT = _v;
        return vrLT;
    }

    /** @dev setLF() Update LINK Token Fee
        @param _v Address to change to
        @return unit256
     */
    function setLF(uint256 _v) public onlyOwner returns(uint256) {
        vrLF = _v;
        return vrLF;
    }  

    /** @dev setKH() Update VRF Key Hash
        @param _v KeyHash to change
        @return bytes32
     */    
    function setKH(bytes32 _v) public onlyOwner returns(bytes32) {
        vrKH = _v;
        return vrKH;
    }  
    /** @dev info() Get info about contract state
        @return address, address, bytes32, uint256
     */
    function info() public view onlyOwner returns(address, address, bytes32, uint256){
        return(vrCO, vrLT, vrKH, vrLF);
    }
}
