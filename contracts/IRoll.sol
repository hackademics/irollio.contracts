// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./VRFService.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract IRoll is Ownable, PullPayment {
    
    using SafeMath for *;
	using Address  for address;

    address  public wallet;
    uint256  public entryFee;
    uint8[8] public payouts = [90,50,20,10,5,4,3,2];
    bool     public locked;
    bytes32 vrfRequestId;

    mapping(address => bool) public players;

    event RollRequest(address sender, bytes32, uint256);
    event RollResult(address sender, bytes32, uint256, uint8[5], uint256);
    event Winner(address sender, uint256, uint8);

    constructor(address _wallet, uint8[8] _payouts, uint256 _entryFee) public {
        require(_wallet != address(0), "Invalid Wallet");
        
        wallet   = _wallet;
        payouts  = _payouts;
        entryFee = _entryFee;

    }

    fallback () public payable {
        if(!locked)
            wallet.transfer(msg.value);
    }

    function roll(uint256 _userSeed) public payable {
        locked = true;
            wallet.transfer(msg.value);
        locked = false;

        players[msg.sender] = true;

        vrfRequestId = VRFService().request(_userSeed);

        emit Rolling(msg.sender, vrfRequestId, _userSeed);
    } 

    function rollResult(_requestId, _randomness) public {
        require(vrfRequestId == _requestId, "No Match VRF");
        
        //dice
        uint8[] di = [0,0,0,0,0];
        //matches
        uint8[] m = [0,0,0,0,0,0];        

        di[0] = _n.mod(6).add(1);        
        m[(di[0]-1)] = uint8(m[(di[0]-1)]+1);

        uint d = 10;
        for (uint8 i=1;i<4;i++) {
            di[i] = _n.div(d).mod(6).add(1);
            m[(di[i]-1)] = uint8(m[(di[i]-1)]+1);            
            d = d.mul(d);
        }

        uint256 won = 0;
        uint8 p = score(di, m);
        if(p > 0){
            won = payout(p);
        }

        emit RollResult(msg.sender, _requestId, _randomness, di, won);
    }  

    function payout(p) public payable returns(uint256) {
        require(!locked, "Locked");
        require(p > 0 && p < 90, "Invalid Payout Amount");
        
        locked = true;
            uint256 w = address(this).balance.mul(p).div(100);
            _asyncTransfer(msg.sender, w);
        locked = false;
        
        emit Winner(msg.sender, w, p);

        return w;
    } 

    function claim(address payable _winner) public payable {
        require(!locked, "Locked");
        require(entries[msg.sender], "No Entry Found");
        locked = true;
            withdrawPayments(_player);
        locked = false;
    }

    function claims(address _winner) public view returns(uint256) {
        return payments(_winner);
    }

    function score(di, m) private returns(uint8)
    {
        if (di[0] == 6 && di[1] == 6 && di[2] == 6 && di[3] == 6 && di[4] == 6){           
            return payouts[0]; //JACK POT        
        } else if ((m[0] == 5) || (m[2] == 5) || (m[3] == 5) || (m[4] == 5) || (m[5] == 5)) {            
            return payouts[1]; //FIVE OF A KIND
        } else if ((m[0] == 4) || (m[1] == 4) || (m[2] == 4) || (m[3] == 4) || (m[4] == 4) || (m[5] == 4)) {            
            return payouts[2];//FOUR OF A KIND
        } else if (((m[0] == 3) || (m[0] == 2)) || ((m[1] == 3) || (m[1] == 2)) || ((m[2] == 3) || (m[2] == 2)) || ((m[3] == 3) || (m[3] == 2)) || ((m[4] == 3) || (m[4] == 2)) || ((m[5] == 3) || (m[5] == 2))) {            
            return payouts[3]; //FULL HOUSE
        } else if ((m[0] >= 1) && (m[1] >= 1) && (m[2] >= 1) && (m[3] >= 1) && (m[4] >= 0)) {
            return payouts[4]; //LARGE STRAIGHT 12345
        } else if ((m[0] == 0) && (m[1] >= 1) && (m[2] >= 1) && (m[3] >= 1) && (m[4] >= 1) && (m[5] >= 1)) {            
            return payouts[4]; //LARGE STRAIGHT 23456
        } else if((m[0] >= 1) && (m[1] >= 1) && (m[2] >= 1) && (m[3] >= 1) && (m[4] == 0)) {
            return payouts[5]; //SMALL STRAIGHT 1234
        } else if((m[0] == 0) && (m[1] >= 1) && (m[2] >= 1) && (m[3] >= 1) && (m[4] >= 1) && (m[5] == 0)) {            
            return payouts[5]; //SMALL STRAIGHT 2345
        } else if((m[1] == 0) && (m[2] >= 1) && (m[3] >= 1) && (m[4] >= 1) && (m[5] >= 1)) {            
            return payouts[5]; //SMALL STRAIGHT 3456
        } else if((m[0] == 3) && (m[1] == 3) && (m[2] == 3) && (m[3] == 3) && (m[4] == 3) && (m[5] == 3)) {            
            return payouts[6]; //THREE OF A KIND
        } else if((m[0] == 2) || (m[2] == 2) || (m[3] == 2) || (m[4] == 2) || (m[5] == 2)) {            
            if ( m[0].add(m[1]).add(m[3]).add(m[1]).add(m[4]).add(m[1]).add(m[5]) == 5){ return payouts[7]; } //TWO PAIRS
        } else {
            return 0; //NO WINNER
        }
    }
}