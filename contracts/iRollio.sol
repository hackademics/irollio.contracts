// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

import "./Pot.sol";
import "./lib/Structs.sol";
import "./services/ScoreService.sol";
import "./services/RollService.sol";

import "@openzeppelin/contracts/payment/escrow/Escrow.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract iRollio is Ownable {
    
    address[] public  pots;
    bool      private locked = false;    
    address   private linkToken = 0xa36085F69e2889c224210F603D836748e7dC0088; 

    event RollRequest(address sender, Roll roll);  
    event RollResult(address sender, Roll roll); 
    event PotCreated(address sender, Pot pot);

    struct PotListItem {
        address pot;
        uint256 balance;    
    }

    /**
        @dev Method to accept player
        @param _pot Address of the wallet they are rolling against
        @param _seed Any number provided by the player
     */
    function iroll(address _pot, uint256 _seed) public payable {        
        //require(address(_pot).entryWei == msg.value, "Invalid Entry Wei");
        //require(address(_pot).balance > 0, "Pot has no balance");
        require(_seed > 0, "Invalid Seed");
        require(!locked, "LOCKED");
        
        Roll memory roll;  
        roll.player = msg.sender;
        roll.pot = _pot;
        roll.seed = _seed;
        roll.ts = block.timestamp;
       
        //if(address(roll.pot).enter(roll))
       // {               
            RollService(linkToken).request(roll);
        //}

         emit RollRequest(msg.sender, roll);
    }

    /**
        @dev Receives the call back from VRF
        @param _roll Array of dice
     */
    function rollResult(Roll memory _roll) public returns(uint256) {       
       lock();
            //_roll.prizePool = address(_roll.pot).prizePool;
            ScoreService _service = new ScoreService();
            _service.result(_roll);

            if(_roll.prizePercent > 0 && _roll.prizeIndex > 0){
                //address(_roll.pot).payout(_roll);
            }
        unlock();
        
        emit RollResult(msg.sender, _roll);
        
        return _roll.won; 
    } 

    /**
        @dev Create a new Pot
     */
    function createPot() public onlyOwner {
        require(!locked, "LOCKED");

        lock();
            Pot _pot = new Pot(1 wei, 8 hours, 90,0,0,0,0,0,0,0); 
            //pots[msg.sender] = _pot; 
            PotCreated(msg.sender, _pot);
        unlock();       
    } 

    /**
        @dev Get a list of pots and their balance

    function potList() public returns(address[] memory){
        require(pots.length >= 10, "No Pots Yet");
        
        address[] memory result;
        for(uint8 i = 0; i < 10; i++)
        {
            require(!result.push(pots[i]), "Bad Array");
            break;
        }

        return result;
    }
    */

    /**
        @dev Lock
    */
    function lock() private {
        locked = true;
    }

    /**
        @dev Unlock
    */
    function unlock() private {
        locked = false;
    }    


}